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
