# Cold Migration — LIVE Procedure (ESXi8 standalone → OCP via MTV)

This is the **live-tested, CLI-driven procedure** for a cold MTV migration from a standalone ESXi8 host (no vCenter) to this OCP cluster. It supersedes the original console-walkthrough draft (formerly `12-poc-execution-procedure.md`) — everything below was actually executed against the live lab across two POC sessions (2026-07-10 console/CLI hybrid run, and 2026-07-11 pure-CLI run), and every step reflects what was proven to work, not just what's theoretically supposed to work.

Prerequisite reading: [`11-pre-ESXi-OCP-Live-cluster-validation-checklist.md`](./11-pre-ESXi-OCP-Live-cluster-validation-checklist.md) — cluster/source readiness state and Section 5's mechanics explainer (what a Secret/Provider/VDDK/virt-v2v/VMI actually is). This document assumes you've read that and focuses on **the ordered steps to run** plus **the full catalog of failures to expect**.

- Source: standalone ESXi8 (example used throughout: `192.168.29.60`, VM `rhel96`)
- Target: OCP 4.16 + OpenShift Virtualization + MTV/Forklift `v2.7.12`
- Migration type: **Cold only** — no vCenter means no CBT-based warm migration is possible here (see Known Issue #1)

---

## Before you start: two things that will break every run if skipped

These were both discovered *reactively* (mid-migration failure) in the first POC pass. Do them proactively now — they cost nothing to check upfront and cost a full failed run each if skipped.

### A. Check the ESXi license tier

Check via the ESXi web UI: **Manage → Licensing**.

If the host is on a free/evaluation license, `PowerOffVM_Task` and most `HostNetworkSystem`/config-write API calls will fail with:
```
ServerFaultCode: Current license or ESXi version prohibits execution of the requested operation.
```
(`vim.fault.RestrictedVersion`.) This blocks Forklift's automatic `PowerOffSource` pipeline step. **If the license is restricted, you must manually power off (or gracefully shut down) every source VM before starting its migration** — see Step 6. This is a per-VM manual step, not automatable through Forklift alone under a restricted license.

### B. Check what hostname the ESXi host reports to itself, and make sure it resolves

Check via ESXi's own **Configure → Networking → TCP/IP configuration → Hostname**, or query it once the Provider exists (Step 3) via the inventory API's `host` object.

`virt-v2v` (via `libvirt`'s `esx://` driver) connects to the source using **this self-reported hostname**, resolved via DNS from *inside the migration pod* — completely independent of whatever IP you put in the Provider's `url` field. If it's not resolvable from the OCP nodes' DNS path, guest conversion fails immediately with:
```
libvirt: VIR_ERR_INTERNAL_ERROR: VIR_FROM_ESX: internal error:
IP address lookup for host '<hostname>' failed: Name or service not known
```
Fix: add an A record for that exact hostname wherever the OCP nodes' upstream DNS lives (check `oc debug node/<worker> -- cat /etc/resolv.conf` for the nameserver, then find and edit that zone). In this lab that's BIND on `svc-infra` (`192.168.29.10`), zone file `/var/named/ocp.local.zone`:
```bash
# on the DNS server
echo '<HOSTNAME>   IN  A   <ESXI-IP>' | sudo tee -a /var/named/ocp.local.zone
sudo sed -i 's/<old-serial>/<old-serial+1>/' /var/named/ocp.local.zone   # bump SOA serial
sudo named-checkzone <zone> /var/named/<zone>.zone                       # validate before reload
sudo rndc reload <zone>
```
Verify from a worker before proceeding: `oc debug node/<worker> -- chroot /host getent hosts <hostname>`.

**Do not try to fix this by changing the ESXi hostname via the API instead** (e.g. with `pyvmomi`'s `HostNetworkSystem.UpdateDnsConfig`) — under a restricted license (item A above) that call fails with the exact same `RestrictedVersion` fault. DNS-side fix is the only option available without touching the ESXi host locally.

---

## Step 1 — Confirm MTV/CNV platform health

```bash
oc get csv -A | grep -iE "forklift|kubevirt"
oc get hyperconverged -n openshift-cnv -o jsonpath='{.items[0].status.conditions}'
oc get pods -n openshift-mtv
oc get pods -n openshift-cnv
```
All CSVs `Succeeded`, HCO `Available=True`/`Degraded=False`/`Progressing=False`, all pods `Running`. Do not proceed if any of this is unhealthy — everything downstream depends on it.

---

## Step 2 — Build and publish the VDDK init image (do this before creating the Provider)

VDDK is not shipped by Forklift (VMware licensing) and is effectively **required**, not optional, for a standalone ESXi source — the non-VDDK HTTPS/NFC fallback transport (`nbdkit`'s `curl` plugin) was observed to fail against this ESXi host's HTTP server with `server does not support 'range' (byte range) requests`. Build it once, reuse for every future ESXi provider in this cluster.

```bash
mkdir vddk-build && cd vddk-build
tar xzf VMware-vix-disklib-<version>.x86_64.tar.gz   # produces vmware-vix-disklib-distrib/

cat > Containerfile <<'EOF'
FROM registry.access.redhat.com/ubi8/ubi-minimal
USER 0
COPY vmware-vix-disklib-distrib /vmware-vix-disklib-distrib
# See Known Issue #6/#7 before skipping this line - it is required, and must be relative.
RUN ln -sf libvixDiskLib.so.9 /vmware-vix-disklib-distrib/lib64/libvixDiskLib.so.8
USER 1001
ENTRYPOINT ["cp", "-r", "/vmware-vix-disklib-distrib", "/opt"]
EOF

podman build -t vddk:local -f Containerfile .

REG_ROUTE=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
oc policy add-role-to-user system:image-builder system:serviceaccount:openshift-mtv:default -n openshift-mtv
TOKEN=$(oc create token default -n openshift-mtv --duration=30m)
podman login -u unused -p "$TOKEN" --tls-verify=false "$REG_ROUTE"
podman tag vddk:local "$REG_ROUTE/openshift-mtv/vddk:local"
podman push --tls-verify=false "$REG_ROUTE/openshift-mtv/vddk:local"
```
Resulting pull path for later steps: `image-registry.openshift-image-registry.svc:5000/openshift-mtv/vddk:local`.

Verify the symlink landed before pushing:
```bash
podman run --rm --entrypoint sh vddk:local -c "ls -la /vmware-vix-disklib-distrib/lib64/libvixDiskLib.so.8"
```

---

## Step 3 — Create the ESXi Provider secret and Provider CR

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <host>-creds
  namespace: openshift-mtv
type: Opaque
stringData:
  user: root
  password: "<password>"
  insecureSkipVerify: "true"   # or use `cacert` with a real CA in production
---
apiVersion: forklift.konveyor.io/v1beta1
kind: Provider
metadata:
  name: <provider-name>
  namespace: openshift-mtv
spec:
  type: vsphere
  url: https://<esxi-ip>/sdk
  settings:
    sdkEndpoint: esxi   # the "no vCenter" switch
    vddkInitImage: image-registry.openshift-image-registry.svc:5000/openshift-mtv/vddk:local
  secret:
    name: <host>-creds
    namespace: openshift-mtv
```
```bash
oc apply -f provider.yaml
oc get provider <provider-name> -n openshift-mtv -o wide   # wait for Ready/Connected/Inventory all True
```
Setting `vddkInitImage` **at Provider creation** (rather than patching it in afterward) avoids the "VDDK image invalid" validation loop documented in Known Issue #8 — the Plan re-validates the whole VDDK chain every time this setting changes, and that re-validation is what surfaces cross-namespace pull RBAC gaps (Step 5) and slow first-pull image delays.

Always double-check `spec.url` matches the real ESXi management IP (see Known Issue #11 — a stale/typo'd URL from a previous attempt is an easy thing to carry forward unnoticed).

---

## Step 4 — Look up the VM's inventory details

The Plan needs the VM's inventory ID, source network name, and source datastore name — pull these from Forklift's inventory API rather than guessing:
```bash
UID_PROVIDER=$(oc get provider <provider-name> -n openshift-mtv -o jsonpath='{.metadata.uid}')
oc exec -n openshift-mtv deployment/forklift-controller -c inventory -- sh -c "
  TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl -sk -H \"Authorization: Bearer \$TOKEN\" \
    https://localhost:8443/providers/vsphere/$UID_PROVIDER/vms?detail=1
"
```
Note the VM's `id`, `networks[].id`, and `disks[].datastore.id` from the output — also read `concerns[]` here (UEFI/Secure Boot, USB controllers, CBT-not-enabled, snapshots present are all flagged here and worth checking before migrating).

**If a snapshot exists on the VM, remove it first** (`vim-cmd vmsvc/snapshot.removeall <vmid>` on the ESXi host, or via the vSphere client) — a snapshot chain was seen to interact badly with the byte-range disk read issue in one POC run and is not worth the risk even with VDDK configured.

---

## Step 5 — Grant cross-namespace image pull for the target namespace

Do this **before** creating the Plan, for whatever namespace the VM will land in:
```bash
oc new-project <target-namespace>   # if it doesn't exist yet
oc policy add-role-to-user system:image-puller system:serviceaccount:<target-namespace>:default -n openshift-mtv
```
Without this, the VDDK-validator Job that Forklift spins up in `<target-namespace>` fails pulling the VDDK image with `Init:ImagePullBackOff` / `authentication required`, and the Plan sits stuck in `ValidatingVDDK` indefinitely with no useful top-level error (you have to go find the Job/Pod events yourself to see why).

---

## Step 6 — Power off the source VM (manual, if license-restricted per item A above)

```bash
ssh root@<vm-ip> "shutdown -h now"   # graceful in-guest shutdown
```
Confirm it registers as powered off in inventory before starting the migration (Forklift's `PowerOffSource` step checks current state first and skips the API call entirely if the VM is already off — this is what makes the manual pre-shutdown work around the license restriction).

---

## Step 7 — Create NetworkMap and StorageMap

```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: NetworkMap
metadata:
  name: <name>-networkmap
  namespace: openshift-mtv
spec:
  provider:
    source: {name: <provider-name>, namespace: openshift-mtv}
    destination: {name: host, namespace: openshift-mtv}
  map:
    - source: {id: "<network-id-from-step-4>", name: "<network-name>"}
      destination: {type: pod}   # or NAD reference if the cluster has one - see checklist Section 3
---
apiVersion: forklift.konveyor.io/v1beta1
kind: StorageMap
metadata:
  name: <name>-storagemap
  namespace: openshift-mtv
spec:
  provider:
    source: {name: <provider-name>, namespace: openshift-mtv}
    destination: {name: host, namespace: openshift-mtv}
  map:
    - source: {id: "<datastore-id-from-step-4>", name: "<datastore-name>"}
      destination: {storageClass: <storage-class>, accessMode: ReadWriteOnce, volumeMode: Filesystem}
```
```bash
oc apply -f networkmap.yaml -f storagemap.yaml
oc get networkmap,storagemap -n openshift-mtv   # both should reach Ready=True within seconds
```
Networking decision background (pod network vs. a dedicated Multus NAD) is recorded in the checklist's Section 3 — this lab's workers have only one physical NIC, already enslaved to `br-ex`, so pod network is the only zero-risk option here.

---

## Step 8 — Create the Plan

```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: Plan
metadata:
  name: <name>-migration
  namespace: openshift-mtv
spec:
  provider:
    source: {name: <provider-name>, namespace: openshift-mtv}
    destination: {name: host, namespace: openshift-mtv}
  map:
    network: {name: <name>-networkmap, namespace: openshift-mtv}
    storage: {name: <name>-storagemap, namespace: openshift-mtv}
  targetNamespace: <target-namespace>
  warm: false
  vms:
    - {id: "<vm-id-from-step-4>", name: <vm-name>}
```
```bash
oc apply -f plan.yaml
oc get plan <name>-migration -n openshift-mtv -o jsonpath='{.status.conditions}'
```
Wait for `Ready=True` ("The migration plan is ready.") before proceeding. If it instead shows `ValidatingVDDK` for more than ~30s, check for a stuck validator Job/Pod in `<target-namespace>` — almost always the Step 5 RBAC grant was missed, or the validator image is still on its (slow, ~2min) first pull of `mtv-virt-v2v-rhel9` from `registry.redhat.io`.

Also confirm the target VM template's **firmware** (UEFI + Secure Boot) matches the source if the source VM uses UEFI (flagged in Step 4's `concerns[]`) — KubeVirt drops Secure Boot regardless, but confirm this isn't a hard requirement for the guest before proceeding.

---

## Step 9 — Start the migration

```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: Migration
metadata:
  name: <name>-migration-run1
  namespace: openshift-mtv
spec:
  plan: {name: <name>-migration, namespace: openshift-mtv}
```
```bash
oc apply -f migration.yaml
```
If a run fails and needs retrying, **create a new Migration object with a new name** (`-run2`, `-run3`, ...) rather than trying to reuse/edit the failed one — Migration objects are effectively one-shot.

---

## Step 10 — Monitor the pipeline

```bash
oc get plan <name>-migration -n openshift-mtv -o jsonpath='{.status.migration.vms[0].pipeline}' | python3 -m json.tool
oc get pods -n <target-namespace>          # the transfer pod, named <vm-name>-<n>-<suffix>
oc logs -n <target-namespace> <transfer-pod> -c virt-v2v --tail=80   # if anything fails
```
Expected phase sequence: `Initialize → DiskAllocation → ImageConversion → DiskTransferV2v → VirtualMachineCreation`, all reaching `Completed`. Overall VM condition should end as `Succeeded=True`. Disk copy time scales with used disk size and ESXi-to-cluster network throughput. See the Known Issues catalog below for what each failure mode looks like and how to fix it.

---

## Step 11 — Post-migration validation

```bash
oc get vm <vm-name> -n <target-namespace>              # should exist, Stopped (cold migration leaves it off)
oc patch vm <vm-name> -n <target-namespace> --type=merge -p '{"spec":{"running":true}}'
oc get vmi <vm-name> -n <target-namespace> -o wide      # wait for Running / Ready=True
oc get vmi <vm-name> -n <target-namespace> -o jsonpath='{.status.conditions}'
oc get vmi <vm-name> -n <target-namespace> -o jsonpath='{.status.interfaces}'
```
Two checks confirm a genuinely successful migration, not just object creation:
- **`AgentConnected=True`** in `status.conditions` — the in-guest qemu-guest-agent checked in over virtio-serial, meaning the guest OS actually booted and its service stack came up.
- **MAC address in `status.interfaces[0].mac`** matches the original ESXi vNIC's MAC (VMware OUI prefix `00:0c:29:...`) — confirms this is the migrated disk/identity, not a coincidentally-booting fresh VM.

Open the VM's console (`virtctl console <vm-name> -n <target-namespace>`, or the web console's Console tab) to visually confirm the boot completed, check `df -h`/`journalctl -xe` for boot errors, and specifically walk the UEFI/Secure Boot path if the source VM used it. Since pod network is in use, expect a **new cluster IP**, not the VM's old ESXi static IP — see Known Issue #10, this is currently a manual follow-up step, not automated.

---

## Known Issues & Fixes — full catalog (both POC sessions combined)

| # | Symptom | Root Cause | Fix |
|---|---|---|---|
| 1 | Can't do warm migration | No vCenter = no CBT-based snapshot chain for live cutover; also, `concerns[]` on the VM inventory explicitly flags "CBT not enabled" | Cold migration only, on this source. Plan for VM downtime during transfer. |
| 2 | `PowerOffSource` pipeline step fails: `ServerFaultCode: Current license or ESXi version prohibits execution of the requested operation` | Free/restricted ESXi license blocks API-driven power control (and, separately, `HostNetworkSystem` config writes — same fault, hit independently when attempting a hostname fix via `pyvmomi`) | Manually shut down the guest OS via SSH before starting the migration (Step 6). Forklift skips the API call if the VM is already off. |
| 3 | `ConvertGuest`/`ImageConversion` fails: `IP address lookup for host '<esxi-hostname>' failed: Name or service not known` | `virt-v2v`'s `esx://` libvirt URI uses the ESXi host's **self-reported hostname**, not the Provider's configured IP/URL. That hostname has no DNS record reachable from the migration pod. | Add an A record for the exact self-reported hostname on whatever DNS server the OCP nodes use upstream (see "Before you start" item B). |
| 4 | `ConvertGuest` fails: `server does not support 'range' (byte range) requests` | No VDDK configured on the Provider — Forklift fell back to `nbdkit`'s `curl`/HTTPS/NFC transport, which this ESXi host's HTTP server doesn't support in the way `nbdkit` needs | Build and configure a VDDK init image (Step 2–3) *before* the first migration attempt, not after. Do not mistake this for a snapshot problem (see #5). |
| 5 | Same byte-range error persists after removing a snapshot | Snapshot was a red herring — don't assume a checklist item is the root cause without confirming after the actual fix | Confirm VDDK is really configured on the Provider (`oc get provider <name> -o jsonpath='{.spec.settings}'`) before spending another retry cycle chasing snapshots. |
| 6 | `ConvertGuest` fails: `libvixDiskLib.so.8: cannot open shared object file` | VDDK 9.x ships `libvixDiskLib.so.9`; this MTV version's `nbdkit-vddk-plugin` expects the older `.so.8` SONAME | Add a symlink in the VDDK image: `ln -sf libvixDiskLib.so.9 libvixDiskLib.so.8` (Step 2). |
| 7 | Same `.so.8` error persists after adding the symlink | Symlink target used an **absolute path** (e.g. `/vmware-vix-disklib-distrib/lib64/libvixDiskLib.so.9.1.0.0`). The init container's `ENTRYPOINT` copies the whole directory to a *different* path (`/opt/vmware-vix-disklib-distrib`) at runtime, and the symlink kept pointing at the old absolute location, which no longer exists there. | Use a **bare relative filename** as the symlink target (`ln -sf libvixDiskLib.so.9 libvixDiskLib.so.8`, run from inside `lib64/`) so it resolves relative to wherever the directory ends up. Verify with `podman run --entrypoint sh ... ls -la` before pushing. |
| 8 | Plan stuck at `ValidatingVDDK` indefinitely, or `VDDKInvalid` | The VDDK-validator Job (created in the **target namespace**, not `openshift-mtv`) can't pull the VDDK image from `openshift-mtv`'s internal imagestream — OpenShift's internal registry enforces per-namespace pull auth | `oc policy add-role-to-user system:image-puller system:serviceaccount:<target-namespace>:default -n openshift-mtv` (Step 5), done *before* creating the Plan. |
| 9 | Plan validation takes >2 minutes on first attempt after this RBAC fix | Not a bug — the validator pod's *second* init container (`mtv-virt-v2v-rhel9`, the actual validation logic) is a large image being pulled from `registry.redhat.io` for the first time on that node | Just wait; subsequent Plans on the same node reuse the cached image and validate in seconds. |
| 10 | Migrated VM boots (`AgentConnected=True`) but `status.interfaces` shows no IP even ~15 minutes after boot | **Unresolved / open in both POC sessions.** VM's guest network config still reflects its old ESXi static-IP setup; pod-network (masquerade) binding needs the guest to either DHCP or be given a new static IP in the pod-network's subnet | Needs an interactive console login (`virtctl console`) post-migration to check/fix guest networking (`nmcli`, `ip a`, `/etc/sysconfig/network-scripts/` or `nmconnection` files depending on RHEL version). Not yet automated — treat as a required manual post-migration step until scripted. |
| 11 | Provider misconfigured with wrong URL/port (e.g. `192.168.29.99:9460` instead of the real ESXi IP) | Simple typo/stale config carried over from an earlier attempt | Always re-verify `oc get provider <name> -o jsonpath='{.spec.url}'` matches the actual ESXi management IP before troubleshooting anything deeper. |

---

## Reusable assets

- **VDDK image** (Step 2), once built and pushed, is reusable for every future ESXi Provider in this cluster — no need to rebuild per VM or per host.
- **DNS records** (item B) are per-ESXi-host, not per-VM — one record covers every VM migrated from that host.
- **Cross-namespace RBAC** (Step 5) is per-target-namespace — grant it once per namespace, not per migration.

---

## Risk areas still worth a second look before a production/bulk pass

| Risk | Why it matters |
|---|---|
| ESXi license tier (Known Issue #2) | Structural blocker for any automation of power control; confirm before promising a "hands-off" bulk migration process |
| Guest networking post-migration (Known Issue #10) | Currently a manual step per VM; will not scale to a bulk migration without a scripted fix |
| UEFI/Secure Boot source VMs | Boots fine on the target template in testing so far, but Secure Boot itself is dropped (KubeVirt doesn't support it) — verify per-VM if Secure Boot is a hard guest requirement |
| USB controllers, CBT-not-enabled | Both surfaced in inventory `concerns[]` for the test VM — USB devices are silently dropped, CBT-not-enabled blocks warm migration specifically |
| No NTP in this lab | Minor clock drift risk on longer transfers; not observed to be an issue for small VMs/short transfers so far |

---

*Live-tested procedure for the ESXi8 → OCP MTV cold migration POC. See also [`11-pre-ESXi-OCP-Live-cluster-validation-checklist.md`](./11-pre-ESXi-OCP-Live-cluster-validation-checklist.md) for cluster readiness validation and deeper mechanics explanations (Secret/Provider/VDDK/virt-v2v/VMI).*
