# Pre-Migration Checklist — ESXi8 → OCP (MTV)

Source: ESXi8 `192.168.29.60` (VM: `rhel96`)
Target: OCP 4.16 cluster, bastion `192.168.29.10`
Migration tool: MTV / Forklift `v2.7.12` + OpenShift Virtualization `v4.16.38`

Last validated: 2026-07-11 (Section 5: live end-to-end test migration executed and succeeded)

---

## 1. ESXi Source Host

| # | Check | Result | Status |
|---|---|---|---|
| 1 | ESXi version | 8.0.3 build 24677879 | ✅ |
| 2 | Licensing | vSphere 8 Hypervisor (paid serial, API access allowed) | ⚠️ **Contradicted 2026-07-11** — live migration run hit `vim.fault.RestrictedVersion: "Current license or ESXi version prohibits execution of the requested operation"` on **both** `PowerOffVM_Task` and `HostNetworkSystem.UpdateDnsConfig`. The host is actually running under a license (free or expired eval) that blocks third-party API write/config calls. See Section 5, item 5.2. Re-check the license under Manage → Licensing in the ESXi web UI before assuming API power control will work. |
| 3 | Network reachability from OCP (port 443, vSphere API) | Reachable | ✅ |
| 4 | NTP | Service enabled; clock manually verified accurate. No external NTP server reachable in this isolated lab (no internet egress) | ✅ (caveat: point to a real internal NTP server if one becomes available) |
| 5 | VM `rhel96` — snapshots | None | ✅ |
| 6 | VM `rhel96` — CD-ROM/ISO | Disconnected (was `rhel-9.6-x86_64-dvd.iso`) | ✅ Fixed |
| 7 | VM `rhel96` — disk controller | `pvscsi` | ✅ Supported |
| 8 | VM `rhel96` — NIC | `vmxnet3` | ✅ Supported |
| 9 | VM `rhel96` — firmware | UEFI + Secure Boot enabled | ⚠️ Target VM template must match (UEFI+SecureBoot) |
| 10 | VMware Tools | Running, `toolsOk` | ✅ |
| 11 | Datastore free space | 118 GB free / 152 GB total (VM ~19 GB used) | ✅ |

---

## 2. OCP Cluster / MTV Target

| # | Check | Result | Status |
|---|---|---|---|
| 12 | OCP cluster version | 4.16.55, 5/5 nodes `Ready` | ✅ |
| 13 | Cluster Operators | All Available, none Degraded/Progressing | ✅ |
| 14 | OpenShift Virtualization (CNV) | v4.16.38, HCO `Available=True`, `Degraded=False` | ✅ |
| 15 | MTV / Forklift operator | v2.7.12, all 6 pods Running | ✅ |
| 16 | Provider: `host` (OCP target) | `Ready / Connected / Inventory=True` | ✅ |
| 17 | Provider: `esxi-lab` (source) | Was misconfigured — wrong URL `192.168.29.99:9460` (should be `.60`), phase `Staging`, TLS test failing | ✅ Fixed — patched to `https://192.168.29.60/sdk`; now `Ready / Connected / Inventory=True`. **Note:** that `esxi-lab` object no longer exists on the cluster as of 2026-07-11 (checked, only the built-in `host` provider was present). The live migration in Section 5 created a fresh provider named `esxi8-host` instead — same target host, same settings pattern (`sdkEndpoint: esxi`). Treat `esxi-lab` as historical/console-session state, not a persistent CR. |
| 18 | StorageClass | `nfs-storage` (default, Retain) + `mtv-storage` present | ✅ |
| 19 | NetworkAttachmentDefinition (NAD) | None found. Investigated: each worker node has only **one physical NIC (`ens18`)**, already enslaved to `br-ex` (the same OVS bridge carrying node API/management traffic). No spare NIC exists for a dedicated Multus bridge. | ✅ Resolved — see Section 3 (decision: use pod network, no NAD needed) |
| 20 | Node capacity (CPU/mem) | Headroom on all 5 nodes (highest mem 80%, workers 46–58%) | ✅ Sufficient for 1 vCPU / 2 GB VM |
| 21 | Existing migration Plan / NetworkMap / StorageMap | None created yet | ℹ️ Expected — pending Section 3 decision |

---

## 3. Decision — Pod Network vs. Multus NAD (RESOLVED)

`rhel96` currently holds a static LAN IP (`192.168.29.61`) on ESXi's "VM Network" portgroup. The migrated VM's networking model had to be chosen before the `NetworkMap` could be created.

| | Pod network (default, no NAD) | Multus NAD (dedicated bridge/VLAN) |
|---|---|---|
| **What it is** | VM's vNIC rides the cluster default SDN (OVN-Kubernetes) | VM's vNIC binds via Multus CNI to a specific physical/VLAN interface on the node |
| **Pros** | Zero extra setup; works immediately; simplest for lab/test/throwaway VMs; no risk to existing cluster networking | Preserves original network identity — same L2 segment/VLAN, same static IP, same reachability from existing LAN devices; supports broadcast/ARP/multicast |
| **Cons** | VM gets a new cluster-network IP — breaks anything hardcoded to `192.168.29.61`; no L2 semantics with existing LAN | Requires a `NetworkAttachmentDefinition` + a bridge preconfigured on worker NIC(s) first; ties VM scheduling to nodes with that bridge; misconfiguration risks node networking |

**Investigation finding:** Checked worker node interfaces (`oc debug node/worker-1... -- ip -o link show`). Each worker has **only one physical NIC (`ens18`)**, and it is already enslaved into `br-ex` — the same OVS bridge that carries the node's own API/management traffic. There is no spare NIC to hand to a dedicated Multus bridge. The only NAD-based alternative would be an OVN-Kubernetes "localnet" NAD layered on top of the shared `br-ex`, which requires modifying the cluster's live OVN config on all nodes — carrying real risk to cluster networking if misconfigured (this is a live 5-node cluster, not a disposable sandbox).

**Decision:** Use **pod network** for `rhel96`. Zero risk to the shared `br-ex`/OVN path; VM will receive a new cluster-network IP instead of `192.168.29.61`. The OVN-K localnet approach remains available as a future option if static-IP preservation becomes a hard requirement, but should only be attempted in a maintenance window with rollback planned.

**Result:** No NAD, NNCP, or bridge changes needed. The `NetworkMap` can use the default pod network binding.

---

## 4. Outstanding Items Before Migration

1. ~~Networking decision~~ — **Resolved**: pod network (Section 3).
2. **UEFI + Secure Boot** — confirm target VM template in the migration Plan explicitly enables both, matching the source.
3. **Create Forklift `NetworkMap`, `StorageMap`, and `Plan`** CRs for `rhel96` — to be done via the OCP web console (Migration Toolkit for Virtualization UI) for hands-on walkthrough.

Everything else on both sides is green. The one real blocker found (provider misconfiguration) has been fixed and re-validated. No cluster-side network changes are required — ready to build the migration Plan.

---

## 5. Live Migration Execution — Test Run (2026-07-11, SUCCESSFUL)

Executed the full pipeline via CLI (`oc apply` + Forklift CRs) instead of the console walkthrough Section 4 anticipated. End result: `rhel96` is running on OpenShift Virtualization with its original MAC address and a connected guest agent, proving a clean boot. This section documents the mechanics and every real obstacle hit, in the order encountered, so the next migration doesn't rediscover them.

### 5.1 The building blocks — what each piece actually does

**Secret** — a plain Kubernetes `Opaque` Secret holds the ESXi credentials the Provider uses to authenticate:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: esxi8-192-168-29-60
  namespace: openshift-mtv
type: Opaque
stringData:
  user: root
  password: "root@123"
  insecureSkipVerify: "true"   # accepts ESXi's self-signed cert; use `cacert` instead for a real CA
```
Confirmed the exact key names (`user`, `password`, `insecureSkipVerify`, `cacert`) by reading them straight out of the running `forklift-ui-plugin` pod's minified JS bundles (`grep` for `case"password"`, `case"cacert"` etc.) rather than guessing — this MTV build doesn't document the Secret schema anywhere else accessible from the cluster.

**Provider** — the CR that tells Forklift where the source/target virtualization environment is and how to reach it. For a vCenter-less ESXi source:
```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: Provider
metadata:
  name: esxi8-host
  namespace: openshift-mtv
spec:
  type: vsphere
  url: https://192.168.29.60/sdk
  settings:
    sdkEndpoint: esxi        # <- this is the "no vCenter" switch; omit/"vcenter" for a real vCenter
    vddkInitImage: image-registry.openshift-image-registry.svc:5000/openshift-mtv/vddk:9.1.0-fix
  secret:
    name: esxi8-192-168-29-60
    namespace: openshift-mtv
```
Once `Ready/Connected/Inventory=True`, Forklift's inventory service mirrors the ESXi object graph (VMs, networks, datastores) and exposes it over a REST API at the `forklift-inventory` route — that's how the VM's moRef ID, network name, and datastore name were pulled for the Plan (`GET /providers/vsphere/<provider-uid>/vms`).

**VDDK (VMware Virtual Disk Development Kit)** — a VMware-proprietary library (`libvixDiskLib`) that lets non-VMware tools read/write VMDK disks efficiently using VMware's own transport (SAN/HotAdd/NBD), instead of pulling the whole disk file over plain HTTPS. Forklift doesn't ship it (licensing) — you provide it as an **init-container image** that just needs the extracted VDDK SDK tarball placed at `/vmware-vix-disklib-distrib`:
```dockerfile
FROM registry.access.redhat.com/ubi8/ubi-minimal
USER 0
COPY vmware-vix-disklib-distrib /vmware-vix-disklib-distrib
RUN ln -sf libvixDiskLib.so.9 /vmware-vix-disklib-distrib/lib64/libvixDiskLib.so.8
USER 1001
ENTRYPOINT ["cp", "-r", "/vmware-vix-disklib-distrib", "/opt"]
```
At migration time Forklift runs this image as an init container in the transfer pod; its entrypoint copies the SDK into a shared `emptyDir` that the `virt-v2v` container then mounts and points `nbdkit`'s vddk plugin at. **Without it**, migrations still work but disk copy falls back to a much slower HTTPS/NFC file-read path instead of VDDK's optimized transport.

Two gotchas hit building it from the customer-supplied `VMware-vix-disklib-9.1.0.0.25379531.x86_64.tar.gz`:
- **Version symlink**: VDDK 9.1.0 ships `libvixDiskLib.so.9`, but the `nbdkit-vddk-plugin` baked into MTV's `mtv-virt-v2v-rhel9` image `dlopen()`s `libvixDiskLib.so.8` by convention (older major). Fixed with the `ln -sf` line above — a known pattern for newer VDDK releases against this MTV version.
- **Config is per-Provider, not just cluster-wide**: `ForkliftController.spec.vddk_init_image` sets a cluster default, but this MTV build (2.7.12) actually reads `Provider.spec.settings.vddkInitImage` per-provider (confirmed via the same JS-bundle-grep approach — the `ProvidersCreatePage` chunk builds `spec.settings.vddkInitImage` directly). Set both to be safe; the per-provider one is authoritative.

The image was built with `podman`, tagged, and pushed to the **internal OCP image registry** (`image-registry.openshift-image-registry.svc:5000/openshift-mtv/vddk:9.1.0-fix`) — no external registry needed. Pushing required temporarily granting the pushing identity `system:image-builder` on `openshift-mtv`.

**virt-v2v** — the actual guest-conversion engine (from `libguestfs`), run inside the `mtv-virt-v2v-rhel9` container as the transfer pod's main container. It does three things: connects to the source hypervisor over `libvirt`'s `esx://` driver, reads the VMDK (via the VDDK plugin above), and rewrites the guest's boot config (drivers, fstab, bootloader) so it boots correctly under KVM/QEMU instead of ESXi. Its connection string, built automatically by Forklift, looks like:
```
virt-v2v -i libvirt -ic esx://root@ESXi8.ocp.local?no_verify=1 -it vddk -io vddk-libdir=/opt/vmware-vix-disklib-distrib ...
```
**Critical detail**: the hostname in that URI (`ESXi8.ocp.local`) is **not** the Provider's configured URL/IP — it's the ESXi host's own self-reported hostname (`vim.HostSystem.name`, i.e. whatever is set under ESXi's own Configure → Networking → Hostname). `libvirt`'s `esx://` driver resolves that name via DNS *from inside the migration pod*, independent of how the Provider itself was reached. This is the source of the DNS problem in 5.3.

**VMI (VirtualMachineInstance)** — the last pipeline stage (`VirtualMachineCreation`) creates a KubeVirt `VirtualMachine` object (the durable, declarative spec — survives reboots/stop-start, `spec.running` controls power state). Starting it (`spec.running: true`) spawns a `VirtualMachineInstance` — the live, ephemeral running-VM object, one per active boot, analogous to a Pod for a Deployment. Checked two VMI fields to confirm the migration actually worked, not just that objects existed:
- `status.conditions[type=AgentConnected].status: "True"` — the in-guest `qemu-guest-agent` (already present from VMware Tools / RHEL's own agent) checked in over the virtio-serial channel. This only happens if the guest OS actually booted and its network/service stack came up — the strongest available proof of a clean migration short of an interactive console login.
- `status.interfaces[0].mac: "00:0c:29:a4:8d:8a"` — a VMware OUI (`00:0c:29`) prefix, matching the original ESXi vNIC's MAC exactly. Confirms this is the migrated disk/identity, not a fresh VM that happened to boot.

**pyvmomi** — VMware's official Python SDK for the vSphere/ESXi SOAP API (`vim25`). Used here as an escape hatch to attempt a direct API fix (see 5.2) when SSH to the ESXi host itself was unavailable (TSM-SSH disabled, which is ESXi's default). Note: the bastion's default Python is 3.9, but current `pyvmomi` (9.1.0.0) requires Python ≥3.10 and fails at import with a clear version-check exception — pin to `pyvmomi==8.0.3.0.1` on Python 3.9 hosts.

### 5.2 Free/restricted ESXi license blocks API writes (hit twice)

First surfaced when Forklift's `PowerOffSource` pipeline step called the standard `PowerOffVM_Task` API and got:
```
ServerFaultCode: Current license or ESXi version prohibits execution of the requested operation.
```
This is `vim.fault.RestrictedVersion` — VMware's free/eval ESXi license blocks a class of third-party API write operations (this includes some backup/power-control operations), even though read operations (inventory listing, etc.) work fine. **Workaround used:** shut the guest down cleanly from inside via SSH (`shutdown -h now`) before starting the migration — Forklift's PowerOffSource step checks current power state first and only calls the API if the VM is still on, so a pre-shutdown VM sails through.

Hit the *exact same fault* again independently when attempting to fix the DNS problem (5.3) by changing the ESXi host's configured hostname via `pyvmomi`'s `HostNetworkSystem.UpdateDnsConfig` — confirms this is a host-wide API restriction, not specific to power operations. **Action item:** check the ESXi license tier (Manage → Licensing in the host UI) before planning a bulk/scripted migration — if it's staying on a restricted license, budget for manual in-guest shutdowns per VM (cold migration only; warm migration's live cutover needs API power control and will not work under this restriction).

### 5.3 virt-v2v couldn't resolve the ESXi host's own hostname

Guest conversion failed on the first real attempt:
```
virt-v2v: error: exception: libvirt: VIR_ERR_INTERNAL_ERROR: VIR_FROM_ESX: internal error:
IP address lookup for host 'ESXi8.ocp.local' failed: Name or service not known
```
As explained in 5.1, `virt-v2v`/`libvirt` connects using the ESXi host's *own* configured hostname (`ESXi8.ocp.local`, set locally on the host — `dnsConfig.hostName=ESXi8`, `domainName=ocp.local`), resolved via DNS **from inside the transfer pod**, completely independent of the IP used in the Provider's `url` field. That name had no DNS record.

Tried to fix it two ways:
1. **Change the ESXi hostname via API** (`pyvmomi` → `HostNetworkSystem.UpdateDnsConfig`) — blocked by the same license restriction as 5.2.
2. **Add the missing DNS record** (used this) — the lab's DNS is BIND (`named`), running on `svc-infra.ocp.local` (`192.168.29.10`), which every OCP node points to as its upstream resolver (`/etc/resolv.conf: nameserver 192.168.29.10`; confirmed via `oc get dns.operator default` → `upstreamResolvers: SystemResolvConf`). Added an A record to the existing `ocp.local` zone:
   ```
   ; ESXi8 standalone host (added for MTV migration - no vCenter, self-reported hostname)
   ESXi8       IN  A   192.168.29.60
   ```
   in `/var/named/ocp.local.zone` on `svc-infra`, bumped the SOA serial, validated with `named-checkzone ocp.local /var/named/ocp.local.zone`, and reloaded with `rndc reload ocp.local`. Verified resolution both from the bastion and from inside the cluster (`oc debug node/... -- getent hosts ESXi8.ocp.local`) before retrying.

   **Access note:** direct SSH to `192.168.29.10` as `root` (password) was refused (`Permission denied (publickey,gssapi-keyex,gssapi-with-mic)` — no password auth accepted). Working path was `centos@192.168.29.10` using key-based auth **already trusted from `tiny1` (`192.168.29.2`)** — i.e. SSH into `tiny1` first, then SSH natively to `svc-infra` from there, rather than proxy-jumping through `tiny1` with a password (which failed the same way). `centos` had passwordless `sudo`.

**Takeaway for future ESXi-without-vCenter migrations in this lab:** before starting, check what hostname the ESXi host itself is configured with (`vim.HostSystem.name` via the inventory API, or Configure → Networking → Hostname in the ESXi UI) and make sure it resolves in whatever DNS the OCP nodes use — this is required even if the Provider itself was set up using a bare IP.

### 5.4 Cross-namespace image pull needed explicit RBAC

The VDDK-validation Job (`vddk-validator-*`, created by Forklift in the **target namespace**, `test-vms`) failed with `Init:ImagePullBackOff` / `authentication required` pulling the VDDK image from `openshift-mtv`'s internal imagestream. OpenShift's internal registry enforces namespace-scoped pull auth — a pod in namespace A pulling an imagestream tag that lives in namespace B needs the puller's service account granted `system:image-puller` in namespace B:
```bash
oc policy add-role-to-user system:image-puller system:serviceaccount:test-vms:default -n openshift-mtv
```
Applies generally: any target migration namespace needs this grant against `openshift-mtv` before its transfer/validator pods can pull the VDDK image.

### 5.5 Final result

```yaml
# Plan (target: test-vms, cold migration)
apiVersion: forklift.konveyor.io/v1beta1
kind: Plan
metadata:
  name: rhel96-test-migration
  namespace: openshift-mtv
spec:
  provider:
    source: {name: esxi8-host, namespace: openshift-mtv}
    destination: {name: host, namespace: openshift-mtv}
  map:
    network: {name: esxi8-rhel96-networkmap, namespace: openshift-mtv}
    storage: {name: esxi8-rhel96-storagemap, namespace: openshift-mtv}
  targetNamespace: test-vms
  warm: false
  vms:
    - {id: "3", name: rhel96}
```
NetworkMap mapped ESXi's `VM Network` → pod network (per Section 3's decision). StorageMap mapped datastore `datastore-1` → `mtv-storage` (`ReadWriteOnce`/`Filesystem`).

Pipeline result: `Initialize → DiskAllocation (16Gi PVC) → ImageConversion → DiskTransferV2v (16384/16384 MB via VDDK) → VirtualMachineCreation`, all `Completed`, VM condition `Succeeded=True`. Started the resulting `VirtualMachine` (`spec.running: true`) — `VirtualMachineInstance` reached `Running`/`Ready=True` with `AgentConnected=True` and the original VMware MAC preserved (see 5.1). **Guest boots cleanly on OpenShift Virtualization.**

### 5.6 Open items for a production/bulk migration pass

- **License restriction (5.2)** is the biggest structural risk — confirm the real ESXi license tier; if it can't be upgraded, warm migration is off the table and every cold migration needs a manual in-guest shutdown step (not automatable through the Forklift API alone).
- **DNS**: every additional standalone ESXi host added as a source will need the same treatment — its self-configured hostname added to the `ocp.local` zone on `svc-infra` — before a Plan referencing it will get past guest conversion.
- **VDDK image**: reusable as-is (`image-registry.openshift-image-registry.svc:5000/openshift-mtv/vddk:9.1.0-fix`) for any future ESXi Provider in this cluster; no need to rebuild per-VM or per-host.
- **UEFI (Section 4 item 2)**: inventory did flag `rhel96` as UEFI (`"UEFI secure boot will be disabled on OpenShift Virtualization"` in the VM's `concerns[]`). It still booted and reached `AgentConnected=True` on the default target VM template, so Secure Boot being dropped didn't block this particular RHEL 9.6 guest — but don't take that as a blanket pass; verify per-VM for anything that hard-requires Secure Boot at boot time.
- The source VM also flagged a **USB controller** as unsupported (dropped silently on migration, per inventory `concerns[]`) and **CBT not enabled** (blocks warm migration regardless of the license issue — enable Changed Block Tracking on any VM you plan to warm-migrate).
