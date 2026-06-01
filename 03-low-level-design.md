# Low-Level Design (LLD)

**Document:** 03-low-level-design.md  
**Phase:** Detailed Technical Specifications  
**Status:** Implementation Guide

---

## Table of Contents
1. [Technical Specifications](#technical-specifications)
2. [Detailed Component Configuration](#detailed-component-configuration)
3. [Network Configuration Details](#network-configuration-details)
4. [Storage Configuration Details](#storage-configuration-details)
5. [MTV Configuration Details](#mtv-configuration-details)
6. [Migration Procedure Details](#migration-procedure-details)
7. [Integration Specifications](#integration-specifications)
8. [Performance Specifications](#performance-specifications)
9. [Security Configuration Details](#security-configuration-details)
10. [Monitoring and Logging Configuration](#monitoring-and-logging-configuration)
11. [Backup and Recovery Procedures](#backup-and-recovery-procedures)
12. [Testing and Validation Procedures](#testing-and-validation-procedures)

---

## Technical Specifications

### Hardware Specifications

**OpenShift Control Plane Nodes:**
- CPU: 4 vCPUs minimum, 8 vCPUs recommended
- Memory: 16 GB minimum, 32 GB recommended
- Storage: 120 GB SSD (etcd + system)
- Network: 10 Gbps recommended

**OpenShift Worker Nodes:**
- CPU: 16 vCPUs minimum (scaled based on VM requirements)
- Memory: 64 GB minimum (scaled based on VM requirements)
- Storage: 500 GB SSD minimum (scaled based on VM storage)
- Network: 10 Gbps minimum, 25 Gbps recommended

**MTV Conversion Host:**
- CPU: 8 vCPUs minimum
- Memory: 32 GB minimum
- Storage: 200 GB SSD temporary storage
- Network: 10 Gbps minimum

### Software Specifications

**OpenShift Version:**
- OpenShift Container Platform 4.13+ (latest stable release)
- OpenShift Virtualization 4.13+
- Kubernetes 1.26+
- OVN-Kubernetes or Multus CNI
- Container Runtime: CRI-O 1.26+

**MTV Version:**
- Migration Toolkit for Virtualization 2.4+
- Provider compatibility: vCenter 6.7+, ESXi 6.7+
- Conversion host: RHEL 8.7+ or RHEL 9.1+

**Supporting Software:**
- Ansible Core 2.13+
- Python 3.9+
- Git 2.39+
- OpenSSL 3.0+

---

## Detailed Component Configuration

### OpenShift Control Plane Configuration

**API Server Configuration:**
```yaml
apiVersion: config.openshift.io/v1
kind: APIServer
metadata:
  name: cluster
spec:
  audit:
    profile: Default
  encryption:
    type: aescbc
  httpsServingCipherSuites:
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
```

**Scheduler Configuration:**
```yaml
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  name: cluster
spec:
  mastersSchedulable: false
  policy:
    name: scheduler-policy
```

**Node Configuration:**
```yaml
apiVersion: config.openshift.io/v1
kind: Node
metadata:
  name: cluster
spec:
  mastersSchedulable: false
```

### OpenShift Virtualization Configuration

**KubeVirt CR:**
```yaml
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: openshift-cnv
spec:
  certificateRotationStrategy:
    renewBefore: 240h
  configuration:
    developerConfiguration:
      featureGates:
      - liveMigration
      - hotplugVolumes
    emulatedMachines:
    - q35-rhel8.6.0
    migrate:
      completionTimeoutPerGiSec: 800
      bandwidthPerMigration: 64Mi
      postCopy: true
      progressTimeout: 1500
    network:
      defaultNetwork:
        type: ""
```

**CDI (Containerized Data Importer) Configuration:**
```yaml
apiVersion: cdi.kubevirt.io/v1beta1
kind: CDI
metadata:
  name: cdi
  namespace: openshift-cnv
spec:
  config:
    filesystemOverhead: 0.055
    scratchSpaceStorageClass: storage-class-ssd
  infra:
    nodeSelector:
      node-role.kubernetes.io/worker: ""
```

---

## Network Configuration Details

### VLAN Network Configuration

**Network Attachment Definition - VLAN 10 (Production):**
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan-10-production
  namespace: openshift-mtv
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "ovs",
    "bridge": "br-ex",
    "vlan": 10,
    "ipam": {
      "type": "static",
      "routes": [
        {
          "dst": "0.0.0.0/0",
          "gw": "10.0.10.1"
        }
      ],
      "dns": {
        "nameservers": ["8.8.8.8", "8.8.4.4"]
      }
    }
  }'
```

**Network Attachment Definition - VLAN 20 (Development):**
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan-20-development
  namespace: openshift-mtv
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "ovs",
    "bridge": "br-ex",
    "vlan": 20,
    "ipam": {
      "type": "static",
      "routes": [
        {
          "dst": "0.0.0.0/0",
          "gw": "10.0.20.1"
        }
      ],
      "dns": {
        "nameservers": ["8.8.8.8", "8.8.4.4"]
      }
    }
  }'
```

**Network Attachment Definition - VLAN 30 (Management):**
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan-30-management
  namespace: openshift-mtv
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "ovs",
    "bridge": "br-ex",
    "vlan": 30,
    "ipam": {
      "type": "static",
      "routes": [
        {
          "dst": "0.0.0.0/0",
          "gw": "10.0.30.1"
        }
      ],
      "dns": {
        "nameservers": ["8.8.8.8", "8.8.4.4"]
      }
    }
  }'
```

### Bridge Configuration

**Node Network Configuration Policy:**
```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bridge-configuration
spec:
  nodeSelector:
    kubernetes.io/hostname: worker-1.example.com
  desiredState:
    interfaces:
    - name: br-ex
      type: linux-bridge
      state: up
      bridge:
        options:
          stp:
            enabled: false
        port:
        - name: ens192
      ipv4:
        enabled: false
    - name: ens192
      type: ethernet
      state: up
      ipv4:
        enabled: false
```

### Network Policies

**Network Policy for Migration Namespace:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: migration-network-policy
  namespace: openshift-mtv
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: openshift-mtv
    ports:
    - protocol: TCP
      port: 443
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 6443
```

---

## Storage Configuration Details

### Storage Class Configuration

**SSD Storage Class:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-ssd
provisioner: csi.driver.vmware.com
parameters:
  storagepolicyname: "gold-storage-policy"
  kind: Volume
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

**HDD Storage Class:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-hdd
provisioner: csi.driver.vmware.com
parameters:
  storagepolicyname: "silver-storage-policy"
  kind: Volume
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

**NFS Storage Class:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-nfs
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /export/vm-storage
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

### Storage Quotas

**Resource Quota for Migration Namespace:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: vm-migration-quota
  namespace: openshift-mtv
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    requests.storage: 5Ti
    persistentvolumeclaims: "50"
    vms.kubevirt.io: "100"
```

---

## MTV Configuration Details

### MTV Operator Installation

**Catalog Source Configuration:**
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operators
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.redhat.io/redhat/redhat-operator-index:v4.13
  displayName: Red Hat Operators
  publisher: Red Hat
  updateStrategy:
    registryPoll:
      interval: 30m
```

**Operator Group:**
```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-mtv-operator-group
  namespace: openshift-mtv
spec:
  targetNamespaces:
  - openshift-mtv
```

**Subscription:**
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: mtv-operator
  namespace: openshift-mtv
spec:
  channel: release-v2.4
  installPlanApproval: Automatic
  name: mtv-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: mtv-operator.v2.4.0
```

### MTV Instance Configuration

**MTV CR:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: MTV
metadata:
  name: mtv
  namespace: openshift-mtv
spec:
  feature_gates:
    feature_flags: "warm_migration"
  ovirt_provider:
    api_endpoint: "https://ovirt.example.com/ovirt-engine/api"
    ovirt_cert: "ovirt-cert-secret"
    ca_cert: "ovirt-ca-cert-secret"
  vmware_provider:
    api_endpoint: "https://vcenter.example.com/sdk"
    username: "migration-user"
    password: "vmware-password-secret"
    ca_cert: "vmware-ca-cert-secret"
```

### Provider Configuration

**VMware Provider:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: vmware-provider
  namespace: openshift-mtv
spec:
  type: vmware
  url: "https://vcenter.example.com/sdk"
  username: "migration-user@vsphere.local"
  password:
    secretName: vmware-credentials
    secretKey: password
  cacert:
    secretName: vmware-ca-cert
    secretKey: cacert
```

**OpenShift Provider:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: openshift-provider
  namespace: openshift-mtv
spec:
  type: openshift
  url: "https://api.openshift.example.com:6443"
  username: "kubeadmin"
  password:
    secretName: openshift-credentials
    secretKey: password
  cacert:
    secretName: openshift-ca-cert
    secretKey: cacert
```

### Network Mapping Configuration

**Network Mapping:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: NetworkMap
metadata:
  name: vmware-to-openshift-networks
  namespace: openshift-mtv
spec:
  map:
    - destination:
        name: vlan-10-production
        namespace: openshift-mtv
        type: multus
      source:
        id: "network-123"
        name: "VM Network"
    - destination:
        name: vlan-20-development
        namespace: openshift-mtv
        type: multus
      source:
        id: "network-456"
        name: "Development Network"
```

---

## Migration Procedure Details

### Migration Plan Configuration

**Migration Plan:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: MigrationPlan
metadata:
  name: wave-1-migration-plan
  namespace: openshift-mtv
spec:
  provider_sources:
    - name: vmware-provider
      namespace: openshift-mtv
  provider_destinations:
    - name: openshift-provider
      namespace: openshift-mtv
  migrations:
    - vm:
        id: "vm-123"
        name: "web-server-01"
        category: "web-server"
      target_namespace: "production"
      target_vm_name: "web-server-01-migrated"
      network_mappings:
        - source: "VM Network"
          destination: "vlan-10-production"
      storage_mappings:
        - source: "datastore-ssd"
          destination: "storage-class-ssd"
  warm_migration: true
  cutover:
    seconds: 300
```

### Migration Execution Procedure

**Step-by-Step Cold Migration:**
1. **Pre-Migration Checks:**
   ```bash
   # Verify source VM status
   oc get vm vm-name -n namespace
   
   # Check storage availability
   oc get sc
   
   # Verify network configuration
   oc get network-attachment-definition -n openshift-mtv
   ```

2. **Shutdown Source VM:**
   ```bash
   # Power off VM in vCenter
   # Or via API
   curl -X POST "https://vcenter.example.com/api/vcenter/vm/${vm_id}/power/stop"
   ```

3. **Execute Migration:**
   ```bash
   # Start migration via MTV controller
   oc apply -f migration-plan.yaml
   
   # Monitor migration progress
   oc get migration -n openshift-mtv -w
   ```

4. **Validate Migration:**
   ```bash
   # Check migrated VM status
   oc get vm vm-name-migrated -n target-namespace
   
   # Verify VM is running
   oc get vmi vm-name-migrated -n target-namespace
   ```

5. **Post-Migration Cleanup:**
   ```bash
   # Remove source VM (after validation)
   # Update DNS records
   # Update monitoring configuration
   ```

**Step-by-Step Warm Migration:**
1. **Pre-Migration Checks:**
   ```bash
   # Verify source VM is running
   # Check network connectivity
   # Validate storage capacity
   ```

2. **Start Warm Migration:**
   ```bash
   # Create warm migration plan
   oc apply -f warm-migration-plan.yaml
   
   # Monitor progress
   oc get migration -n openshift-mtv -w
   ```

3. **Monitor Synchronization:**
   ```bash
   # Check sync status
   oc describe migration migration-name -n openshift-mtv
   ```

4. **Execute Cutover:**
   ```bash
   # Schedule cutover window
   # Notify stakeholders
   # Execute final cutover
   ```

5. **Validate and Cleanup:**
   ```bash
   # Validate migrated VM
   # Update network configuration
   # Cleanup source VM
   ```

---

## Integration Specifications

### DNS Integration

**DNS Update Procedure:**
```bash
# Update DNS record for migrated VM
nsupdate -k /etc/rndc.key <<EOF
server dns-server.example.com
zone example.com
update delete web-server-01.example.com. A
update add web-server-01.example.com. 300 A 10.0.10.50
send
EOF
```

### Load Balancer Integration

**HAProxy Configuration Update:**
```haproxy
# Add migrated VM to backend pool
backend web-servers
    balance roundrobin
    server web-server-01 10.0.10.50:80 check
    server web-server-02 10.0.10.51:80 check
```

### Monitoring Integration

**Prometheus Service Monitor:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vm-monitor
  namespace: production
spec:
  selector:
    matchLabels:
      app: web-server
  endpoints:
  - port: metrics
    interval: 30s
```

---

## Performance Specifications

### Resource Allocation

**VM Resource Mapping:**
```yaml
# Source VM specifications
CPU: 4 vCPUs
Memory: 8 GB
Storage: 100 GB

# Target VM specifications (with 20% buffer)
CPU: 5 vCPUs
Memory: 10 GB
Storage: 150 GB (50% buffer)
```

**Performance Baselines:**
- CPU Utilization: < 70%
- Memory Utilization: < 80%
- Storage IOPS: Match or exceed source
- Network Bandwidth: 1 Gbps minimum, 10 Gbps recommended

### Migration Performance

**Data Transfer Rates:**
- Cold Migration: 500 Mbps - 1 Gbps
- Warm Migration (initial): 500 Mbps - 1 Gbps
- Warm Migration (sync): < 100 Mbps

**Migration Duration Estimates:**
- 50 GB VM: 30-60 minutes (cold)
- 100 GB VM: 1-2 hours (cold)
- 500 GB VM: 4-8 hours (cold)

---

## Security Configuration Details

### Secret Management

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
  password: "secure-password"
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
  username: "db-user"
  password: "db-password"
  connection-string: "jdbc:postgresql://db-server:5432/dbname"
```

### Network Security

**Network Policy for Database VMs:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      role: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: application
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

---

## Monitoring and Logging Configuration

### Prometheus Monitoring

**Prometheus Rule for Migration:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: migration-alerts
  namespace: openshift-mtv
spec:
  groups:
  - name: migration.rules
    rules:
    - alert: MigrationFailed
      expr: mtv_migration_status{status="failed"} == 1
      for: 5m
      annotations:
        summary: "Migration failed for {{ $labels.vm_name }}"
      labels:
        severity: critical
```

### Logging Configuration

**Fluentd Configuration for VM Logs:**
```xml
<source>
  @type tail
  path /var/log/vm/*.log
  pos_file /var/log/fluentd-vm.pos
  tag vm.*
  format json
</source>

<match vm.**>
  @type elasticsearch
  host elasticsearch.logging.svc
  port 9200
  index_name vm-logs
  type_name vm-log
</match>
```

---

## Backup and Recovery Procedures

### etcd Backup

**Automated etcd Backup Script:**
```bash
#!/bin/bash
# etcd backup script
ETCDCTL_PATH="/usr/bin/etcdctl"
BACKUP_DIR="/backup/etcd"
DATE=$(date +%Y%m%d-%H%M%S)

$ETCDCTL_PATH snapshot save $BACKUP_DIR/etcd-backup-$DATE.db \
  --cacert=/etc/kubernetes/static-pod-resources/configmaps/etcd-ca-bundle/ca-bundle.crt \
  --cert=/etc/kubernetes/static-pod-resources/secrets/etcd-client/tls.crt \
  --key=/etc/kubernetes/static-pod-resources/secrets/etcd-client/tls.key
```

### VM Configuration Backup

**VM Configuration Backup:**
```bash
#!/bin/bash
# Backup VM configuration
NAMESPACE=$1
VM_NAME=$2
BACKUP_DIR="/backup/vm-configs"
DATE=$(date +%Y%m%d-%H%M%S)

oc get vm $VM_NAME -n $NAMESPACE -o yaml > $BACKUP_DIR/$VM_NAME-$DATE.yaml
oc get vmi $VM_NAME -n $NAMESPACE -o yaml > $BACKUP_DIR/$VM_NAME-vmi-$DATE.yaml
```

---

## Testing and Validation Procedures

### Pre-Migration Validation

**VM Compatibility Check:**
```bash
#!/bin/bash
# VM compatibility check script
VM_NAME=$1

echo "Checking VM compatibility for $VM_NAME"

# Check VMware Tools version
echo "VMware Tools version: $(vmtoolsd --version)"

# Check disk consolidation
echo "Disk consolidation status: $(vmware-cmd -l checkconsolidation)"

# Check for snapshots
echo "Snapshot count: $(vmware-cmd -l getsnapshotcount)"
```

### Post-Migration Validation

**VM Functionality Test:**
```bash
#!/bin/bash
# Post-migration validation script
VM_NAME=$1
NAMESPACE=$2

echo "Validating migrated VM: $VM_NAME in namespace: $NAMESPACE"

# Check VM status
STATUS=$(oc get vm $VM_NAME -n $NAMESPACE -o jsonpath='{.status.printableStatus}')
echo "VM Status: $STATUS"

# Check VMI is running
RUNNING=$(oc get vmi $VM_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
echo "VMI Phase: $RUNNING"

# Check network connectivity
IP=$(oc get vmi $VM_NAME -n $NAMESPACE -o jsonpath='{.status.interfaces[0].ipAddress}')
echo "VM IP Address: $IP"

# Test network connectivity
ping -c 3 $IP
```

---

## Next Steps

Upon completion of LLD review:
- **Implement Network Configuration:** 04-networking-considerations.md
- **Implement Storage Configuration:** 05-storage-planning.md
- **Configure Governance and Security:** 06-governance-security.md

---

**Document Status:** Complete  
**Next Review Date:** [TBD]  
**Approved By:** [Approver Name]  
**Approval Date:** [Date]