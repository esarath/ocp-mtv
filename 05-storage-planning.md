# Storage Planning

**Document:** 05-storage-planning.md  
**Phase:** Storage Architecture and Configuration  
**Status:** Storage Implementation Guide

---

## Table of Contents
1. [Storage Architecture Overview](#storage-architecture-overview)
2. [Storage Class Configuration](#storage-class-configuration)
3. [Storage Capacity Planning](#storage-capacity-planning)
4. [Storage Performance Planning](#storage-performance-planning)
5. [Storage Mapping Strategy](#storage-mapping-strategy)
6. [Secrets and Password Management](#secrets-and-password-management)
7. [Non-OS Disks and LUNs](#non-os-disks-and-luns)
8. [Storage for Special Cases](#storage-for-special-cases)
9. [Storage Migration Procedures](#storage-migration-procedures)
10. [Storage Validation and Testing](#storage-validation-and-testing)
11. [Storage Troubleshooting](#storage-troubleshooting)

---

## Storage Architecture Overview

### Storage Design Principles

**Storage Hierarchy:**
- Tier 1: High-performance SSD storage (databases, critical applications)
- Tier 2: Standard HDD storage (application servers, web servers)
- Tier 3: File storage (NFS for shared data, backups)
- Tier 4: Archive storage (long-term retention)

**Storage Architecture Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    STORAGE ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────┘

VMware Storage                    OpenShift Storage
┌──────────────────────┐         ┌──────────────────────────────┐
│ VMware Datastores    │         │ OpenShift Storage Classes    │
│                      │         │                              │
│ ┌──────────────────┐ │         │ ┌────────────────────────┐  │
│ │ SSD Datastore     │─────────▶│ │ storage-class-ssd     │  │
│ │ (High Perf)       │ Mapping │ │ (High Performance)     │  │
│ └──────────────────┘ │         │ └────────────────────────┘  │
│                      │         │                              │
│ ┌──────────────────┐ │         │ ┌────────────────────────┐  │
│ │ HDD Datastore     │─────────▶│ │ storage-class-hdd     │  │
│ │ (Standard)        │ Mapping │ │ (Standard)             │  │
│ └──────────────────┘ │         │ └────────────────────────┘  │
│                      │         │                              │
│ ┌──────────────────┐ │         │ ┌────────────────────────┐  │
│ │ NFS Datastore     │─────────▶│ │ storage-class-nfs     │  │
│ │ (File Storage)    │ Mapping │ │ (File Storage)         │  │
│ └──────────────────┘ │         │ └────────────────────────┘  │
└──────────────────────┘         └──────────────────────────────┘
          │                               │
          │                               │
          └───────────────┬───────────────┘
                          │
                  ┌───────▼────────┐
                  │   Storage CSI  │
                  │   Drivers      │
                  │                │
                  │  - vSphere CSI │
                  │  - NFS CSI     │
                  │  - Local CSI   │
                  └────────────────┘
```

---

## Storage Class Configuration

### Storage Class Definitions

**SSD Storage Class (High Performance):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: csi.vsphere.vmware.com
parameters:
  storagePolicyName: "gold-storage-policy"
  datastoreURL: "ds:///vmfs/volumes/ssd-datastore"
  diskformat: thin
  fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

**HDD Storage Class (Standard):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-hdd
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: csi.vsphere.vmware.com
parameters:
  storagePolicyName: "silver-storage-policy"
  datastoreURL: "ds:///vmfs/volumes/hdd-datastore"
  diskformat: thin
  fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

**NFS Storage Class (File Storage):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-nfs
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /export/vm-storage
  mountOptions: "hard,nfsvers=4.1"
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

**Local Storage Class (Temporary):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-local
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

### Storage Class Performance Characteristics

**Storage Class Performance Matrix:**

| Storage Class | Type | IOPS | Throughput | Latency | Use Case |
|---------------|------|------|------------|---------|----------|
| storage-class-ssd | SSD | 10,000+ | 500 MB/s | < 2ms | Databases, critical apps |
| storage-class-hdd | HDD | 2,000-5,000 | 150 MB/s | 5-10ms | App servers, web servers |
| storage-class-nfs | NFS | 1,000-3,000 | 100 MB/s | 10-20ms | Shared data, backups |
| storage-class-local | Local SSD | 15,000+ | 1 GB/s | < 1ms | Temporary migration storage |

---

## Storage Capacity Planning

### Capacity Calculation Formula

**Total Storage Requirement Calculation (200 VMs):**
```
Total Storage = (VM Storage × 1.5) + (Migration Overhead × Number of Concurrent Migrations)

Where:
- VM Storage: Sum of all VM disk sizes
- 1.5: 50% buffer for migrations and snapshots
- Migration Overhead: 100 GB per concurrent migration
- Number of Concurrent Migrations: 5 (maximum concurrent)
```

**Example Calculation for 200 VMs:**
```
VM Storage: 35 TB (35,000 GB)
Buffer: 50% of 35 TB = 17.5 TB
Migration Overhead: 100 GB × 5 concurrent migrations = 500 GB

Total Storage = 35 TB + 17.5 TB + 0.5 TB = 53 TB
```

**Per Cluster Storage Allocation:**
- Cluster 1 (Development/Staging): 3.75 TB
- Cluster 2 (Production Tier 3 & 2): 11.25 TB
- Cluster 3 (Production Tier 1): 37.5 TB

### Storage Allocation by VM Type

**VM Storage Allocation (200 VMs total):**

| VM Type | Average Size | Number of VMs | Total Storage | Buffer | Allocated Storage |
|---------|--------------|---------------|---------------|--------|-------------------|
| Non-Production | 50 GB | 50 | 2.5 TB | 1.25 TB | 3.75 TB |
| Tier 3 Production (Web) | 50 GB | 50 | 2.5 TB | 1.25 TB | 3.75 TB |
| Tier 2 Production (App) | 100 GB | 50 | 5 TB | 2.5 TB | 7.5 TB |
| Tier 1 Production (Database) | 500 GB | 50 | 25 TB | 12.5 TB | 37.5 TB |
| Total | - | 200 | 35 TB | 17.5 TB | 52.5 TB |

### Storage Quota Configuration

**Namespace Storage Quota:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: production
spec:
  hard:
    requests.storage: "10Ti"
    persistentvolumeclaims: "100"
    vms.kubevirt.io: "50"
    persistentvolumeclaims: "50"
```

**Project Storage Limit:**
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limits
  namespace: production
spec:
  limits:
  - type: PersistentVolumeClaim
    max:
      storage: 2Ti
    min:
      storage: 10Gi
    default:
      storage: 100Gi
    defaultRequest:
      storage: 100Gi
```

---

## Storage Performance Planning

### Performance Requirements by VM Type

**Performance Specifications:**

| VM Type | IOPS Requirement | Throughput Requirement | Latency Requirement | Recommended Storage Class |
|---------|------------------|------------------------|---------------------|--------------------------|
| Database Servers | 5,000-10,000 | 200-500 MB/s | < 5ms | storage-class-ssd |
| Application Servers | 1,000-3,000 | 50-150 MB/s | < 10ms | storage-class-hdd |
| Web Servers | 500-1,000 | 20-50 MB/s | < 15ms | storage-class-hdd |
| Development VMs | 500-1,000 | 20-50 MB/s | < 20ms | storage-class-nfs |

### Storage Performance Monitoring

**Storage Metrics to Monitor:**
- IOPS per storage class
- Throughput per storage class
- Latency per storage class
- Storage utilization percentage
- Storage queue depth
- Storage errors

**Prometheus Storage Monitoring:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: storage-alerts
  namespace: openshift-monitoring
spec:
  groups:
  - name: storage.rules
    rules:
    - alert: HighStorageLatency
      expr: kubelet_volume_stats_used_bytes > 0.8
      for: 5m
      annotations:
        summary: "High storage latency detected"
      labels:
        severity: warning
    - alert: StorageCapacityLow
      expr: kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes < 0.1
      for: 5m
      annotations:
        summary: "Storage capacity below 10%"
      labels:
        severity: critical
```

---

## Storage Mapping Strategy

### VMware to OpenShift Storage Mapping

**Storage Mapping Configuration:**

```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: StorageMap
metadata:
  name: vmware-to-openshift-storage
  namespace: openshift-mtv
spec:
  map:
    - destination:
        name: storage-class-ssd
        namespace: openshift-mtv
      source:
        id: "datastore-ssd"
        name: "SSD Datastore"
    - destination:
        name: storage-class-hdd
        namespace: openshift-mtv
      source:
        id: "datastore-hdd"
        name: "HDD Datastore"
    - destination:
        name: storage-class-nfs
        namespace: openshift-mtv
      source:
        id: "datastore-nfs"
        name: "NFS Datastore"
```

### Storage Selection Criteria

**Storage Class Selection Logic:**

1. **Performance-Based Selection:**
   - Database VMs → storage-class-ssd
   - Application VMs → storage-class-hdd
   - Web Server VMs → storage-class-hdd
   - Development VMs → storage-class-nfs

2. **Capacity-Based Selection:**
   - Large disks (> 500 GB) → storage-class-hdd
   - Small disks (< 50 GB) → storage-class-ssd
   - Shared storage → storage-class-nfs

3. **Cost-Based Selection:**
   - Critical production → storage-class-ssd
   - Standard production → storage-class-hdd
   - Non-production → storage-class-nfs

---

## Secrets and Password Management

### Credential Inventory

**Credential Types to Manage:**

| Credential Type | Example | Storage Method | Rotation Policy |
|-----------------|---------|----------------|-----------------|
| VMware vCenter | vcenter-user | OpenShift Secret | Quarterly |
| Database | db-admin-user | OpenShift Secret | Monthly |
| Application | app-service-user | External Vault | Monthly |
| API Keys | api-service-key | External Vault | As needed |
| Certificates | ssl-cert | OpenShift Secret | Yearly |

### OpenShift Secrets Configuration

**VMware Credentials Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vmware-credentials
  namespace: openshift-mtv
type: Opaque
stringData:
  username: "migration-user@vsphere.local"
  password: "secure-password-here"
  api-endpoint: "https://vcenter.example.com/sdk"
```

**Database Credentials Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: production
type: Opaque
stringData:
  username: "database-admin"
  password: "database-password"
  connection-string: "postgresql://db-server:5432/database"
```

### External Secret Management

**HashiCorp Vault Integration:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: production
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "auth/kubernetes"
          role: "migration-role"
```

**External Secret:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-external-secret
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: secret/data/database
      property: username
  - secretKey: password
    remoteRef:
      key: secret/data/database
      property: password
```

### Secret Rotation Procedures

**Manual Secret Rotation:**
```bash
#!/bin/bash
# Secret rotation script
SECRET_NAME=$1
NEW_PASSWORD=$2

# Generate new password if not provided
if [ -z "$NEW_PASSWORD" ]; then
  NEW_PASSWORD=$(openssl rand -base64 32)
fi

# Update secret
kubectl create secret generic $SECRET_NAME \
  --from-literal=password=$NEW_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart affected pods
kubectl rollout restart deployment -l secret=$SECRET_NAME
```

**Automated Secret Rotation:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secret-rotation
  namespace: production
spec:
  schedule: "0 0 1 * *"  # Monthly
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: rotate-secrets
            image: quay.io/external-secrets/external-secrets:latest
            command:
            - /bin/sh
            - -c
            - |
              # Rotate secrets
              kubectl create secret generic database-credentials \
                --from-literal=password=$(openssl rand -base64 32) \
                --dry-run=client -o yaml | kubectl apply -f -
              # Restart affected applications
              kubectl rollout restart deployment -l app=database
          restartPolicy: OnFailure
```

---

## Non-OS Disks and LUNs

### Special Case: Non-OS Disks

**Non-OS Disk Types:**
- NAS (Network Attached Storage)
- SAN (Storage Area Network)
- NFS (Network File System)
- iSCSI LUNs
- Fibre Channel LUNs

**Non-OS Disk Identification:**
```bash
# Identify non-OS disks in VMware
vmware-cmd -l getdisks vm-name

# Check disk type
vsish -e get /vmks/vmls/info

# Identify mounted filesystems
lsblk -f
df -h
```

### NAS/SAN/NFS Disk Handling

**NAS Disk Migration Procedure:**

1. **Pre-Migration Assessment:**
   ```bash
   # Document NAS configuration
   echo "NAS Configuration:" > nas-config.txt
   echo "Mount Point: /data/nas" >> nas-config.txt
   echo "NAS Server: nas-server.example.com" >> nas-config.txt
   echo "Share: /export/share" >> nas-config.txt
   echo "Protocol: NFS" >> nas-config.txt
   ```

2. **Configure OpenShift for NAS Access:**
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: nas-pv
   spec:
     capacity:
       storage: 1Ti
     accessModes:
     - ReadWriteMany
     nfs:
       server: nas-server.example.com
       path: /export/share
   ```

3. **Configure VM to Mount NAS:**
   ```yaml
   apiVersion: kubevirt.io/v1
   kind: VirtualMachine
   metadata:
     name: vm-with-nas
   spec:
     template:
       spec:
         volumes:
         - name: nas-volume
           persistentVolumeClaim:
             claimName: nas-pvc
         - name: rootdisk
           dataVolume:
             name: rootdisk
   ```

**SAN Disk Migration Procedure:**

1. **Document SAN Configuration:**
   ```bash
   # Document LUN details
   multipath -ll
   fdisk -l
   cat /etc/multipath.conf
   ```

2. **Configure OpenShift for SAN Access:**
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: san-pv
   spec:
     capacity:
       storage: 1Ti
     accessModes:
     - ReadWriteOnce
     fc:
       targetWWNs: ["target_wwn"]
       lun: 0
     volumeMode: Block
   ```

3. **Configure VM for SAN Access:**
   ```yaml
   apiVersion: kubevirt.io/v1
   kind: VirtualMachine
   metadata:
     name: vm-with-san
   spec:
     template:
       spec:
         domain:
           devices:
             disks:
             - name: san-disk
               disk:
                 bus: virtio
         volumes:
         - name: san-disk
           persistentVolumeClaim:
             claimName: san-pvc
   ```

### LUN Reattachment Procedure

**LUN Reattachment Steps:**

1. **Detach LUN from Source VM:**
   ```bash
   # Power off source VM
   vmware-cmd -l stop vm-name
   
   # Remove LUN from VM configuration
   vmware-cmd -l removedisk vm-name disk-id
   ```

2. **Attach LUN to Target VM:**
   ```yaml
   apiVersion: kubevirt.io/v1
   kind: VirtualMachine
   metadata:
     name: vm-with-lun
   spec:
     template:
       spec:
         domain:
           devices:
             disks:
             - name: lun-disk
               lun:
                 reservation: true
                 bus: virtio
         volumes:
         - name: lun-disk
           persistentVolumeClaim:
             claimName: lun-pvc
   ```

3. **Validate LUN Access:**
   ```bash
   # Check LUN visibility
   oc exec -it vm-name -- lsblk
   
   # Verify filesystem
   oc exec -it vm-name -- mount | grep /mnt/lun
   ```

---

## Storage for Special Cases

### Database Storage Configuration

**Database VM Storage:**
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: database-vm
  namespace: production
spec:
  template:
    spec:
      domain:
        devices:
          disks:
          - name: database-disk
            disk:
              bus: virtio
          - name: database-log
            disk:
              bus: virtio
      volumes:
      - name: database-disk
        dataVolume:
          name: database-dv
      - name: database-log
        dataVolume:
          name: database-log-dv
  dataVolumes:
  - metadata:
      name: database-dv
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 500Gi
        storageClassName: storage-class-ssd
      source:
        blank: {}
  - metadata:
      name: database-log-dv
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
        storageClassName: storage-class-ssd
      source:
        blank: {}
```

### High-Performance Storage Configuration

**Multi-Disk VM Configuration:**
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: high-perf-vm
  namespace: production
spec:
  template:
    spec:
      domain:
        devices:
          disks:
          - name: disk-1
            disk:
              bus: virtio
          - name: disk-2
            disk:
              bus: virtio
          - name: disk-3
            disk:
              bus: virtio
      volumes:
      - name: disk-1
        dataVolume:
          name: dv-1
      - name: disk-2
        dataVolume:
          name: dv-2
      - name: disk-3
        dataVolume:
          name: dv-3
  dataVolumes:
  - metadata:
      name: dv-1
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
        storageClassName: storage-class-ssd
      source:
        blank: {}
  - metadata:
      name: dv-2
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
        storageClassName: storage-class-ssd
      source:
        blank: {}
  - metadata:
      name: dv-3
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
        storageClassName: storage-class-ssd
      source:
        blank: {}
```

---

## Storage Migration Procedures

### Pre-Migration Storage Validation

**Storage Validation Checklist:**
```bash
#!/bin/bash
# Storage validation script
VM_NAME=$1

echo "Validating storage for $VM_NAME"

# Check disk consolidation
echo "Checking disk consolidation status"
vmware-cmd -l checkconsolidation $VM_NAME

# Check for snapshots
echo "Checking for snapshots"
SNAPSHOT_COUNT=$(vmware-cmd -l getsnapshotcount $VM_NAME)
echo "Snapshot count: $SNAPSHOT_COUNT"

# Check storage capacity
echo "Checking storage capacity"
oc get pv
oc get sc

# Validate storage class availability
echo "Validating storage classes"
oc get sc storage-class-ssd
oc get sc storage-class-hdd
oc get sc storage-class-nfs
```

### Storage Migration Execution

**Step-by-Step Storage Migration:**

1. **Pre-Migration:**
   ```bash
   # Document current storage configuration
   oc get vm vm-name -n namespace -o yaml > vm-storage-config.yaml
   
   # Validate storage class mapping
   oc get storagemap -n openshift-mtv
   
   # Check storage capacity
   oc describe sc storage-class-ssd
   ```

2. **Execute Migration:**
   ```bash
   # Start migration with storage mapping
   oc apply -f migration-plan-with-storage.yaml
   
   # Monitor storage provisioning
   oc get pvc -n target-namespace -w
   
   # Check storage usage
   oc exec -it vm-name -- df -h
   ```

3. **Post-Migration Validation:**
   ```bash
   # Validate disk sizes
   oc exec -it vm-name -- lsblk
   
   # Check filesystem integrity
   oc exec -it vm-name -- fsck /dev/vda1
   
   # Verify storage performance
   oc exec -it vm-name -- dd if=/dev/zero of=/tmp/test bs=1G count=1 oflag=direct
   ```

---

## Storage Validation and Testing

### Storage Performance Testing

**Storage Performance Test:**
```bash
#!/bin/bash
# Storage performance test for migrated VM
VM_NAME=$1

echo "Testing storage performance for $VM_NAME"

# Test write performance
echo "Testing write performance"
oc exec -it $VM_NAME -- dd if=/dev/zero of=/tmp/test-write bs=1M count=1024 oflag=direct

# Test read performance
echo "Testing read performance"
oc exec -it $VM_NAME -- dd if=/tmp/test-write of=/dev/null bs=1M

# Test random I/O
echo "Testing random I/O"
oc exec -it $VM_NAME -- fio --name=random-rw --ioengine=libaio --rw=randrw --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 --time_based

# Cleanup
oc exec -it $VM_NAME -- rm /tmp/test-write
```

### Storage Validation Checklist

**Pre-Migration Validation:**
- [ ] Storage classes configured and tested
- [ ] Storage capacity verified (with buffer)
- [ ] Storage mapping configured
- [ ] Secrets and credentials secured
- [ ] Non-OS disks documented
- [ ] Performance baselines established

**Post-Migration Validation:**
- [ ] Storage provisioned correctly
- [ ] Disk sizes match source
- [ ] Filesystem integrity verified
- [ ] Performance meets or exceeds baseline
- [ ] Non-OS disks reattached
- [ ] Backup and recovery tested

---

## Storage Troubleshooting

### Common Storage Issues

**Issue 1: Storage Class Not Available**
```bash
# Check storage class status
oc get sc

# Describe storage class
oc describe sc storage-class-ssd

# Check CSI driver status
oc get pods -n openshift-cluster-csi-drivers

# Solution: Verify CSI driver installation and storage class configuration
```

**Issue 2: Insufficient Storage Capacity**
```bash
# Check storage capacity
oc get pv
oc describe sc storage-class-ssd

# Check node storage
oc describe nodes

# Solution: Add additional storage or clean up unused volumes
```

**Issue 3: PVC Pending State**
```bash
# Check PVC status
oc get pvc -A
oc describe pvc pvc-name

# Check storage class binding mode
oc describe sc storage-class-ssd

# Solution: Adjust storage class binding mode or add node labels
```

**Issue 4: Non-OS Disk Not Accessible**
```bash
# Check PV status
oc get pv

# Check PVC status
oc get pvc

# Check VM disk attachment
oc get vm vm-name -o yaml | grep -A 10 volumes

# Solution: Verify PV/PVC configuration and check network connectivity for NAS/SAN
```

### Storage Debugging Commands

**Storage Debugging:**
```bash
# Check storage classes
oc get sc
oc describe sc storage-class-ssd

# Check PV/PVC status
oc get pv
oc get pvc -A
oc describe pvc pvc-name

# Check storage usage
oc exec -it vm-name -- df -h
oc exec -it vm-name -- lsblk

# Check CSI drivers
oc get pods -n openshift-cluster-csi-drivers
oc logs csi-driver-pod -n openshift-cluster-csi-drivers

# Check storage mapping
oc get storagemap -n openshift-mtv
oc describe storagemap vmware-to-openshift-storage -n openshift-mtv
```

---

## Next Steps

Upon completion of storage configuration:
- **Configure Governance and Security:** 06-governance-security.md
- **Implement Manual Migration Procedures:** 07-manual-migration.md

---

**Document Status:** Complete  
**Next Review Date:** [TBD]  
**Approved By:** [Approver Name]  
**Approval Date:** [Date]