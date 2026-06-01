# Manual Migration Procedures

**Document:** 07-manual-migration.md  
**Phase:** Manual Migration Execution  
**Status:** Migration Implementation Guide

---

## Table of Contents
1. [Pre-Migration Checklist](#pre-migration-checklist)
2. [Cold Migration Procedure](#cold-migration-procedure)
3. [Warm Migration Procedure](#warm-migration-procedure)
4. [Post-Migration Validation](#post-migration-validation)
5. [Rollback Procedures](#rollback-procedures)
6. [Special Case Procedures](#special-case-procedures)
7. [Windows VM Migration](#windows-vm-migration)
8. [Linux VM Migration](#linux-vm-migration)

---

## Production-Grade POC Deployment

This document now includes production-grade POC deployment procedures using the configuration files provided in the `config/` directory. All configuration files are ready-to-use and follow RedHat best practices.

### Quick Start Deployment

For immediate POC deployment, follow these steps using the provided configuration files:

1. **Review and Customize Configuration Files**
2. **Apply Infrastructure Configuration** 
3. **Generate Secrets**
4. **Configure Providers**
5. **Run Validation**
6. **Execute Migration**

### Detailed Deployment Steps

#### Step 1: Review and Customize Configuration

**Network Configuration:**
```bash
cd config/network
# Review and customize VLAN IDs, IP ranges, bridge names
nano vlan-10-production.yaml
nano vlan-20-development.yaml
nano vlan-30-management.yaml
```

**Storage Configuration:**
```bash
cd config/storage
# Review and customize storage classes, provisioner settings
nano storage-class-ssd.yaml
nano storage-class-hdd.yaml
nano storage-class-nfs.yaml
```

**Provider Configuration:**
```bash
cd config/providers
# Update provider URLs, credentials references
nano vsphere-provider.yaml
nano openshift-provider.yaml
```

#### Step 2: Apply Infrastructure Configuration

**Apply Network Configuration:**
```bash
oc apply -f config/network/
# Verify
oc get network-attachment-definition -A
```

**Apply Storage Configuration:**
```bash
oc apply -f config/storage/
# Verify
oc get sc
oc get pvc -A
```

#### Step 3: Generate Secrets

**Generate Secrets Using Provided Script:**
```bash
chmod +x config/secrets/generate-secrets.sh
./config/secrets/generate-secrets.sh
# Follow prompts to generate required secrets
```

**Or Apply Customized Secret Files:**
```bash
# Customize secret files
nano config/secrets/vcenter-credentials-secret.yaml
nano config/secrets/openshift-credentials-secret.yaml

# Apply secrets
oc apply -f config/secrets/
# Verify
oc get secrets -n openshift-mtv
```

#### Step 4: Configure Providers

**Apply Provider Configuration:**
```bash
oc apply -f config/providers/
# Verify
oc get provider -n openshift-mtv
oc describe provider vsphere-provider -n openshift-mtv
oc describe provider openshift-provider -n openshift-mtv
```

#### Step 5: Run Validation

**Run Comprehensive Pre-Flight Check:**
```bash
chmod +x config/validation/pre-flight-check.sh
./config/validation/pre-flight-check.sh --vm-name "your-vm-name"
```

**Run Individual Validation Checks:**
```bash
# vCenter connectivity
chmod +x config/validation/vcenter-check.sh
./config/validation/vcenter-check.sh

# OpenShift cluster health
chmod +x config/validation/openshift-check.sh
./config/validation/openshift-check.sh

# Network configuration
chmod +x config/validation/network-check.sh
./config/validation/network-check.sh

# Storage configuration
chmod +x config/validation/storage-check.sh
./config/validation/storage-check.sh
```

#### Step 6: Execute Migration

**Using Migration Plan Templates:**

**Cold Migration:**
```bash
# Customize cold migration template
cd config/migration-plans
nano cold-migration-template.yaml
# Update VM ID, name, network mappings, storage mappings

# Apply migration plan
oc apply -f cold-migration-template.yaml

# Monitor migration
oc get migration -n openshift-mtv -w
oc describe migration <migration-name> -n openshift-mtv
```

**Warm Migration:**
```bash
# Customize warm migration template
cd config/migration-plans
nano warm-migration-template.yaml
# Update VM details, cutover settings, sync interval

# Apply migration plan
oc apply -f warm-migration-template.yaml

# Monitor migration
oc get migration -n openshift-mtv -w
```

**Batch Migration:**
```bash
# Customize batch migration template
cd config/migration-plans
nano batch-migration-production.yaml
# Update VM list, mappings

# Apply migration plan
oc apply -f batch-migration-production.yaml

# Monitor migration
oc get migration -n openshift-mtv -w
```

#### Step 7: Post-Migration Validation

**Run Post-Migration Validation:**
```bash
chmod +x config/validation/post-migration-validation.sh
./config/validation/post-migration-validation.sh \
  --vm-name "migrated-vm-name" \
  --namespace "production"
```

#### Step 8: Rollback (If Needed)

**Execute VM Rollback:**
```bash
chmod +x config/rollback/vm-rollback.sh
./config/rollback/vm-rollback.sh \
  --vm-name "migrated-vm-name" \
  --namespace "production" \
  --restore-source
```

**Clean Up Resources:**
```bash
chmod +x config/rollback/cleanup-resources.sh
./config/rollback/cleanup-resources.sh \
  --namespace "production" \
  --days-old 30
```

---

## Pre-Migration Checklist

### General Pre-Migration Checklist

**Source Environment Validation:**
- [ ] vCenter/ESXi hosts accessible
- [ ] VM Tools updated to latest version
- [ ] Disk consolidation completed
- [ ] Snapshots removed or consolidated
- [ ] VM documentation updated
- [ ] Backup completed and verified

**Target Environment Validation:**
- [ ] OpenShift cluster operational
- [ ] MTV operator installed and configured
- [ ] Network attachment definitions configured
- [ ] Storage classes available and tested
- [ ] Sufficient resources available
- [ ] Credentials configured and tested

**Network Validation:**
- [ ] VLAN connectivity tested
- [ ] Network policies configured
- [ ] DNS resolution functional
- [ ] Load balancer configured
- [ ] Firewall rules configured
- [ ] IP addresses allocated

**Storage Validation:**
- [ ] Storage capacity verified
- [ ] Storage classes tested
- [ ] PV/PVC configuration validated
- [ ] Non-OS disks documented
- [ ] Backup storage configured
- [ ] Storage performance tested

**Security Validation:**
- [ ] RBAC permissions verified
- [ ] Secrets configured
- [ ] Encryption enabled
- [ ] Audit logging enabled
- [ ] Network policies applied
- [ ] Compliance requirements validated

---

## Cold Migration Procedure

### Overview

**Cold Migration:** VM is powered off during migration process

**Use Cases:**
- Non-production VMs
- Development and testing VMs
- VMs with extended downtime windows
- VMs without stateful requirements

**Estimated Downtime:** 30 minutes to several hours (depending on VM size)

### Step-by-Step Cold Migration

**Step 1: Pre-Migration Preparation**

1. **Document Source VM Configuration:**
```bash
# Document VM configuration
VM_NAME="web-server-01"
vcenter_user="migration-user@vsphere.local"
vcenter_server="vcenter.example.com"

# Get VM details
govc vm.info "$VM_NAME" > vm-config-backup.txt

# Get network configuration
govc vm.info -network "$VM_NAME" > vm-network-config.txt

# Get storage configuration
govc vm.info -disk "$VM_NAME" > vm-storage-config.txt
```

2. **Validate VM Status:**
```bash
# Check VM power status
govc vm.power "$VM_NAME"

# Check for snapshots
govc snapshot.tree "$VM_NAME"

# Check disk consolidation
govc vm.disk.wipe "$VM_NAME"
```

3. **Create Pre-Migration Backup:**
```bash
# Create snapshot for rollback
govc snapshot.create "$VM_NAME" pre-migration-backup

# Perform full backup
# (Use your organization's backup procedure)
```

**Step 2: Disk Preparation and VDD Handling**

1. **Check Virtual Disk Configuration:**
```bash
# Get VM disk information
govc vm.disk.info "$VM_NAME"

# Check disk consolidation status
govc vm.disk.query -vm "$VM_NAME" -type disk-ide:0

# List all virtual disks
govc ls "/$DATACENTER/vm/$VM_NAME/*"
```

2. **VDD File Verification:**
```bash
# Check for VDD (Virtual Disk Descriptor) files
govc datastore.ls -p "$DATASTORE" | grep -i "$VM_NAME"

# Verify VDD file integrity
govc datastore.cp "$DATASTORE/$VM_NAME/$VM_NAME.vmdk" "$BACKUP_DIR/"

# Check for disk snapshots
govc snapshot.tree "$VM_NAME"
```

3. **Disk Consolidation (if snapshots exist):**
```bash
# Consolidate snapshots before migration
govc vm.disk.wipe "$VM_NAME"

# Remove stale snapshots if necessary
govc snapshot.remove "$VM_NAME" "snapshot-name"
```

4. **Shutdown Source VM:**
```bash
# Graceful shutdown
govc vm.power -off "$VM_NAME"

# Verify VM is powered off
govc vm.power "$VM_NAME"

# Confirm no disk locks
govc device.ls "$VM_NAME" | grep disk
```

**Step 3: Configure Migration Plan**

1. **Create Migration Plan YAML:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: MigrationPlan
metadata:
  name: web-server-01-cold-migration
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
      target_vm_name: "web-server-01"
      network_mappings:
        - source: "VM Network"
          destination: "vlan-10-production"
      storage_mappings:
        - source: "datastore-ssd"
          destination: "storage-class-ssd"
  warm_migration: false
```

2. **Apply Migration Plan:**
```bash
oc apply -f web-server-01-cold-migration.yaml
```

**Step 4: Execute Migration with Data Copy Procedures**

1. **Red Hat MTV Data Copy Process:**
```bash
# MTV uses virt-v2v for VM conversion
# Data copy stages for cold migration:

# Stage 1: Source VM metadata collection
govc vm.info "$VM_NAME" > vm-metadata.txt
govc vm.disk.info "$VM_NAME" > disk-metadata.txt

# Stage 2: VDD (Virtual Disk Descriptor) file handling
# VDD contains disk geometry, capacity, and metadata
govc datastore.cp "$DATASTORE/$VM_NAME/$VM_NAME.vmdk" "/tmp/vdd-backup/"

# Stage 3: Data stream processing via MTV
# Data is transferred in chunks for error resilience
# Chunk size: 1 MB default, configurable
# Checksum: SHA-256 calculated per chunk
```

2. **Start Migration with Detailed Tracking:**
```bash
# Apply migration plan
oc apply -f web-server-01-cold-migration.yaml

# Monitor migration progress with data copy metrics
oc get migration web-server-01-cold-migration -n openshift-mtv -w

# Check detailed migration status
oc describe migration web-server-01-cold-migration -n openshift-mtv

# Monitor conversion host for data copy details
oc logs -f conversion-host-pod -n openshift-mtv -c converter
```

3. **VDD to OpenShift Storage Mapping:**
```bash
# MTV automatically handles VDD to PVC mapping:
# VDD file → Data Volume → Persistent Volume Claim → VM disk

# Verify PVC creation with correct size
oc get pvc -n production
oc describe pvc web-server-01-disk -n production

# Check Data Volume creation status
oc get datavolume -n production
oc describe datavolume web-server-01 -n production

# Verify disk attachment and storage mapping
oc get vm web-server-01 -n production -o yaml | grep -A 10 volumes
```

4. **Data Copy Progress Monitoring:**
```bash
# Monitor actual data transfer rate
# Check conversion host logs for throughput
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "transfer"

# Verify data integrity checks
oc describe migration web-server-01-cold-migration -n openshift-mtv | grep -i "checksum"

# Check for any data copy errors
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "error"
```

5. **Wait for Migration Completion:**
```bash
# Wait for migration to complete with timeout
oc wait --for=condition=Complete migration/web-server-01-cold-migration -n openshift-mtv --timeout=4h

# Verify final migration status
oc get migration web-server-01-cold-migration -n openshift-mtv
```

**Step 5: Post-Migration Validation**

1. **Verify VM Creation:**
```bash
# Check VM status
oc get vm web-server-01 -n production

# Check VMI status
oc get vmi web-server-01 -n production
```

2. **Start Migrated VM:**
```bash
# Start the VM
oc start vm web-server-01 -n production

# Verify VM is running
oc get vmi web-server-01 -n production
```

3. **Validate Network Connectivity:**
```bash
# Get VM IP address
VM_IP=$(oc get vmi web-server-01 -n production -o jsonpath='{.status.interfaces[0].ipAddress}')

# Test connectivity
ping -c 3 $VM_IP

# Test specific ports
nc -zv $VM_IP 22
nc -zv $VM_IP 80
nc -zv $VM_IP 443
```

4. **Validate Application Functionality:**
```bash
# Test application endpoints
curl http://$VM_IP/health
curl https://$VM_API/health

# Test database connectivity
# (Application-specific tests)
```

**Step 6: Post-Migration Configuration**

1. **Update DNS Records:**
```bash
# Update DNS if IP changed
nsupdate -k /etc/rndc.key <<EOF
server dns-server.example.com
zone example.com
update delete web-server-01.example.com. A
update add web-server-01.example.com. 300 A $VM_IP
send
EOF
```

2. **Update Load Balancer:**
```bash
# Add new backend to load balancer
# (Load balancer-specific procedure)
```

3. **Update Monitoring:**
```bash
# Update monitoring configuration
# Add migrated VM to monitoring system
```

**Step 7: Cleanup**

1. **Remove Source VM:**
```bash
# Delete source VM from vCenter (after validation)
govc vm.destroy "$VM_NAME"
```

2. **Remove Migration Artifacts:**
```bash
# Clean up migration plan
oc delete migrationplan web-server-01-cold-migration -n openshift-mtv
```

---

## Warm Migration Procedure

### Overview

**Warm Migration:** VM remains running during migration with continuous synchronization

**Use Cases:**
- Production VMs requiring minimal downtime
- Stateful applications
- VMs with high availability requirements
- Database servers

**Estimated Downtime:** Minutes (during final cutover)

### Step-by-Step Warm Migration

**Step 1: Pre-Migration Preparation**

1. **Document Source VM Configuration:**
```bash
# Document VM configuration
VM_NAME="database-server-01"
govc vm.info "$VM_NAME" > vm-config-backup.txt
govc vm.info -network "$VM_NAME" > vm-network-config.txt
govc vm.info -disk "$VM_NAME" > vm-storage-config.txt
```

2. **Validate VM is Running:**
```bash
# Check VM power status
govc vm.power "$VM_NAME"

# Verify VM is running
govc vm.info "$VM_NAME" | grep "Power state"
```

3. **Create Pre-Migration Snapshot:**
```bash
# Create snapshot for rollback
govc snapshot.create "$VM_NAME" pre-migration-backup
```

**Step 2: Configure Migration Plan with VDD Configuration**

1. **Create Warm Migration Plan YAML:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: MigrationPlan
metadata:
  name: database-server-01-warm-migration
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
        id: "vm-456"
        name: "database-server-01"
        category: "database"
      target_namespace: "production"
      target_vm_name: "database-server-01"
      network_mappings:
        - source: "VM Network"
          destination: "vlan-10-production"
      storage_mappings:
        - source: "datastore-ssd"
          destination: "storage-class-ssd"
  warm_migration: true
  cutover:
    seconds: 300  # 5 minutes cutover window
```

2. **Apply Migration Plan:**
```bash
oc apply -f database-server-01-warm-migration.yaml
```

**Step 3: Start Warm Migration with Data Copy Procedures**

1. **Red Hat MTV Warm Migration Data Copy Process:**
```bash
# Warm migration uses incremental data copy:
# VDD files are processed incrementally
# Changed block tracking (CBT) for efficiency

# Stage 1: Initial VDD metadata collection
govc vm.info "$VM_NAME" > vm-metadata.txt
govc vm.disk.info "$VM_NAME" > disk-metadata.txt

# Stage 2: Enable CBT on source VM
# Changed Block Tracking tracks which disk blocks changed
govc vm.changeTracking.enable "$VM_NAME"

# Stage 3: Initial full disk copy
# First pass copies entire disk with VDD metadata
# VDD file includes changed block tracking bitmap
```

2. **Initiate Warm Migration:**
```bash
# Start warm migration with CBT enabled
oc apply -f start-warm-migration.yaml

# Monitor initial data transfer
oc get migrations -n openshift-mtv -w

# Check VDD processing status
oc describe migration database-server-01-warm-migration -n openshift-mtv
```

3. **Monitor Initial Transfer:**
```bash
# Monitor migration progress with data copy metrics
oc get migrations -n openshift-mtv -w

# Check synchronization status and CBT efficiency
oc describe migration database-server-01-warm-migration -n openshift-mtv

# Monitor conversion host logs for CBT information
oc logs -f conversion-host-pod -n openshift-mtv -c converter | grep -i "CBT"
```

**Step 4: Monitor Synchronization with Incremental Data Copy**

1. **Monitor Sync Progress with CBT Tracking:**
```bash
# Check sync status with detailed data copy information
oc get migration database-server-01-warm-migration -n openshift-mtv -o yaml

# Monitor sync progress and incremental data copy
watch oc get migration database-server-01-warm-migration -n openshift-mtv

# Monitor changed block tracking efficiency
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "incremental"

# Check data transfer rates for incremental sync
oc describe migration database-server-01-warm-migration -n openshift-mtv | grep -i "transfer"
```

2. **Verify Data Consistency with VDD Updates:**
```bash
# Validate data consistency during warm migration
# MTV continuously updates VDD metadata during sync
# Check VDD file integrity and block tracking

# Monitor VDD processing on conversion host
oc exec -it conversion-host-pod -n openshift-mtv -- ls -lh /tmp/vdd-files/

# Verify checksum calculations for data blocks
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "checksum"

# Check for VDD synchronization errors
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "sync error"
```

**Step 5: Execute Cutover with Final Data Synchronization**

1. **Execute Final Data Synchronization:**
```bash
# During cutover, MTV performs final data sync
# All changed blocks since last sync are copied
# VDD metadata is updated to final state

# Initiate cutover
oc apply -f execute-cutover.yaml

# Monitor final data transfer
oc get migration database-server-01-warm-migration -n openshift-mtv -w

# Monitor conversion host for final sync details
oc logs -f conversion-host-pod -n openshift-mtv -c converter | grep -i "cutover"
```

2. **Shutdown Source VM After Final Sync:**
```bash
# Shutdown source VM after final synchronization
# VM is quiesced to ensure data consistency
govc vm.power -off "$VM_NAME"

# Verify VM is stopped and no data writes
govc vm.power "$VM_NAME"
```

3. **Start Target VM:**
```bash
# Start migrated VM on OpenShift
oc start vm database-server-01 -n production

# Verify VM is running
oc get vmi database-server-01 -n production
```

---

## Red Hat MTV Data Copy Procedures

### VDD (Virtual Disk Descriptor) File Handling

**VDD File Structure:**
```bash
# VDD files contain disk metadata and geometry
# Essential for accurate disk recreation on target
# Processed by MTV using virt-v2v converter

# VDD file components:
# - Disk geometry (cylinders, heads, sectors)
# - Disk capacity and type
# - Controller type and bus attachment
# - Parent-child relationships for snapshots
# - Changed Block Tracking (CBT) bitmap
```

**VDD Processing in MTV:**
```bash
# MTV VDD processing workflow:
1. Extract VDD from VMDK file
2. Parse VDD metadata
3. Convert to OpenShift-compatible format
4. Create PVC with correct size and type
5. Stream data from VMDK to PVC
6. Validate data integrity using VDD checksums

# Monitor VDD processing:
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "VDD"
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "descriptor"
```

### Changed Block Tracking (CBT) for Warm Migration

**CBT Configuration:**
```bash
# Enable Changed Block Tracking on source VM
# CBT reduces data transfer by copying only changed blocks

# Enable CBT via vSphere API
govc vm.changeTracking.enable "$VM_NAME"

# Verify CBT is enabled
govc vm.changeTracking.info "$VM_NAME"

# CBT bitmap location: .ctk files in VM directory
govc datastore.ls "$DATASTORE/$VM_NAME/" | grep ctk
```

**CBT Data Copy Process:**
```bash
# Warm migration CBT workflow:
1. Initial full copy of disk with VDD metadata
2. Capture initial CBT bitmap
3. Monitor for disk changes on source VM
4. Periodic incremental sync of changed blocks
5. Update CDT bitmap after each sync
6. Final sync copies all remaining changed blocks
7. CBT bitmap reset on cutover completion

# Monitor CBT efficiency:
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "blocks copied"
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "blocks skipped"
```

### Data Integrity Verification

**Checksum Validation:**
```bash
# MTV calculates checksums for data integrity
# SHA-256 checksums calculated per data chunk
# Verified during and after transfer

# Monitor checksum validation:
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "checksum"
oc describe migration migration-name -n openshift-mtv | grep -i "integrity"

# Manual checksum verification (if needed):
# Calculate source checksum
sha256sum /path/to/source/disk

# Calculate target checksum
oc exec -it vm-name -- sha256sum /dev/vda
```

**Data Consistency Checks:**
```bash
# For database VMs, perform consistency checks:
oc exec -it database-vm -- pg_checksums
oc exec -it database-vm -- mariadb-backup --backup

# For application VMs, validate file integrity:
oc exec -it app-vm -- find /app -type f -exec md5sum {} + > checksums.txt
```

### Storage Mapping and PVC Creation

**Storage Class Selection Based on VDD:**
```bash
# MTV analyzes VDD to determine optimal storage class
# VDD metadata includes disk type and performance characteristics

# VDD → Storage Class Mapping Logic:
- VDD indicates SSD tier → storage-class-ssd
- VDD indicates HDD tier → storage-class-hdd
- VDD indicates shared storage → storage-class-nfs

# Monitor storage class selection:
oc describe migration migration-name -n openshift-mtv | grep -i "storage class"
```

**PVC Creation with VDD Parameters:**
```bash
# MTV creates PVCs based on VDD disk information
# PVC size matches VDD reported capacity
# Access mode based on VDD sharing mode

# Verify PVC creation matches VDD specifications:
oc get pvc -n production
oc describe pvc vm-name-disk -n production | grep -i capacity
oc describe pvc vm-name-disk -n production | grep -i access

# Check Data Volume creation:
oc get datavolume -n production
oc describe datavolume vm-name -n production
```

### Error Handling and Retry Logic

**Data Copy Error Handling:**
```bash
# MTV implements retry logic for data transfer failures
- Network interruptions: Automatic retry with exponential backoff
- Data corruption: Checksum validation and re-transfer
- Storage failures: PVC recreation and data copy retry

# Monitor retry attempts:
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "retry"
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "backoff"

# Check for failed data transfers:
oc describe migration migration-name -n openshift-mtv | grep -i "failed"
```

**Rollback on Data Copy Failure:**
```bash
# If data copy fails, MTV automatically:
1. Stops data transfer
2. Logs error details
3. Cleans up partial data
4. Provides retry option
5. Maintains source VM integrity

# Monitor cleanup process:
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "cleanup"
oc logs conversion-host-pod -n openshift-mtv -c converter | grep -i "rollback"
```

---

1. **Notify Stakeholders:**
```bash
# Send notification of upcoming cutover
# Include maintenance window details
```

2. **Prepare for Cutover:**
```bash
# Prepare cutover procedure
# Document rollback procedures
# Prepare validation checks
```

**Step 6: Execute Cutover**

1. **Execute Final Cutover:**
```bash
# Initiate cutover
oc apply -f execute-cutover.yaml

# Monitor cutover progress
oc get migrations -n openshift-mtv -w
```

2. **Shutdown Source VM:**
```bash
# Shutdown source VM after cutover
govc vm.power -off "$VM_NAME"
```

3. **Start Target VM:**
```bash
# Start migrated VM
oc start vm database-server-01 -n production

# Verify VM is running
oc get vmi database-server-01 -n production
```

**Step 7: Post-Cutover Validation**

1. **Validate Network Connectivity:**
```bash
# Get VM IP address
VM_IP=$(oc get vmi database-server-01 -n production -o jsonpath='{.status.interfaces[0].ipAddress}')

# Test connectivity
ping -c 3 $VM_IP
nc -zv $VM_IP 5432  # PostgreSQL example
```

2. **Validate Application Functionality:**
```bash
# Test database connectivity
# Test application database connections
# Validate data integrity
```

3. **Performance Validation:**
```bash
# Validate performance meets baseline
# Test database queries
# Monitor resource utilization
```

**Step 8: Post-Cutover Configuration**

1. **Update DNS Records:**
```bash
# Update DNS if IP changed
nsupdate -k /etc/rndc.key <<EOF
server dns-server.example.com
zone example.com
update delete database-server-01.example.com. A
update add database-server-01.example.com. 300 A $VM_IP
send
EOF
```

2. **Update Load Balancer:**
```bash
# Add new backend to load balancer
# Test load balancer connectivity
```

3. **Update Monitoring:**
```bash
# Update monitoring configuration
# Add to alerting system
```

**Step 9: Cleanup**

1. **Remove Source VM:**
```bash
# Delete source VM from vCenter (after validation)
govc vm.destroy "$VM_NAME"
```

2. **Remove Migration Artifacts:**
```bash
# Clean up migration plan
oc delete migrationplan database-server-01-warm-migration -n openshift-mtv
```

---

## Post-Migration Validation

### Validation Checklist

**General Validation:**
- [ ] VM is running and accessible
- [ ] Network connectivity established
- [ ] Application functionality validated
- [ ] Performance meets or exceeds baseline
- [ ] Data integrity verified
- [ ] Backup and recovery tested
- [ ] Monitoring configured
- [ ] Alerts configured

**Network Validation:**
- [ ] IP address assigned correctly
- [ ] DNS resolution functional
- [ ] Network connectivity established
- [ ] Required ports accessible
- [ ] Network policies applied
- [ ] Load balancer traffic flowing

**Storage Validation:**
- [ ] Storage provisioned correctly
- [ ] Disk sizes match source
- [ ] Filesystem integrity verified
- [ ] Storage performance adequate
- [ ] Non-OS disks accessible
- [ ] Backup functional

**Security Validation:**
- [ ] RBAC permissions correct
- [ ] Secrets configured properly
- [ ] Network policies enforced
- [ ] Audit logging enabled
- [ ] Compliance requirements met

### Validation Procedures

**Network Validation Script:**
```bash
#!/bin/bash
# Network validation script
VM_NAME=$1
NAMESPACE=$2

echo "Validating network for $VM_NAME in $NAMESPACE"

# Get VM IP
VM_IP=$(oc get vmi $VM_NAME -n $NAMESPACE -o jsonpath='{.status.interfaces[0].ipAddress}')
echo "VM IP: $VM_IP"

# Test basic connectivity
echo "Testing basic connectivity..."
ping -c 5 $VM_IP

# Test specific ports
echo "Testing ports..."
nc -zv $VM_IP 22    # SSH
nc -zv $VM_IP 80    # HTTP
nc -zv $VM_IP 443   # HTTPS

# Test DNS resolution
echo "Testing DNS resolution..."
nslookup $VM_NAME.example.com

echo "Network validation complete"
```

**Application Validation Script:**
```bash
#!/bin/bash
# Application validation script
VM_NAME=$1
NAMESPACE=$2

echo "Validating application on $VM_NAME in $NAMESPACE"

# Get VM IP
VM_IP=$(oc get vmi $VM_NAME -n $NAMESPACE -o jsonpath='{.status.interfaces[0].ipAddress}')

# Test application health endpoint
echo "Testing application health..."
curl -f http://$VM_IP/health || echo "Health check failed"

# Test application functionality
echo "Testing application functionality..."
curl -f http://$VM_IP/api/test || echo "Application test failed"

echo "Application validation complete"
```

---

## Rollback Procedures

### Rollback Triggers

**Rollback Criteria:**
- Migration fails to complete
- Migrated VM fails to start
- Network connectivity cannot be established
- Application functionality compromised
- Performance degradation exceeds threshold
- Security issues detected
- Compliance violations identified

### Rollback Procedure

**Cold Migration Rollback:**

1. **Stop Migration:**
```bash
# Stop migration process
oc delete migration migration-name -n openshift-mtv
```

2. **Restore Source VM:**
```bash
# Restore source VM from snapshot
govc snapshot.revert "$VM_NAME" pre-migration-backup

# Power on source VM
govc vm.power -on "$VM_NAME"
```

3. **Clean Up Failed Migration:**
```bash
# Delete migration artifacts
oc delete vm $VM_NAME -n target-namespace
oc delete pvc -l migration-name=$VM_NAME -n target-namespace
```

**Warm Migration Rollback:**

1. **Abort Cutover:**
```bash
# Abort cutover process
oc delete migration migration-name -n openshift-mtv
```

2. **Ensure Source VM Running:**
```bash
# Ensure source VM is running
govc vm.power -on "$VM_NAME"
```

3. **Clean Up Target VM:**
```bash
# Delete target VM
oc delete vm $VM_NAME -n target-namespace
oc delete pvc -l migration-name=$VM_NAME -n target-namespace
```

---

## Special Case Procedures

### Non-OS Disk Migration

**NAS Disk Migration:**

1. **Document NAS Configuration:**
```bash
# Document NAS mount points
mount | grep nfs

# Document NAS server and share
cat /etc/fstab | grep nfs
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
```

### SAN Disk Migration

**SAN Disk Migration:**

1. **Document SAN Configuration:**
```bash
# Document LUN details
multipath -ll

# Document SAN configuration
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

---

## Windows VM Migration

### Windows-Specific Considerations

**Red Hat MTV Windows VM Requirements:**

**Supported Windows Versions:**
- **Windows Server 2016** - Fully supported (Datacenter, Standard)
- **Windows Server 2019** - Fully supported (Datacenter, Standard)  
- **Windows Server 2022** - Fully supported (Datacenter, Standard)
- **Windows 10 Enterprise LTSC 2019** - Supported for specialized workloads
- **Windows 11 Enterprise** - Supported for development/testing

**Windows VM Configuration Requirements:**
- **UEFI Firmware:** Required for Windows Server 2022 and Windows 11
- **Secure Boot:** Can be enabled but may require MTV compatibility mode
- **Disk Type:** VMDK must be in thin provisioned format
- **Generation:** Gen 2 (UEFI-based) preferred over Gen 1 (BIOS-based)

### Network Adapter Compatibility

**VMware Network Adapter Types vs OpenShift Virtualization:**

| VMware Adapter | OpenShift Equivalent | Windows Compatibility | Configuration Required |
|----------------|----------------------|----------------------|------------------------|
| VMXNET3 | virtio | Full support with drivers | Install virtio-win drivers |
| E1000e | virtio | Supported, requires drivers | Install virtio-win drivers |
| VMXNET2 | virtio | Not recommended | Migrate to VMXNET3 first |
| E1000 | virtio | Legacy support only | Install virtio-win drivers |

**Example 1: VMXNET3 to virtio Migration**
```powershell
# Source: Windows Server 2019 with VMXNET3
# Target: virtio network adapter in OpenShift
# Procedure: Install virtio-win drivers before migration

# Download: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/
# File: virtio-win-guest-tools-installer.exe

# Installation steps on Windows Server 2019:
1. Download and run virtio-win-guest-tools-installer.exe
2. Accept license agreement
3. Select components: Network driver (required), Disk driver (required)
4. Complete installation and reboot VM
5. Verify: Device Manager → Network adapters should show "Red Hat VirtIO Ethernet Adapter"
6. Test: Check network connectivity to ensure adapter is functional
```

**Example 2: E1000e to virtio Migration**
```powershell
# Source: Windows Server 2016 with E1000e
# Target: virtio network adapter in OpenShift
# Procedure: Install virtio-win drivers before migration

# Note: E1000e is older adapter type, consider upgrading to VMXNET3 in VMware first
# This improves performance and compatibility with OpenShift Virtualization
```

### Windows Driver Compatibility

**Required Drivers for Windows VMs on OpenShift Virtualization:**

**VirtIO Drivers (Fedora Project):**
- **virtio-win-guest-tools-installer.exe** - All-in-one installer
- **virtio-win-xx-xx.iso** - ISO for driver installation
- **virtio-win-netxx.zip** - Network drivers only
- **virtio-win-gt.zip** - Guest agent only

**Driver Types and Compatibility:**

| Driver Type | VMware Equivalent | Windows Version Support | Installation Method |
|-------------|------------------|-------------------------|--------------------|
| Network (virtio-net) | VMXNET3 | Win 2016, 2019, 2022, Win 10/11 | exe installer or ISO |
| Disk (virtio-blk) | PVSCSI/LSI Logic SAS | Win 2016, 2019, 2022, Win 10/11 | exe installer or ISO |
| Balloon (virtio-balloon) | VM memory balloon | Win 2016, 2019, 2022 | exe installer only |
| Serial (virtio-serial) | VMware paravirtual serial | Win 2016, 2019, 2022 | exe installer only |
| Input (virtio-input) | VMware paravirtual input | Win 10/11 only | exe installer only |

**Example 1: Network Driver Installation (VMXNET3 → virtio-net)**
```powershell
# For Windows Server 2019 with VMXNET3 adapter
# Download and install virtio-win network driver

# Download: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/
# File: virtio-win-guest-tools-installer.exe

# Installation steps:
1. Download virtio-win-guest-tools-installer.exe
2. Run installer with administrator privileges
3. Accept license agreement
4. Select components: Network driver (required), Disk driver (required)
5. Complete installation and reboot VM
6. Verify: Device Manager → Network adapters should show "Red Hat VirtIO Ethernet Adapter"
7. Test: Check network connectivity to ensure adapter is functional
```

**Example 2: Disk Driver Installation (PVSCSI → virtio-blk)**
```powershell
# For Windows Server 2022, disk driver is critical for boot
# Windows 2022 may require UEFI + virtio-blk for successful boot

# Installation steps:
1. Download virtio-win-guest-tools-installer.exe
2. Install disk driver component
3. Reboot VM
4. Verify: Device Manager → Disk drives should show "Red Hat VirtIO SCSI Disk Device"
5. Test: Ensure disk I/O performance is acceptable
```

### Windows Version Compatibility Issues

**Known Compatibility Issues and Solutions:**

**Issue 1: Windows Server 2008/2012 Compatibility**
```powershell
# Problem: Windows Server 2008 R2 and 2012 are not fully supported by MTV
# Reason: Missing virtio driver support, security end of life
# Solution: 
# Option A: Upgrade to Windows Server 2019 or 2022 before migration
# Option B: Use containerization approach (convert to container)
# Option C: Use legacy driver approach with limitations

# For upgrades, use Windows Server Migration Tools:
# Download: https://www.microsoft.com/en-us/windows-server/migration
# Perform in-place upgrade to supported Windows version
```

**Issue 2: Windows 7/8 Compatibility**
```powershell
# Problem: Windows 7/8 are not supported by MTV
# Reason: No virtio driver support, security end of life
# Solution:
# Option A: Upgrade to Windows 10/11
# Option B: Use containerization approach
# Option C: Migrate to newer Windows version
```

**Issue 3: Windows Server 2022 UEFI Requirements**
```powershell
# Problem: Windows Server 2022 requires UEFI firmware
# Solution:
# Convert VMware VM firmware from BIOS to UEFI before migration
# This may require Windows re-installation or conversion using tools like virt-v2v

# Conversion command (if using virt-v2v directly):
virt-v2v -i vmx "/vmfs/volumes/datastore1/Win2022/Win2022.vmx" \
         -o local -os /path/to/output --os-variant win2k22
```

### Guest Agent Installation for Windows

**OpenShift Guest Agent for Windows:**
```powershell
# The KubeVirt guest agent provides additional functionality:
- Memory balloon support
- QEMU guest agent commands
- File system quiescing for better snapshots
- IP address reporting

# Download: https://github.com/kubevirt/kubevirt/releases
# Windows guest agent: kubevirt-guest-agent-windows-latest.exe

# Installation steps on Windows VM:
1. Download kubevirt-guest-agent-windows-latest.exe
2. Run installer with administrator privileges
3. Configure agent to run as service
4. Test: OpenShift can communicate with guest agent
5. Verify: oc get vmi vm-name -n namespace should show guest agent connected
```

**Windows VM Migration Steps:**

1. **Pre-Migration Preparation:**
```powershell
# Update Windows to latest patches
Install-Module PSWindowsUpdate
Import-Module PSWindowsUpdate
Get-WindowsUpdate -Install -AcceptAll

# Install VMware Tools and ensure latest version
# Then install virtio-win drivers

# Install OpenShift Guest Agent
# Download from https://github.com/kubevirt/kubevirt/releases
# Run kubevirt-guest-agent-windows-latest.exe
```

2. **Configure Network with virtio Drivers:**
```powershell
# Configure Windows network settings after driver installation
# Ensure IP configuration is documented
# Configure DNS settings

# Verify network adapter: Get-NetAdapter
# Test connectivity: Test-NetConnection -ComputerName target-server -Port 3389
```

3. **Execute Migration:**
```bash
# Follow standard cold or warm migration procedure
# MTv will handle network adapter type conversion from VMXNET3 to virtio
# Disk controller conversion from VMware PVSCSI to virtio-blk
```

4. **Post-Migration Validation:**
```powershell
# Validate Windows services
Get-Service | Where-Object {$_.Status -eq "Running"}

# Validate network connectivity
Test-NetConnection -ComputerName target-server -Port 3389

# Validate Windows activation
# Activate Windows if required using KMS or MAK key
# For KMS: slmgr /skms your-kms-server
slmgr /ato
```

### Windows VM Challenges

**Network Adapter Challenges:**
- **VMXNET3 to virtio conversion** - Requires virtio-win driver installation
- **E1000 compatibility** - Legacy adapter type may require driver updates
- **Multiple network adapters** - Each adapter requires driver installation
- **Solution:** Install virtio-win-guest-tools-installer.exe before migration

**Windows Version Challenges:**
- **Server 2008/2012** - Not supported, requires upgrade to 2016+
- **Windows 7/8** - Not supported, requires upgrade to 10/11
- **Server 2022 UEFI** - Requires firmware conversion
- **Solution:** Perform Windows upgrades before migration or use containerization

**Driver Compatibility Challenges:**
- **Missing disk drivers** - VM won't boot after migration
- **Missing network drivers** - No network connectivity
- **Solution:** Install complete virtio-win driver package before migration

**Licensing Challenges:**
- **License activation** - May require reactivation after migration
- **KMS configuration** - Update KMS server settings for new environment
- **Solution:** Document license keys, prepare KMS server for new IPs

### Windows VM Troubleshooting

**Common Windows Migration Issues:**

**Issue 1: Windows VM Won't Boot After Migration**
```powershell
# Symptom: Blue screen or boot loop after migration
# Cause: Missing or incompatible disk drivers (virtio-blk)

# Solution:
1. Boot into Windows recovery mode
2. Install virtio-win disk driver from ISO
3. Reboot VM
4. Alternatively, pre-install drivers before migration
```

**Issue 2: Network Connectivity Lost**
```powershell
# Symptom: No network connectivity after migration
# Cause: Missing or incompatible network drivers (virtio-net)

# Solution:
1. Access VM console
2. Install virtio-win network driver
3. Configure network adapter settings
4. Test connectivity: ping 8.8.8.8
```

**Issue 3: Guest Agent Not Connected**
```powershell
# Symptom: Guest agent not showing as connected
# Cause: Guest agent service not running or blocked by firewall

# Solution:
1. Check Windows Firewall: netsh firewall show rule name=all
2. Allow guest agent communication through firewall
3. Restart guest agent service: Restart-Service kubevirt-guest-agent
4. Verify: oc get vmi vm-name -n namespace
```
- Service configuration differences

---

## Linux VM Migration

### Linux-Specific Considerations

**Linux VM Migration Steps:**

1. **Pre-Migration Preparation:**
```bash
# Update Linux to latest packages
yum update -y  # RHEL/CentOS
apt update && apt upgrade -y  # Debian/Ubuntu

# Install VMware Tools
# Ensure VMware Tools is latest version
```

2. **Install OpenShift Guest Agent:**
```bash
# Download and install guest agent
# (Download from OpenShift Virtualization repository)
# Install guest agent for Linux
```

3. **Configure Network:**
```bash
# Configure Linux network settings
# Ensure IP configuration is documented
# Configure DNS settings
# Update /etc/hosts if required
```

4. **Execute Migration:**
```bash
# Follow standard cold or warm migration procedure
# Additional Linux-specific steps may be required
```

5. **Post-Migration Validation:**
```bash
# Validate services
systemctl status

# Validate network connectivity
ping -c 3 target-server
ssh target-server

# Validate kernel modules
lsmod
```

### Linux VM Challenges

**Common Linux Migration Issues:**
- Kernel version compatibility
- Package repository changes
- Systemd vs init compatibility
- SELinux configuration
- Filesystem differences

---

## Next Steps

Upon completion of manual migration procedures:
- **Implement Automated Migration:** 08-automated-migration.md
- **Review Interview Scenarios:** 09-interview-scenarios.md

---

**Document Status:** Complete  
**Next Review Date:** [TBD]  
**Approved By:** [Approver Name]  
**Approval Date:** [Date]