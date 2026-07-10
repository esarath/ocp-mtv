# Step-by-Step POC Execution Procedure — ESXi8 → OCP MTV Migration (Web Console)

Based on validated state from [`11-pre-ESXi-OCP-Live-cluster-validation-checklist.md`](./11-pre-ESXi-OCP-Live-cluster-validation-checklist.md).

- Source: ESXi8 `192.168.29.60`, VM `rhel96` (RHEL 9, 1 vCPU / 2GB, UEFI+SecureBoot, pvscsi, vmxnet3)
- Target: OCP 4.16 cluster (console: `https://console-openshift-console.apps.lab.ocp.local`)
- Providers already configured: `esxi-lab` (source, Ready) and `host` (target, Ready)
- Networking decision: **pod network** (no NAD — see Section 3 of the validation checklist)
- Storage: `nfs-storage` (default) or `mtv-storage`

**Progress tracker:** Step 1–2 (console/provider checks) → walk through in console. Step 3 (NetworkMap) → ✅ done. Step 4 (StorageMap) → ✅ done. Step 5 (Plan) → ✅ created, not yet started. Step 6 onward → pending, follow via web console.

---

## Step 1 — Log in to the OCP Web Console

1. Navigate to `https://console-openshift-console.apps.lab.ocp.local`
2. Log in with your cluster-admin credentials (kubeadmin or your configured identity provider account).
3. In the left nav, switch to the **Administrator** perspective (not Developer) — MTV/Migration menus live there.

---

## Step 2 — Confirm Providers Are Ready

1. Left nav → **Migration** → **Providers for virtualization** (namespace: `openshift-mtv`).
2. Confirm you see:
   - `esxi-lab` — Type `vsphere`, Status `Ready`
   - `host` — Type `openshift`, Status `Ready`
3. Click `esxi-lab` → **VirtualMachines** tab → confirm `rhel96` appears in the inventory list.

If either provider shows anything other than `Ready`, stop and re-check — do not proceed to Step 3.

---

## Step 3 — Create a Network Map ✅ DONE

**Status: Completed via CLI on 2026-07-10.** You can view it as-is in the console, or use these console steps to recreate/verify:

1. Left nav → **Migration** → **NetworkMaps for virtualization** → **Create NetworkMap**.
2. Name: `esxi-to-ocp-podnetwork`
3. Source provider: `esxi-lab`
4. Target provider: `host`
5. Map the source network (`VM Network`) to target: select **Pod Networking** (this is the decision recorded in the checklist — no NAD/Multus binding is used, since worker nodes have no spare NIC for a dedicated bridge).
6. Save.

**Result (verify in console under Migration → NetworkMaps for virtualization):**

| Field | Value |
|---|---|
| Name | `esxi-to-ocp-podnetwork` |
| Namespace | `openshift-mtv` |
| Source provider | `esxi-lab` |
| Destination provider | `host` |
| Mapping | `"VM Network"` (vsphere) → **Pod Networking** |
| Status | `Ready = True` — "The network map is ready." |

**YAML applied:**
```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: NetworkMap
metadata:
  name: esxi-to-ocp-podnetwork
  namespace: openshift-mtv
spec:
  provider:
    source:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: Provider
      name: esxi-lab
      namespace: openshift-mtv
    destination:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: Provider
      name: host
      namespace: openshift-mtv
  map:
    - source:
        name: "VM Network"
        type: vsphere
      destination:
        type: pod
```

---

## Step 4 — Create a Storage Map ✅ DONE

**Status: Completed via CLI on 2026-07-10.** You can view it as-is in the console, or use these console steps to recreate/verify:

1. Left nav → **Migration** → **StorageMaps for virtualization** → **Create StorageMap**.
2. Name: `esxi-to-ocp-storage`
3. Source provider: `esxi-lab`
4. Target provider: `host`
5. Map the source datastore (`datastore-1`) to a target StorageClass:
   - Use **`nfs-storage`** (cluster default) unless you specifically want `mtv-storage`.
6. Save.

**Result (verify in console under Migration → StorageMaps for virtualization):**

| Field | Value |
|---|---|
| Name | `esxi-to-ocp-storage` |
| Namespace | `openshift-mtv` |
| Source provider | `esxi-lab` |
| Destination provider | `host` |
| Mapping | `datastore-1` (vsphere) → StorageClass `nfs-storage`, access mode `ReadWriteOnce` |
| Status | `Ready = True` — "The storage map is ready." |

**YAML applied:**
```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: StorageMap
metadata:
  name: esxi-to-ocp-storage
  namespace: openshift-mtv
spec:
  provider:
    source:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: Provider
      name: esxi-lab
      namespace: openshift-mtv
    destination:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: Provider
      name: host
      namespace: openshift-mtv
  map:
    - source:
        name: "datastore-1"
        type: vsphere
      destination:
        storageClass: nfs-storage
        accessMode: ReadWriteOnce
```

---

## Step 5 — Create the Migration Plan ✅ DONE (not yet started)

**Status: Plan created via CLI on 2026-07-10. Status = `Ready: True`. Migration has NOT been started yet — Steps 6–8 are still pending.**

Console steps to recreate/verify:

1. Left nav → **Migration** → **Plans for virtualization** → **Create Plan**.
2. Name: `rhel96-migration-poc`
3. Source provider: `esxi-lab`
4. Target provider: `host`
5. Target namespace/project: choose or create one (e.g., `rhel96-vms`).
6. Select VM: `rhel96` from the inventory list.
7. Network map: `esxi-to-ocp-podnetwork` (from Step 3)
8. Storage map: `esxi-to-ocp-storage` (from Step 4)
9. Migration type: **Cold migration** (VM will be powered off during transfer — recommended for this POC; warm migration needs a running CBT snapshot chain and vCenter, which isn't available on a standalone ESXi host).
10. Review the **VM firmware/preferences** on the plan's VM details page:
    - Confirm **UEFI** is selected as firmware type.
    - Confirm **Secure Boot** is enabled to match the source (`uefi.secureBoot.enabled = TRUE` on ESXi).
    - **Not yet verified — do this in the console before starting the plan.**
11. Save the plan (do **not** start it yet).

**Result (verify in console under Migration → Plans for virtualization):**

| Field | Value |
|---|---|
| Name | `rhel96-migration-poc` |
| Namespace | `openshift-mtv` |
| Source provider | `esxi-lab` |
| Destination provider | `host` |
| Target namespace | `rhel96-vms` (newly created) |
| Network map | `esxi-to-ocp-podnetwork` |
| Storage map | `esxi-to-ocp-storage` |
| Migration type | Cold (`warm: false`) |
| VM(s) | `rhel96` |
| Status | `Ready = True` — "The migration plan is ready." |
| Executed? | **No — not started.** `.status.migration.vms` is empty. |

**YAML applied:**
```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: Plan
metadata:
  name: rhel96-migration-poc
  namespace: openshift-mtv
spec:
  description: "POC cold migration of rhel96 from standalone ESXi8 to OCP via MTV"
  provider:
    source:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: Provider
      name: esxi-lab
      namespace: openshift-mtv
    destination:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: Provider
      name: host
      namespace: openshift-mtv
  targetNamespace: rhel96-vms
  warm: false
  map:
    network:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: NetworkMap
      name: esxi-to-ocp-podnetwork
      namespace: openshift-mtv
    storage:
      apiVersion: forklift.konveyor.io/v1beta1
      kind: StorageMap
      name: esxi-to-ocp-storage
      namespace: openshift-mtv
  vms:
    - name: rhel96
```

**Note:** Target namespace `rhel96-vms` did not exist and was created (`oc create namespace rhel96-vms`) before applying the plan.

---

### Issues & Fixes During Migration Execution

The migration required **6 attempts** before succeeding. Each failure and fix is recorded here in order for future reference/troubleshooting.

| Attempt | Result | Root Cause | Fix Applied |
|---|---|---|---|
| **Pre-migration** | Snapshot taken for rollback (`pre-migration-snapshot`) before powering off `rhel96` | N/A — precautionary step | N/A |
| **run1** | ❌ Failed at `ConvertGuest` | `virt-v2v` builds an `esx://root@ESXi8.ocp.local` libvirt URI using the ESXi host's **self-reported hostname** (from `esxcli system hostname get`), not the IP used in the Provider config. This hostname had no DNS record reachable from the OCP pod network. Error: `IP address lookup for host 'ESXi8.ocp.local' failed: Name or service not known` | Identified the bastion (`192.168.29.10`) runs BIND (`named`) for zone `ocp.local` (`/var/named/ocp.local.zone`). Added an A record: `ESXi8 IN A 192.168.29.60`, bumped the SOA serial, ran `rndc reload ocp.local`. Verified resolution both on the bastion (`dig`) and from inside the cluster pod network (`getent hosts` in a test pod). |
| **run2** | ❌ Failed at `ConvertGuest` | New error: `server does not support 'range' (byte range) requests` when `nbdkit`'s `curl` plugin read the VMDK over HTTPS from ESXi. Initially suspected the `pre-migration-snapshot` (reading a delta disk) as the cause. | Removed the snapshot (`vim-cmd vmsvc/snapshot.removeall`), flattening the disk back to base `rhel10.vmdk`. |
| **run3** | ❌ Failed — **same exact error** | Snapshot removal did not fix it — confirmed the snapshot was a **red herring**. Real cause: the `esxi-lab` Provider had **no VDDK init image configured** (`spec.settings` only had `sdkEndpoint: esxi`). Without VDDK, Forklift falls back to the HTTPS/NFC transport via `nbdkit-curl`, which doesn't support byte-range reads against this ESXi host's HTTP server — a known incompatibility. | Retrieved user-downloaded VDDK tarball (`VMware-vix-disklib-9.1.0.0.25379531.x86_64.tar.gz`, from Broadcom support portal) from host `tiny1` (192.168.29.2). Built a VDDK init container image on the OCP bastion using `podman` with the standard Red Hat MTV Dockerfile pattern (`FROM ubi8/ubi:8.6`, `COPY vmware-vix-disklib-distrib`, `ENTRYPOINT ["cp","-r",...,"/opt"]`). Pushed to OCP's internal registry (`openshift-mtv/vddk:9.1.0`). Patched provider: `spec.settings.vddkInitImage`. Granted cross-namespace image-pull RBAC (`system:image-puller` role bound to `system:serviceaccounts:rhel96-vms` in `openshift-mtv`). |
| **run4** | ❌ Failed at `ConvertGuest` | VDDK now loading, but new error: `libvixDiskLib.so.8: cannot open shared object file`. VDDK 9.1.0 only ships `libvixDiskLib.so.9`; this MTV version's `virt-v2v`/`nbdkit-vddk` plugin expects the older `.so.8` SONAME. | Added a compatibility symlink in the image: `ln -sf libvixDiskLib.so.9.1.0.0 libvixDiskLib.so.8`. First attempt used an **absolute path** for the symlink target — wrong, see run5. |
| **run5** | ❌ Failed — **same `.so.8` error persisted** | The absolute-path symlink (`/vmware-vix-disklib-distrib/lib64/...`) broke because the init container's `ENTRYPOINT` copies the whole directory to `/opt/vmware-vix-disklib-distrib` at runtime — the symlink kept pointing to the original (non-existent, in the shared volume) absolute path instead of resolving relative to its new location. | Rebuilt the image with a **relative** symlink (`cd lib64 && ln -sf libvixDiskLib.so.9.1.0.0 libvixDiskLib.so.8`), matching the pattern VMware's own `.so`/`.so.9` symlinks already used. Verified directly with `podman run --entrypoint sh ... ls -la lib64/` before pushing. Pushed as `vddk:9.1.0-compat8v2`, re-patched provider. |
| **run6** | ✅ **SUCCEEDED** | — | Full pipeline completed: `Initialize` → `DiskAllocation` (16384 MB) → `ImageConversion` → `DiskTransferV2v` (16384/16384 MB transferred) → `VirtualMachineCreation`. Migration condition: `"The migration has SUCCEEDED."` VM object `rhel96` created in `rhel96-vms` namespace (`Stopped` initially, as expected for cold migration). Started via `virtctl start rhel96 -n rhel96-vms` → `Running`, `Ready: True`. Guest agent confirmed live: `guestOSInfo` reported RHEL 9.6, kernel `5.14.0-570.12.1.el9_6.x86_64` — UEFI/Secure Boot boot path succeeded with no issues. |

**Key lessons for future ESXi(standalone)-to-OCP MTV migrations:**
1. **DNS matters even for IP-based provider URLs** — Forklift/`virt-v2v` may still resolve the ESXi host's own reported hostname internally; ensure it's resolvable from the OCP pod network, not just the Provider's configured URL.
2. **VDDK is effectively required** for standalone ESXi sources (no vCenter) — the non-VDDK HTTPS fallback transport is unreliable (byte-range support issues observed here).
3. **VDDK version vs. MTV compatibility**: MTV 2.7.12's `virt-v2v` expects VDDK's `.so.8` SONAME; only VDDK 9.1.0 (`.so.9`) was available at migration time. A relative symlink workaround was needed — **use a relative symlink**, not absolute, since the VDDK init container's contents get copied to a different path (`/opt/...`) at runtime via its `ENTRYPOINT`.
4. **Snapshots are not the real blocker for cold migration** in this environment — don't assume a checklist item (like "no snapshots") is the root cause without confirming after the fix; this cost one full retry cycle here.
5. **Unresolved at end of session**: the migrated VM's guest network config was still using its old ESXi static-IP setup; `status.interfaces` on the VMI had no IP populated even ~15 minutes after boot. Needs a console login to check/fix (`nmcli`/`ip` inside the guest) — likely needs to switch to DHCP for the pod-network masquerade binding to assign an address, or set a new static IP in the correct subnet.

---

## Step 6 — Validate the Plan

1. Open the created plan → check the **Status** column shows `Ready` (green), not `Warning`/`Critical`.
2. Click into the plan → **VMs** tab → confirm `rhel96` shows no validation errors (e.g., no leftover CD-ROM/ISO warning — this was already fixed at the source).
3. Confirm target namespace has enough resource quota (if any ResourceQuota exists in that namespace) for 1 vCPU / 2GB.

---

## Step 7 — Power Off the Source VM (Cold Migration Prerequisite)

1. On ESXi (via `vim-cmd vmsvc/power.off <vmid>` or vSphere client), power off `rhel96` before starting the migration — cold migration requires the source VM to be off, or MTV will prompt/auto-handle shutdown depending on plan settings.
2. Confirm `rhel96` shows `poweredOff` before starting the plan.

---

## Step 8 — Start the Migration

1. Back in **Plans for virtualization**, select `rhel96-migration-poc` → **Actions** → **Start**.
2. Monitor progress in the plan's **VMs** tab — it will show phase transitions: `Initializing` → `CopyingDisks` → `ConvertingGuest` → `Completed`.
3. Disk copy time depends on the ~19GB used disk size and network throughput between ESXi (`192.168.29.60`) and the OCP cluster.

---

## Step 9 — Post-Migration Validation

1. Once the plan shows `Succeeded`, go to **Virtualization** → **VirtualMachines** in the target namespace (`rhel96-vms`).
2. Confirm `rhel96` VM object exists and is **Running** (MTV starts it automatically after conversion, unless configured otherwise).
3. Open the VM's **Console** tab in the web console → verify RHEL9 boots successfully (UEFI/Secure Boot boot path is the main risk area — this is why Step 5.10 matters).
4. Confirm network connectivity:
   - Since pod network is used, the VM will get a **new IP** (not `192.168.29.61`). Check via console `ip a` or the VM's **Details** tab.
   - Test connectivity to/from the VM within the cluster (e.g., `oc rsh` into another pod and ping/curl the VM's new pod-network IP, or check via VM's `virtctl console`).
5. Confirm the VM's disk (root filesystem) mounted correctly and no data corruption — check `df -h`, `journalctl -xe` inside the guest for boot errors.

---

## Step 10 — Cleanup / Decision Point

1. If validation passes: decide whether to keep the ESXi source VM powered off (as rollback option) or decommission it.
2. If validation fails: check the plan's **Events**/logs in the console, and the `forklift-controller` pod logs (`oc logs -n openshift-mtv deploy/forklift-controller`) for root cause before retrying.
3. Record the outcome (success/failure, new VM IP, any issues) back into this repo for the POC record.

---

## Known Risk Areas to Watch During Execution

| Risk | Why | Where it surfaces |
|---|---|---|
| UEFI/Secure Boot mismatch | Source has Secure Boot enabled; target VM template must match or boot will fail | Step 5.10, Step 9.3 |
| New IP on pod network | Any hardcoded reference to `192.168.29.61` (DNS, /etc/hosts, app config) will break | Step 9.4 |
| Cold migration only | No vCenter means no CBT-based warm migration; VM must be powered off during transfer, causing downtime | Step 7 |
| No NTP source in lab | Minor clock drift possible over long migrations; not expected to be an issue for this small VM/short transfer | N/A — informational |

---

*Prepared as part of the ESXi8 → OCP MTV POC. See also: [`11-pre-ESXi-OCP-Live-cluster-validation-checklist.md`](./11-pre-ESXi-OCP-Live-cluster-validation-checklist.md) for the underlying validation results.*
