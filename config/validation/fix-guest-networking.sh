#!/bin/bash
#
# Bulk fix for the "migrated VM boots but has no IP" issue documented in
# 11A-COLD-POC-Migration-LIVE-procedure.md, Step 12 / Known Issue #10.
#
# Root cause: virt-v2v does not rewrite the guest's NetworkManager connection
# profile to match the new virtio NIC. The profile stays bound to the old
# hypervisor's device name (e.g. ESXi's "ens34") with the old LAN-subnet
# static IP, so it never activates on the target's "enpXsY" device.
#
# This script, per VM: stops it, frees its PVC, mounts the disk offline via a
# purpose-created libguestfs pod, replaces any stale NetworkManager profile
# with one bound to the correct interface using DHCP, then restarts the VM
# and confirms an IP was actually assigned. Safe to re-run — VMs that already
# have a working IP are skipped unless --force is given.
#
# Usage:
#   fix-guest-networking.sh -n <namespace> [-v vm1,vm2,...] [--dry-run] [--force] [--default-iface enp1s0]
#
#   -n, --namespace       Target namespace (required)
#   -v, --vms             Comma-separated VM names. Default: all VMs in the namespace.
#   --dry-run             Report what would change without modifying anything.
#   --force               Re-apply the fix even if the VM already has a working IP.
#   --default-iface NAME  Interface name to assume when it can't be detected from a
#                          previous boot (default: enp1s0 - true for this lab's pc-q35
#                          machine type with a single virtio NIC; verify for anything else).
#   --guestfs-image REF   Override the libguestfs-tools image reference.
#
# Limitations (documented, not silently ignored):
#   - Assumes a single NIC per VM. Multi-NIC VMs are skipped with a warning -
#     review and fix those by hand following Step 12 in the procedure doc.
#   - Assumes a single-disk VM for the PVC lookup (spec.template.spec.volumes[0]).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="/tmp/mtv-fix-guest-networking-$(date +%Y%m%d-%H%M%S).log"
DEFAULT_GUESTFS_IMAGE="registry.redhat.io/container-native-virtualization/libguestfs-tools-rhel9@sha256:a51dc6303e491de47533fc0a25ac5165cd8027b91fc884b80d540843e8ea2448"

NAMESPACE=""
VM_LIST=""
DRY_RUN=false
FORCE=false
DEFAULT_IFACE="enp1s0"
GUESTFS_IMAGE="$DEFAULT_GUESTFS_IMAGE"

RESULTS=()   # "vmname|STATUS|detail"

log()  { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >/dev/null; }
info() { echo -e "${BLUE}ℹ${NC} $1"; log "INFO: $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; log "OK: $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; log "WARN: $1"; }
err()  { echo -e "${RED}✗${NC} $1"; log "ERROR: $1"; }

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        -v|--vms) VM_LIST="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        --default-iface) DEFAULT_IFACE="$2"; shift 2 ;;
        --guestfs-image) GUESTFS_IMAGE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) err "Unknown option: $1"; usage ;;
    esac
done

if [ -z "$NAMESPACE" ]; then
    err "Namespace is required (-n/--namespace)"
    usage
fi

command -v oc >/dev/null || { err "oc CLI not found"; exit 1; }

if [ -z "$VM_LIST" ]; then
    VM_LIST=$(oc get vm -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    if [ -z "$VM_LIST" ]; then
        err "No VMs found in namespace $NAMESPACE"
        exit 1
    fi
    VM_LIST="${VM_LIST// /,}"
fi

info "Namespace: $NAMESPACE"
info "VMs: $VM_LIST"
info "Dry run: $DRY_RUN | Force: $FORCE | Default iface: $DEFAULT_IFACE"
info "Log file: $LOG_FILE"
echo ""

wait_for() {
    # wait_for <description> <timeout_seconds> <command...>
    local desc="$1" timeout="$2"; shift 2
    local waited=0
    while ! "$@" >/dev/null 2>&1; do
        sleep 3
        waited=$((waited + 3))
        if [ "$waited" -ge "$timeout" ]; then
            return 1
        fi
    done
    return 0
}

vmi_gone() {
    ! oc get vmi "$1" -n "$NAMESPACE" >/dev/null 2>&1
}

pod_ready() {
    [ "$(oc get pod "$1" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]
}

vmi_has_ip() {
    local vm="$1"
    local ip
    ip=$(oc get vmi "$vm" -n "$NAMESPACE" -o jsonpath='{.status.interfaces[0].ipAddress}' 2>/dev/null)
    [ -n "$ip" ]
}

fix_vm_networking() {
    local vm="$1"
    info "=== $vm ==="

    if ! oc get vm "$vm" -n "$NAMESPACE" >/dev/null 2>&1; then
        err "$vm: VM not found in namespace $NAMESPACE"
        RESULTS+=("$vm|FAILED|not found")
        return
    fi

    local nic_count
    nic_count=$(oc get vm "$vm" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.domain.devices.interfaces}' 2>/dev/null | python3 -c "import json,sys; d=sys.stdin.read(); print(len(json.loads(d)) if d.strip() else 0)" 2>/dev/null || echo 1)
    if [ "$nic_count" -gt 1 ] 2>/dev/null; then
        warn "$vm: has $nic_count NICs - this script assumes single-NIC VMs. Skipping; fix by hand per Step 12."
        RESULTS+=("$vm|SKIPPED|multi-NIC ($nic_count), needs manual review")
        return
    fi

    local pvc
    pvc=$(oc get vm "$vm" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null)
    if [ -z "$pvc" ]; then
        err "$vm: could not determine PVC name from spec.template.spec.volumes[0]"
        RESULTS+=("$vm|FAILED|no PVC found")
        return
    fi
    info "$vm: PVC = $pvc"

    # Was it already running with an IP? (idempotency)
    local was_running="false"
    local detected_iface=""
    if oc get vmi "$vm" -n "$NAMESPACE" >/dev/null 2>&1; then
        was_running="true"
        detected_iface=$(oc get vmi "$vm" -n "$NAMESPACE" -o jsonpath='{.status.interfaces[0].interfaceName}' 2>/dev/null)
        if vmi_has_ip "$vm" && [ "$FORCE" != "true" ]; then
            local ip
            ip=$(oc get vmi "$vm" -n "$NAMESPACE" -o jsonpath='{.status.interfaces[0].ipAddress}')
            ok "$vm: already has IP $ip - skipping (use --force to re-apply anyway)"
            RESULTS+=("$vm|SKIPPED|already has IP $ip")
            return
        fi
    fi

    local target_iface="${detected_iface:-$DEFAULT_IFACE}"
    if [ -z "$detected_iface" ]; then
        warn "$vm: could not detect interface name from a previous boot - assuming '$target_iface' (verify manually if this VM's machine type/NIC model differs from the validated pc-q35/virtio case)"
    else
        info "$vm: detected target interface = $target_iface"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        ok "$vm: [dry-run] would stop VM, mount PVC $pvc offline, rebind stale NetworkManager profile(s) to '$target_iface' with DHCP, then restart"
        RESULTS+=("$vm|DRY-RUN|would target interface $target_iface")
        return
    fi

    # --- Stop VM and free the PVC ---
    info "$vm: stopping VM"
    oc patch vm "$vm" -n "$NAMESPACE" --type=merge -p '{"spec":{"running":false}}' >/dev/null
    if ! wait_for "$vm VMI teardown" 120 vmi_gone "$vm"; then
        err "$vm: VMI did not stop within 120s"
        RESULTS+=("$vm|FAILED|VM did not stop")
        return
    fi

    info "$vm: freeing PVC $pvc from any lingering pods"
    for pod in $(oc get pods -n "$NAMESPACE" -o json | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d['items']:
    for v in p['spec'].get('volumes', []):
        if v.get('persistentVolumeClaim', {}).get('claimName') == '$pvc':
            print(p['metadata']['name'])
"); do
        info "$vm: deleting stale pod $pod (still referenced PVC)"
        oc delete pod "$pod" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
    done

    # --- Create guestfs pod ---
    local gf_pod="guestfs-fix-${vm}"
    info "$vm: creating guestfs pod $gf_pod"
    oc delete pod "$gf_pod" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
    cat <<EOF | oc apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: $gf_pod
  namespace: $NAMESPACE
  labels:
    purpose: mtv-guest-network-fix
spec:
  restartPolicy: Never
  containers:
  - name: libguestfs
    image: $GUESTFS_IMAGE
    command: ["sleep", "1800"]
    securityContext:
      runAsUser: 0
      privileged: true
    volumeMounts:
    - name: disk
      mountPath: /disk
  volumes:
  - name: disk
    persistentVolumeClaim:
      claimName: $pvc
EOF

    if ! wait_for "$gf_pod ready" 180 pod_ready "$gf_pod"; then
        err "$vm: guestfs pod $gf_pod not ready within 180s"
        oc delete pod "$gf_pod" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
        RESULTS+=("$vm|FAILED|guestfs pod did not become ready")
        return
    fi

    # --- Discover stale NetworkManager profiles and apply the fix in one virt-customize call ---
    info "$vm: inspecting NetworkManager profiles on the guest disk"
    local existing_profiles
    existing_profiles=$(oc exec -n "$NAMESPACE" "$gf_pod" -- sh -c "
        export LIBGUESTFS_BACKEND=direct
        export LIBGUESTFS_PATH=/usr/local/lib/guestfs/appliance
        virt-ls -a /disk/disk.img -m /dev/rhel/root /etc/NetworkManager/system-connections/ 2>/dev/null
    ")

    local delete_args=""
    local target_already_correct="false"
    for prof in $existing_profiles; do
        local content
        content=$(oc exec -n "$NAMESPACE" "$gf_pod" -- sh -c "
            export LIBGUESTFS_BACKEND=direct
            export LIBGUESTFS_PATH=/usr/local/lib/guestfs/appliance
            virt-cat -a /disk/disk.img -m /dev/rhel/root /etc/NetworkManager/system-connections/$prof 2>/dev/null
        ")
        if echo "$content" | grep -q "interface-name=${target_iface}\$" && echo "$content" | grep -q "method=auto"; then
            target_already_correct="true"
            info "$vm: profile $prof already correctly bound to $target_iface with DHCP"
        else
            info "$vm: marking stale profile for removal: $prof"
            delete_args="$delete_args --delete /etc/NetworkManager/system-connections/$prof"
        fi
    done

    if [ "$target_already_correct" = "true" ] && [ "$FORCE" != "true" ]; then
        ok "$vm: NetworkManager config already correct, nothing to change"
    else
        info "$vm: writing corrected profile for $target_iface and applying via virt-customize"
        local apply_rc
        oc exec -n "$NAMESPACE" "$gf_pod" -- sh -c "
            export LIBGUESTFS_BACKEND=direct
            export LIBGUESTFS_PATH=/usr/local/lib/guestfs/appliance
            UUID=\$(cat /proc/sys/kernel/random/uuid)
            cat > /tmp/${target_iface}.nmconnection << EOC
[connection]
id=${target_iface}
uuid=\$UUID
type=ethernet
interface-name=${target_iface}

[ethernet]

[ipv4]
method=auto

[ipv6]
addr-gen-mode=eui64
method=auto

[proxy]
EOC
            chmod 600 /tmp/${target_iface}.nmconnection
            virt-customize -a /disk/disk.img \
              --upload /tmp/${target_iface}.nmconnection:/etc/NetworkManager/system-connections/${target_iface}.nmconnection \
              ${delete_args} \
              --chmod 0600:/etc/NetworkManager/system-connections/${target_iface}.nmconnection \
              --selinux-relabel
        "
        apply_rc=$?
        if [ "$apply_rc" -ne 0 ]; then
            err "$vm: virt-customize failed (exit $apply_rc)"
            oc delete pod "$gf_pod" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
            RESULTS+=("$vm|FAILED|virt-customize error")
            return
        fi
        ok "$vm: NetworkManager profile fixed"
    fi

    oc delete pod "$gf_pod" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

    # --- Boot and verify ---
    info "$vm: starting VM"
    oc patch vm "$vm" -n "$NAMESPACE" --type=merge -p '{"spec":{"running":true}}' >/dev/null

    if ! wait_for "$vm IP assignment" 120 vmi_has_ip "$vm"; then
        err "$vm: no IP assigned within 120s of boot"
        RESULTS+=("$vm|FAILED|no IP after boot - check console manually")
        return
    fi

    local final_ip
    final_ip=$(oc get vmi "$vm" -n "$NAMESPACE" -o jsonpath='{.status.interfaces[0].ipAddress}')
    ok "$vm: IP assigned: $final_ip"
    RESULTS+=("$vm|FIXED|$final_ip")
}

IFS=',' read -ra VMS <<< "$VM_LIST"
for vm in "${VMS[@]}"; do
    fix_vm_networking "$vm"
    echo ""
done

echo -e "${BLUE}=== Summary ===${NC}"
printf "%-30s %-10s %s\n" "VM" "STATUS" "DETAIL"
fixed=0; skipped=0; failed=0
for r in "${RESULTS[@]}"; do
    IFS='|' read -r vm status detail <<< "$r"
    case "$status" in
        FIXED) color="$GREEN"; fixed=$((fixed+1)) ;;
        SKIPPED|DRY-RUN) color="$YELLOW"; skipped=$((skipped+1)) ;;
        *) color="$RED"; failed=$((failed+1)) ;;
    esac
    printf "%-30s ${color}%-10s${NC} %s\n" "$vm" "$status" "$detail"
done
echo ""
echo "Fixed: $fixed | Skipped: $skipped | Failed: $failed"
echo "Full log: $LOG_FILE"

[ "$failed" -eq 0 ]
