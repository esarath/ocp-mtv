# Pre-Migration Checklist — ESXi8 → OCP (MTV)

Source: ESXi8 `192.168.29.60` (VM: `rhel96`)
Target: OCP 4.16 cluster, bastion `192.168.29.10`
Migration tool: MTV / Forklift `v2.7.12` + OpenShift Virtualization `v4.16.38`

Last validated: 2026-07-10

---

## 1. ESXi Source Host

| # | Check | Result | Status |
|---|---|---|---|
| 1 | ESXi version | 8.0.3 build 24677879 | ✅ |
| 2 | Licensing | vSphere 8 Hypervisor (paid serial, API access allowed) | ✅ |
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
| 17 | Provider: `esxi-lab` (source) | Was misconfigured — wrong URL `192.168.29.99:9460` (should be `.60`), phase `Staging`, TLS test failing | ✅ Fixed — patched to `https://192.168.29.60/sdk`; now `Ready / Connected / Inventory=True` |
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
