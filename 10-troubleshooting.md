# Troubleshooting Guide

**Document:** 10-troubleshooting.md  
**Phase:** Troubleshooting and Issue Resolution  
**Status:** Troubleshooting Reference

---

## RedHat Official Documentation Reference

This troubleshooting guide is enhanced with scenarios from the official RedHat MTV documentation:
- [RedHat MTV Troubleshooting Documentation](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/assembly_troubleshooting-migration_mtv)

## Troubleshooting Workflow

### Standard Troubleshooting Process

1. **Identify the Issue Category**
   - Migration execution issues
   - VM startup issues
   - Network connectivity issues
   - Storage provisioning issues
   - Provider connectivity issues
   - Specific error messages

2. **Gather Diagnostic Information**
   - Check migration status and logs
   - Review provider connectivity
   - Examine network and storage configurations
   - Collect system logs using must-gather

3. **Apply Specific Resolution Steps**
   - Follow the appropriate troubleshooting procedure
   - Test the resolution
   - Verify the fix is complete

4. **Document the Resolution**
   - Record the issue and resolution
   - Update configuration if needed
   - Share lessons learned

### Using Must-Gather Tool

When facing complex issues, use the MTV must-gather tool to collect comprehensive diagnostic information:

```bash
# Install must-gather if not already installed
oc adm must-gather --image=quay.io/konveyor/forklift-must-gather:latest \
  --dest-dir=/tmp/mtv-must-gather

# Analyze the collected logs
cd /tmp/mtv-must-gather
# Review the collected logs and custom resources
```

**Reference:** [Using the must-gather tool](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/using-the-must-gather-tool_troubleshooting-migration_mtv)

---

## Understanding VDDK (Virtual Disk Development Kit)

### What is VDDK?

**VDDK (Virtual Disk Development Kit)** is a VMware-provided library and set of tools that allows applications to access and manipulate VMware virtual machine disk files. In the context of OpenShift Migration Toolkit for Virtualization (MTV), VDDK is essential for:

- **Reading VMware VM disk data** from vSphere datastores during migration
- **Converting disk formats** from VMware formats (VMDK) to formats compatible with OpenShift Virtualization
- **Accessing VM storage** through VMware vSphere APIs
- **Enabling storage-level operations** during migration

### Why VDDK is Critical for MTV Migrations

1. **Disk Data Access**: VDDK provides the only supported method to read VM disk data from VMware vSphere environments
2. **Format Conversion**: Converts VMware-specific disk formats to standard formats used by OpenShift
3. **Storage Integration**: Enables direct communication with VMware vSphere storage backends
4. **Performance Optimization**: Provides optimized disk access for faster migration performance

### Common VDDK-Related Issues

**VDDK issues typically manifest as:**
- Migration failures during the conversion phase
- "Failed to pull VDDK image" errors
- Disk access errors during migration
- vSAN compatibility problems
- Performance bottlenecks during disk transfer
- Connection timeouts to VMware storage systems

**Root Causes of VDDK Issues:**
- **Image Availability**: VDDK container image not accessible from OpenShift
- **Version Compatibility**: VDDK version incompatible with VMware vSphere version
- **Network Connectivity**: OpenShift cannot reach VMware vSphere storage systems
- **Authentication**: Missing or incorrect credentials for VMware storage access
- **Storage Configuration**: VMware storage (vSAN, NFS, etc.) misconfiguration
- **Resource Limitations**: Insufficient resources for VDDK operations

### VDDK in Migration Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                  VDDK Migration Flow                        │
├─────────────────────────────────────────────────────────────┤
│ 1. MTV pulls VDDK image from container registry            │
│ 2. Conversion pod starts with VDDK image                  │
│ 3. VDDK establishes connection to VMware vCenter/vSAN       │
│ 4. VDDK reads VM disk data from VMware storage              │
│ 5. Disk data is converted and written to OpenShift storage   │
│ 6. Migration completes successfully                       │
└─────────────────────────────────────────────────────────────┘
```

### VDDK Image Configuration

**VDDK images are containerized versions of the VMware VDDK libraries:**
- **Source**: VMware-provided container images hosted in container registries
- **Versions**: Different versions support different VMware vSphere versions
- **Configuration**: Must be specified in the VMware provider configuration
- **Pull Requirements**: May require authentication for private registries

**Example VDDK Image Configuration:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: vsphere-provider
  namespace: openshift-mtv
spec:
  type: vsphere
  settings:
    vddk_init_image: quay.io/konveyor/forklift-vddk:latest
    url: "https://vcenter.example.com"
```

### VDDK Compatibility Considerations

**Version Compatibility Matrix:**
- **vSphere 6.7+**: Use VDDK 7.x versions
- **vSphere 7.0+**: Use VDDK 7.x or 8.x versions  
- **vSphere 8.0+**: Use VDDK 8.x versions for optimal compatibility
- **vSAN Compatibility**: Check VMware compatibility matrix for vSAN-specific requirements

**Storage-Specific Considerations:**
- **vSAN**: Requires vSAN-compatible VDDK version and proper permissions
- **NFS**: Requires network connectivity and appropriate mount configurations
- **VMFS**: Standard VDDK operations with standard permissions
- **Storage Copy Offload**: Enables faster data transfer when supported

---

## Common Migration Issues

### Issue 1: Migration Fails to Start

**Symptoms:**
- Migration plan stuck in "Pending" state
- No error messages visible
- MTV controller not responding

**Detailed Issue Description:**
The migration plan is created and initiated, but it remains in a "Pending" state without progressing to the actual migration execution. This typically indicates issues with the MTV controller, provider connectivity, or network configuration that prevent the migration from starting.

**RedHat Documentation Reference:**
- [Common Migration Issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/common-migration-issues_troubleshooting-migration_mtv)

**Troubleshooting Steps:**
1. **Check MTV controller pod status:**
   ```bash
   oc get pods -n openshift-mtv
   oc logs mtv-controller-xxxxx -n openshift-mtv
   oc describe pod mtv-controller-xxxxx -n openshift-mtv
   ```

2. **Validate provider connections:**
   ```bash
   oc get provider -n openshift-mtv
   oc describe provider vmware-provider -n openshift-mtv
   oc describe provider openshift-provider -n openshift-mtv
   ```

3. **Check network connectivity:**
   ```bash
   oc exec -it mtv-controller-xxxxx -n openshift-mtv -- ping vcenter.example.com
   oc exec -it mtv-controller-xxxxx -n openshift-mtv -- telnet vcenter.example.com 443
   ```

4. **Verify RBAC permissions:**
   ```bash
   oc auth can-i --list --as=system:serviceaccount:openshift-mtv:mtv-controller
   oc describe clusterrolebinding mtv-controller
   ```

5. **Check migration plan status:**
   ```bash
   oc get migrationplan -n openshift-mtv
   oc describe migrationplan <plan-name> -n openshift-mtv
   ```

**Solutions:**
- **Restart MTV controller pod:** `oc delete pod mtv-controller-xxxxx -n openshift-mtv`
- **Recreate provider credentials:** Delete and recreate provider secrets
- **Verify network policies allow connectivity:** Ensure network policies permit MTV controller to reach vCenter
- **Check vCenter API accessibility:** Validate vCenter API endpoint is reachable and responsive
- **Update provider configuration:** Ensure provider URL and credentials are correct
- **Check MTV operator version:** Verify compatibility between MTV operator and OpenShift version
- **Review resource quotas:** Ensure sufficient resources are available in the target namespace

**Preventive Measures:**
- Regularly monitor MTV controller pod health
- Implement network policies that explicitly allow MTV traffic
- Use dedicated service accounts with appropriate RBAC permissions
- Monitor resource quotas and capacity
- Test provider connectivity before migrations

---

### Issue 2: VM Fails to Start After Migration

**Symptoms:**
- VM created but fails to start
- VMI stuck in "Scheduling" or "Failed" state
- Error: "Insufficient resources"

**Detailed Issue Description:**
The VM migration completes successfully and the VM is created in OpenShift Virtualization, but the VM fails to start. This can be due to resource constraints, scheduling issues, network configuration problems, or driver compatibility issues.

**RedHat Documentation Reference:**
- [Common Migration Issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/common-migration-issues_troubleshooting-migration_mtv)

**Troubleshooting Steps:**
1. **Check VM status:**
   ```bash
   oc get vm vm-name -n namespace
   oc describe vm vm-name -n namespace
   ```

2. **Check VMI status:**
   ```bash
   oc get vmi vm-name -n namespace
   oc describe vmi vm-name -n namespace
   oc get events --field-selector involvedObject.kind=VirtualMachineInstance,involvedObject.name=vm-name -n namespace
   ```

3. **Check node capacity:**
   ```bash
   oc describe nodes
   oc get nodes -o wide
   oc top nodes
   ```

4. **Review scheduling constraints:**
   ```bash
   oc get vm vm-name -n namespace -o yaml | grep -A 10 affinity
   oc get nodes --show-labels
   ```

5. **Check resource requests/limits:**
   ```bash
   oc get vm vm-name -n namespace -o yaml | grep -A 5 resources
   oc describe quota -n namespace
   ```

6. **Verify network attachment definitions:**
   ```bash
   oc get network-attachment-definition -A
   oc describe network-attachment-definition <network-name> -n namespace
   ```

**Solutions:**
- **Add additional worker nodes:** Scale up the OpenShift cluster to provide more resources
- **Adjust VM resource requests/limits:** Reduce CPU and memory requirements if over-provisioned
- **Check node scheduling constraints:** Remove or modify affinity/anti-affinity rules
- **Verify resource quotas:** Increase namespace resource quotas or move VMs to different namespaces
- **Fix network configuration:** Ensure network attachment definitions are properly configured
- **Install missing drivers:** Add required drivers for Windows VMs (virtio-win)
- **Check storage provisioning:** Ensure PVCs are bound and storage is accessible
- **Review node taints:** Remove taints that prevent scheduling on specific nodes

**Preventive Measures:**
- Conduct capacity planning before migrations
- Test resource requirements with small migrations first
- Monitor cluster resource utilization regularly
- Implement proper node labeling and tainting strategies
- Use resource quotas to prevent overcommitment

---

**Troubleshooting Steps:**
1. Check VM status:
   ```bash
   oc get vm vm-name -n namespace
   oc describe vm vm-name -n namespace
   ```

2. Check VMI status:
   ```bash
   oc get vmi vm-name -n namespace
   oc describe vmi vm-name -n namespace
   ```

3. Check node capacity:
   ```bash
   oc describe nodes
   oc get nodes -o wide
   ```

**Solutions:**
- Add additional worker nodes
- Adjust VM resource requests/limits
- Check node scheduling constraints
- Verify resource quotas

---

### Issue 3: Network Connectivity Issues

**Symptoms:**
- VM cannot be reached via network
- IP address not assigned
- DNS resolution fails

**Detailed Issue Description:**
The VM migrates successfully and starts, but network connectivity is not established. This can occur due to network attachment definition misconfiguration, VLAN misconfiguration, bridge configuration issues, or network policy restrictions.

**RedHat Documentation Reference:**
- [Common Migration Issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/common-migration-issues_troubleshooting-migration_mtv)

**Troubleshooting Steps:**
1. **Check VM network interfaces:**
   ```bash
   oc get vmi vm-name -n namespace -o yaml | grep -A 10 interfaces
   oc describe vmi vm-name -n namespace
   ```

2. **Check network attachment definitions:**
   ```bash
   oc get network-attachment-definition -A
   oc describe network-attachment-definition vlan-10-production -n namespace
   ```

3. **Test connectivity from VM:**
   ```bash
   oc rsh vmi vm-name -n namespace -- ping -c 3 8.8.8.8
   oc rsh vmi vm-name -n namespace -- ip addr show
   ```

4. **Check network policies:**
   ```bash
   oc get networkpolicy -A
   oc describe networkpolicy <policy-name> -n namespace
   ```

5. **Verify bridge configuration:**
   ```bash
   oc get node -o wide
   oc debug node/<node-name> -- chroot /host -- ip link show
   ```

**Solutions:**
- **Verify VLAN configuration:** Ensure VLAN ID and bridge configuration match network setup
- **Check network policies:** Update network policies to allow required traffic
- **Validate bridge configuration:** Ensure network attachment definitions reference correct bridges
- **Update DNS records:** Add VM hostname to DNS or configure static IP
- **Check MTU settings:** Ensure MTU settings are consistent across the network path
- **Review DHCP configuration:** Verify DHCP is providing correct IP addresses
- **Test network attachment:** Create test pod with same network attachment to validate

**Preventive Measures:**
- Test network attachment definitions before migration
- Document network configurations and mappings
- Use consistent VLAN and IP addressing schemes
- Monitor network performance during migrations
- Implement network monitoring and alerting

---

## RedHat-Specific Error Scenarios

### Issue 4: Warm Import Retry Limit Errors

**Symptoms:**
- Warm migration fails during import phase
- Error message: "Warm import retry limit exceeded"
- Migration stuck in "Importing" state
- Data synchronization failures

**Detailed Issue Description:**
Warm migrations involve continuous data synchronization from the source VM to the target. When the synchronization process encounters repeated failures during the import phase, it may exceed the configured retry limit and fail the migration. This typically occurs due to network instability, storage performance issues, or source VM configuration problems.

**RedHat Documentation Reference:**
- [Resolving warm import retry limit errors](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/proc_resolving-warm-import-retry-limit-errors_troubleshooting-migration_mtv)

**Root Causes:**
- Network connectivity instability between vCenter and OpenShift
- Storage performance bottlenecks during data transfer
- Insufficient timeout configurations
- Source VM high I/O load during synchronization
- VDDK (Virtual Disk Development Kit) issues
- Large VM disk sizes requiring extended transfer times

**Troubleshooting Steps:**
1. **Check migration status and logs:**
   ```bash
   oc get migration <migration-name> -n openshift-mtv
   oc describe migration <migration-name> -n openshift-mtv
   oc logs -f <conversion-pod-name> -n openshift-mtv
   ```

2. **Monitor network connectivity:**
   ```bash
   # From MTV controller pod
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- ping vcenter.example.com
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- telnet vcenter.example.com 443
   ```

3. **Check storage performance:**
   ```bash
   # Monitor storage I/O during migration
   oc top pods -n openshift-mtv
   oc get pv -o wide
   oc describe pvc <pvc-name> -n <target-namespace>
   ```

4. **Review timeout configurations:**
   ```bash
   oc get configmap -n openshift-mtv
   oc describe configmap <mtv-config> -n openshift-mtv
   ```

5. **Check VDDK image status:**
   ```bash
   oc get pods -n openshift-mtv
   oc describe pod <conversion-pod-name> -n openshift-mtv
   ```

**Solutions:**
- **Increase timeout settings:** Adjust MTV timeout configurations for large disk transfers
  ```bash
  oc edit configmap mtv-config -n openshift-mtv
  # Add or modify timeout settings
  ```

- **Improve network stability:** Ensure stable, high-bandwidth network connection between vCenter and OpenShift
- **Schedule migrations during low I/O periods:** Perform warm migrations when source VM I/O is minimal
- **Upgrade VDDK version:** Use latest VDDK image for better compatibility and performance
- **Reduce disk size:** Consider splitting large disks into smaller partitions
- **Increase retry limits:** Configure higher retry limits in provider settings
- **Use storage copy offload:** For vSphere environments, implement storage copy offload to improve performance

**Configuration Example:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: vsphere-provider
  namespace: openshift-mtv
spec:
  type: vsphere
  settings:
    # Increase timeout for large transfers
    timeout: 3600  # 1 hour in seconds
    # Enable storage copy offload if supported
    storage_copy_offload: true
```

**Preventive Measures:**
- Conduct network performance testing before migrations
- Monitor storage performance during migrations
- Use appropriate timeout settings based on disk size
- Test warm migrations with smaller VMs first
- Implement network QoS for migration traffic
- Schedule migrations during off-peak hours

---

**Troubleshooting Steps:**
1. Check VM network interfaces:
   ```bash
   oc get vmi vm-name -n namespace -o yaml | grep -A 10 interfaces
   ```

2. Check network attachment definitions:
   ```bash
   oc get network-attachment-definition -A
   oc describe network-attachment-definition vlan-10-production -n openshift-mtv
   ```

3. Test connectivity from VM:
   ```bash
   oc rsh vmi vm-name -n namespace -- ping -c 3 8.8.8.8
   ```

**Solutions:**
- Verify VLAN configuration
- Check network policies
- Validate bridge configuration
- Update DNS records

---

### Issue 5: Storage Provisioning Failures

**Symptoms:**
- PVC stuck in "Pending" state
- Storage class not available
- Insufficient storage capacity

**Detailed Issue Description:**
Storage provisioning failures occur when OpenShift cannot create or bind persistent volume claims for migrated VM disks. This can be due to missing storage classes, insufficient capacity, CSI driver issues, or incorrect storage configuration.

**RedHat Documentation Reference:**
- [Common Migration Issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/common-migration-issues_troubleshooting-migration_mtv)

**Troubleshooting Steps:**
1. **Check PVC status:**
   ```bash
   oc get pvc -A
   oc describe pvc pvc-name -n namespace
   oc get events --field-selector involvedObject.kind=PersistentVolumeClaim,involvedObject.name=pvc-name -n namespace
   ```

2. **Check storage classes:**
   ```bash
   oc get sc
   oc describe sc storage-class-name
   ```

3. **Check PV availability:**
   ```bash
   oc get pv
   oc describe pv pv-name
   ```

4. **Verify CSI driver status:**
   ```bash
   oc get csidriver
   oc get pods -n <csi-driver-namespace>
   ```

5. **Check storage capacity:**
   ```bash
   oc describe nodes
   oc get capacityinfrastructure -A  # if using Capacity addon
   ```

**Solutions:**
- **Verify storage class exists and is default:** Ensure proper storage classes are configured
- **Check CSI driver status:** Restart CSI driver pods if needed
- **Add additional storage capacity:** Scale up storage backend or add new storage
- **Adjust storage class binding mode:** Change from WaitForFirstConsumer to Immediate if needed
- **Verify storage quota:** Ensure namespace has sufficient storage quota
- **Check storage driver configuration:** Validate CSI driver configuration parameters
- **Review storage performance:** Ensure storage backend can handle the I/O load

**Preventive Measures:**
- Monitor storage capacity regularly
- Implement storage capacity planning
- Test storage provisioning before migrations
- Use appropriate storage classes for different workloads
- Monitor CSI driver health
- Implement storage alerts and notifications

---

### Issue 6: Disk Resize Errors

**Symptoms:**
- Migration fails with disk resize error
- Error message: "Failed to resize disk"
- PVC creation fails during migration
- Storage mapping errors

**Detailed Issue Description:**
Disk resize errors occur when MTV attempts to resize VM disks during migration but encounters issues with the target storage class or PVC configuration. This can happen when the target storage class doesn't support volume expansion, when the disk size exceeds storage limits, or when there are storage class configuration issues.

**RedHat Documentation Reference:**
- [Resolving disk resize errors](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/proc_resolving-disk-resize-errors_troubleshooting-migration_mtv)

**Root Causes:**
- Storage class doesn't support volume expansion
- Disk size exceeds storage class limits
- Incorrect storage mapping configuration
- PVC resizing not supported by CSI driver
- Insufficient storage capacity in target storage class
- Storage class volume binding mode issues

**Troubleshooting Steps:**
1. **Check migration error details:**
   ```bash
   oc get migration <migration-name> -n openshift-mtv
   oc describe migration <migration-name> -n openshift-mtv
   oc logs <migration-pod> -n openshift-mtv | grep -i "resize"
   ```

2. **Verify storage class volume expansion:**
   ```bash
   oc get sc -o yaml | grep -A 5 allowVolumeExpansion
   oc describe sc <storage-class-name>
   ```

3. **Check disk size limits:**
   ```bash
   # Check source disk size
   govc vm.disk.info <vm-name>
   
   # Check storage class limits
   oc get sc -o yaml | grep -A 10 parameters
   ```

4. **Review storage mapping configuration:**
   ```bash
   oc get migrationplan <plan-name> -n openshift-mtv -o yaml
   oc describe migrationplan <plan-name> -n openshift-mtv
   ```

5. **Test PVC creation with resize:**
   ```bash
   cat <<EOF | oc apply -f -
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: test-resize-pvc
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 10Gi
   EOF
   ```

**Solutions:**
- **Enable volume expansion on storage class:**
  ```yaml
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: storage-class-name
  allowVolumeExpansion: true
  ```

- **Use storage class that supports resizing:** Select storage classes that support PVC resizing
- **Adjust disk size to fit within limits:** Modify VM disk size before migration or select appropriate storage class
- **Fix storage mapping configuration:** Ensure storage mappings are correctly configured
- **Upgrade CSI driver:** Use CSI driver version that supports volume expansion
- **Change volume binding mode:** Adjust from WaitForFirstConsumer to Immediate if appropriate
- **Pre-provision PVs:** Manually create PVs with appropriate sizes

**Configuration Example:**
```yaml
# Storage class with volume expansion enabled
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-expandable
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
provisioner: csi.driver.example.com
parameters:
  type: ssd
  resize: "true"
```

**Preventive Measures:**
- Test storage class volume expansion capabilities
- Use storage classes that support required features
- Monitor storage capacity and limits
- Implement proper storage class selection based on workload requirements
- Regular test PVC creation and resizing operations

---

**Troubleshooting Steps:**
1. Check PVC status:
   ```bash
   oc get pvc -A
   oc describe pvc pvc-name -n namespace
   ```

2. Check storage classes:
   ```bash
   oc get sc
   oc describe sc storage-class-ssd
   ```

3. Check PV availability:
   ```bash
   oc get pv
   oc describe pv pv-name
   ```

**Solutions:**
- Verify storage class exists and is default
- Check CSI driver status
- Add additional storage capacity
- Adjust storage class binding mode

---

## Windows-Specific Issues

### Issue 5: Windows VM Boot Failures

**Symptoms:**
- Windows VM fails to boot after migration
- Blue screen of death (BSOD)
- Boot loop
- "Operating system not found" error

**Troubleshooting Steps:**
1. Check VM console:
   ```bash
   oc console vmi vm-name -n namespace
   ```

2. Check Windows boot configuration:
   ```bash
   oc exec -it vm-name -n namespace -- bcdedit /enum all
   ```

3. Check UEFI/BIOS firmware type:
   ```bash
   oc get vm vm-name -n namespace -o yaml | grep firmware
   ```

**Solutions:**
- Validate Windows compatibility with MTV (Win 2016+, 2019+, 2022 supported)
- Install required drivers (virtio-win-guest-tools-installer.exe)
- Check Windows activation status and reconfigure if needed
- Convert firmware type (BIOS to UEFI for Windows 2022 using VMware tools)
- Use Windows recovery mode or safe mode
- Perform in-place Windows upgrade if compatibility issues

### Issue 6: Windows Network Adapter Issues

**Symptoms:**
- Network adapter not detected in Windows
- IP address not assigned
- Network connectivity fails
- "Media disconnected" in Windows

**Troubleshooting Steps:**
1. Check VM network configuration:
   ```bash
   oc get vmi vm-name -n namespace -o yaml | grep -A 10 interfaces
   ```

2. Check Windows Device Manager:
   ```bash
   oc exec -it vm-name -n namespace -- devmgmt.msc
   ```

3. Check Windows network settings:
   ```bash
   oc exec -it vm-name -n namespace -- ipconfig /all
   ```

4. Check for missing drivers (yellow exclamation marks in Device Manager):
   ```bash
   oc exec -it vm-name -n namespace -- powershell -Command "Get-WmiObject Win32_PnPEntity | Where-Object {$_.ConfigManagerErrorCode -ne 0}"
   ```

**Solutions:**
- Install VirtIO drivers for Windows (virtio-win-guest-tools-installer.exe)
- Convert network adapter type from VMXNET3 to virtio
- Update network adapter configuration in Windows
- Restart Windows network service: netsh interface set interface name=admin
- Reinstall network adapter driver if needed
- Convert E1000/E1000e to VMXNET3 before migration for better compatibility

### Issue 7: Windows Driver Compatibility

**Symptoms:**
- Device Manager shows missing drivers
- Unknown devices in Device Manager
- VM functions but with errors
- Performance degradation

**Troubleshooting Steps:**
1. Check for missing drivers:
   ```powershell
   # In Windows Device Manager, check for devices with yellow exclamation marks
   # Common missing drivers: virtio-blk (disk), virtio-net (network), virtio-balloon
   ```

2. Check driver versions:
   ```powershell
   Get-WmiObject Win32_PnPSignedDriver | Select-Object DeviceName, DriverVersion, DriverDate
   ```

**Solutions:**
- Download and install latest virtio-win drivers from Fedora project (https://fedorapeople.org/groups/virt/virtio-win/)
- Use virtio-win-guest-tools-installer.exe for all-in-one installation
- Install drivers from virtio-win.iso mounted on Windows VM
- Reboot VM after driver installation
- Update Windows to latest patches for driver compatibility
- Ensure Windows Server 2016+ for full driver support

### Issue 8: Windows Activation Issues

**Symptoms:**
- Windows shows "Not Activated" after migration
- "Windows is not genuine" message
- Limited functionality due to activation

**Troubleshooting Steps:**
1. Check Windows activation status:
   ```powershell
   slmgr /dli
   ```

2. Check KMS client settings:
   ```powershell
   slmgr /ckms
   ```

**Solutions:**
- Update KMS server settings for new environment: slmgr /skms <kms-server>
- Reactivate Windows using MAK key: slmgr /ipk <product-key> && slmgr /ato
- Configure proxy settings if KMS requires it
- Use volume activation for Windows Server deployments
- Extend grace period if needed: slmgr /rearm

### Issue 9: Windows Guest Agent Issues

**Symptoms:**
- Guest agent not connected
- Cannot execute guest commands
- File system quiescing not working

**Troubleshooting Steps:**
1. Check guest agent service status:
   ```powershell
   Get-Service kubevirt-guest-agent
   ```

2. Check Windows Firewall:
   ```powershell
   netsh firewall show rule name=all
   ```

3. Test guest agent communication:
   ```powershell
   curl -v http://localhost:3905/health
   ```

**Solutions:**
- Ensure guest agent service is running: Start-Service kubevirt-guest-agent
- Configure Windows Firewall to allow guest agent communication on port 3905
- Restart guest agent service
- Reinstall guest agent if necessary from GitHub kubevirt releases
- Verify port 3905 availability

### Issue 10: Windows Version Compatibility

**Symptoms:**
- Migration fails for certain Windows versions
- Error message about unsupported OS
- Compatibility warnings in MTV

**Troubleshooting Steps:**
1. Check Windows version:
   ```powershell
   winver
   ```

2. Check system information:
   ```powershell
   Get-ComputerInfo
   ```

**Solutions:**
- Upgrade unsupported Windows versions:
  - Server 2008/2012 → Upgrade to Server 2016/2019/2022
  - Windows 7/8 → Upgrade to Windows 10/11
- Use Windows Server Migration Tools for in-place upgrades
- Use containerization approach for legacy Windows versions
- Consult Red Hat MTV compatibility matrix for supported versions

### Issue 11: Windows UEFI/BIOS Compatibility

**Symptoms:**
- Windows Server 2022 fails to boot
- "Boot configuration data" errors
- UEFI firmware issues

**Troubleshooting Steps:**
1. Check firmware type:
   ```bash
   oc get vm vm-name -n namespace -o yaml | grep firmware
   ```

2. Check Windows boot configuration:
   ```powershell
   bcdedit /enum all
   ```

**Solutions:**
- Convert VMware VM firmware from BIOS to UEFI before migration
- Use Windows Server 2022 with UEFI firmware (Gen 2)
- Enable Secure Boot if required
- Perform firmware conversion using VMware tools: vmkfstools -i disk.vmdk -O  --format raw
- Use virt-v2v for firmware conversion: virt-v2v -i vmx --os-variant win2k22

---

## Linux-Specific Issues

### Issue 7: Linux VM Boot Failures

**Symptoms:**
- Linux VM fails to boot after migration
- Kernel panic
- Boot loader issues

**Troubleshooting Steps:**
1. Check VM console:
   ```bash
   oc console vmi vm-name -n namespace
   ```

2. Check boot parameters:
   ```bash
   oc get vmi vm-name -n namespace -o yaml | grep kernelArgs
   ```

3. Check filesystem status:
   ```bash
   oc exec -it vm-name -n namespace -- fsck /dev/vda1
   ```

**Solutions:**
- Validate kernel compatibility
- Check bootloader configuration
- Repair filesystem issues
- Boot into rescue mode

### Issue 8: SELinux Issues

**Symptoms:**
- SELinux denies access
- Services fail to start
- Application errors

**Troubleshooting Steps:**
1. Check SELinux status:
   ```bash
   oc exec -it vm-name -n namespace -- getenforce
   ```

2. Check SELinux errors:
   ```bash
   oc exec -it vm-name -n namespace -- ausearch -m avc
   ```

3. Check SELinux context:
   ```bash
   oc exec -it vm-name -n namespace -- ls -Z /path/to/file
   ```

**Solutions:**
- Document and restore SELinux contexts
- Update SELinux policies
- Set SELinux to permissive temporarily
- Fix SELinux booleans

---

## Performance Issues

### Issue 9: Poor VM Performance

**Symptoms:**
- VM slow response times
- High CPU/memory utilization
- I/O bottlenecks

**Troubleshooting Steps:**
1. Check VM resource usage:
   ```bash
   oc exec -it vm-name -n namespace -- top
   oc exec -it vm-name -n namespace -- free -h
   ```

2. Check storage performance:
   ```bash
   oc exec -it vm-name -n namespace -- iostat -x 1
   ```

3. Check network performance:
   ```bash
   oc exec -it vm-name -n namespace -- iperf3 -c target-server
   ```

**Solutions:**
- Increase VM resource allocation
- Optimize storage I/O patterns
- Check network bandwidth
- Use appropriate storage class

### Issue 10: Slow Migration Speed

**Symptoms:**
- Migration taking longer than expected
- Network bandwidth saturated
- Storage I/O bottlenecks

**Troubleshooting Steps:**
1. Check migration progress:
   ```bash
   oc get migration migration-name -n openshift-mtv -w
   oc describe migration migration-name -n openshift-mtv
   ```

2. Monitor network bandwidth:
   ```bash
   oc exec -it mtv-controller-xxxxx -n openshift-mtv -- iperf3 -s
   ```

3. Check storage I/O:
   ```bash
   oc exec -it mtv-controller-xxxxx -n openshift-mtv -- iostat -x 1
   ```

**Solutions:**
- Throttle concurrent migrations
- Schedule migrations during off-hours
- Increase network bandwidth
- Use faster storage class

---

## Security Issues

### Issue 11: Authentication Failures

**Symptoms:**
- Cannot authenticate to vCenter
- Provider authentication fails
- Secret not accessible

**Troubleshooting Steps:**
1. Check secret status:
   ```bash
   oc get secret secret-name -n namespace
   oc describe secret secret-name -n namespace
   ```

2. Validate secret contents:
   ```bash
   oc get secret secret-name -n namespace -o yaml
   ```

3. Test authentication:
   ```bash
   curl -k -u username:password https://vcenter.example.com/sdk
   ```

**Solutions:**
- Recreate secrets
- Validate credentials
- Check RBAC permissions
- Verify secret access policies

### Issue 12: Network Policy Blocking Traffic

**Symptoms:**
- Cannot access VM ports
- Network traffic blocked
- Service discovery fails

**Troubleshooting Steps:**
1. Check network policies:
   ```bash
   oc get network-policy -A
   oc describe network-policy policy-name -n namespace
   ```

2. Test network connectivity:
   ```bash
   oc exec -it vm-name -n namespace -- nc -zv target-ip target-port
   ```

3. Check pod security:
   ```bash
   oc get pod -n namespace
   oc describe pod pod-name -n namespace
   ```

**Solutions:**
- Update network policies
- Add required ports to policies
- Check pod security contexts
- Verify security zones

---

## Special Case Issues

### Issue 13: Non-OS Disk Not Accessible

**Symptoms:**
- NAS/SAN/NFS disk not mounted
- LUN not visible in VM
- Data not accessible

**Troubleshooting Steps:**
1. Check PV/PVC status:
   ```bash
   oc get pv
   oc get pvc -A
   oc describe pvc pvc-name -n namespace
   ```

2. Check VM disk attachment:
   ```bash
   oc get vm vm-name -n namespace -o yaml | grep -A 10 volumes
   ```

3. Check VM disk visibility:
   ```bash
   oc exec -it vm-name -n namespace -- lsblk
   ```

**Solutions:**
- Verify PV/PVC configuration
- Check NAS/SAN network connectivity
- Validate LUN configuration
- Reattach disk to VM

### Issue 14: Warm Migration Synchronization Failures

**Symptoms:**
- Warm migration sync fails
- Data inconsistency
- Cutover fails

**Troubleshooting Steps:**
1. Check sync status:
   ```bash
   oc get migration migration-name -n openshift-mtv
   oc describe migration migration-name -n openshift-mtv
   ```

2. Check source VM status:
   ```bash
   govc vm.info vm-name
   ```

3. Check network connectivity:
   ```bash
   oc exec -it mtv-controller-xxxxx -n openshift-mtv -- ping vm-ip
   ```

**Solutions:**
- Verify source VM is running
- Check network stability
- Validate storage capacity
- Retry warm migration
- Check CBT (Changed Block Tracking) configuration

---

## Network Port Issues

### Issue 15: MTV Cannot Connect to vCenter

**Symptoms:**
- "Failed to connect to vCenter" error in MTV
- Authentication failures
- SSL/TLS certificate errors

**Troubleshooting Steps:**
1. Test vCenter connectivity:
   ```bash
   telnet vcenter.example.com 443
   ```

2. Test vCenter API:
   ```bash
   curl -k -u "username:password" https://vcenter.example.com/sdk
   ```

**Solutions:**
- Open firewall ports 443/8443 on vCenter
- Update MTV provider credentials
- Add vCenter CA certificate to OpenShift trust store
- Check vCenter service status
- Verify DNS resolution

### Issue 16: VM Network Port Access Issues

**Symptoms:**
- VM cannot access network ports
- Application connectivity failures
- Database connection timeouts

**Troubleshooting Steps:**
1. Test port connectivity:
   ```bash
   nc -zv <vm-ip> 80    # HTTP
   nc -zv <vm-ip> 443   # HTTPS
   nc -zv <vm-ip> 22    # SSH
   nc -zv <vm-ip> 3389  # RDP
   ```

**Solutions:**
- Update network policies to allow required ports
- Configure correct VLAN attachments
- Update firewall rules

### Issue 17: Database Connection Port Issues

**Symptoms:**
- Database servers cannot connect to databases
- Connection refused errors
- Timeout errors

**Troubleshooting Steps:**
1. Test database ports:
   ```bash
   nc -zv <db-ip> 5432   # PostgreSQL
   nc -zv <db-ip> 3306   # MySQL
   nc -zv <db-ip> 1433   # MS SQL
   ```

**Solutions:**
- Open database ports in network policies
- Configure firewall rules on database VMs
- Update database client connection strings

---

## Debugging Commands

### General Debugging

**OpenShift Cluster Status:**
```bash
oc get nodes
oc get clusteroperator
oc get clusterversion
```

**MTV Status:**
```bash
oc get all -n openshift-mtv
oc get migration -n openshift-mtv
oc get migrationplan -n openshift-mtv
```

**VM Status:**
```bash
oc get vm -A
oc get vmi -A
oc get vmi -n namespace -o yaml
```

### Network Debugging

**Network Configuration:**
```bash
oc get network-attachment-definition -A
oc get network-policy -A
oc describe network-attachment-definition name -n namespace
```

**Network Connectivity:**
```bash
oc exec -it vm-name -n namespace -- ping target-ip
oc exec -it vm-name -n namespace -- nc -zv target-ip target-port
oc rsh vmi vm-name -n namespace -- traceroute target-ip
```

### Storage Debugging

**Storage Status:**
```bash
oc get sc
oc get pv
oc get pvc -A
oc describe sc storage-class-name
```

**Storage Usage:**
```bash
oc exec -it vm-name -n namespace -- df -h
oc exec -it vm-name -n namespace -- lsblk
oc exec -it vm-name -n namespace -- mount
```

### Performance Debugging

**VM Performance:**
```bash
oc exec -it vm-name -n namespace -- top
oc exec -it vm-name -n namespace -- free -h
oc exec -it vm-name -n namespace -- iostat -x 1
```

**Migration Performance:**
```bash
oc get migration migration-name -n openshift-mtv -w
oc describe migration migration-name -n openshift-mtv
oc logs -f mtv-controller-xxxxx -n openshift-mtv
```

---

## Escalation Procedures

### When to Escalate

**Critical Issues:**
- Data loss or corruption
- Security breach
- Production outage > 1 hour
- Multiple concurrent failures

**Escalation Path:**
1. **Level 1:** Migration Engineer (15 minutes)
2. **Level 2:** Technical Lead (30 minutes)
3. **Level 3:** Solution Architect (1 hour)
4. **Level 4:** Executive Sponsor (2 hours)

### Escalation Template

```
ESCALATION REQUEST

Issue: [Brief description]
Impact: [Business impact]
Affected Systems: [System list]
Current Status: [Current status]
Actions Taken: [Actions already taken]
Time to Resolution: [Expected resolution time]

Requested Action: [Specific request]
```

---

## Additional RedHat-Specific Scenarios

### Issue 15: VDDK Image Pull Errors

**Symptoms:**
- Migration fails with VDDK image pull error
- Error message: "Failed to pull VDDK image"
- Conversion pod fails to start
- Image registry connectivity issues

**Detailed Issue Description:**
VDDK (Virtual Disk Development Kit) image pull errors occur when MTV cannot download or access the required VDDK image for VMware disk conversion. The VDDK image contains the VMware libraries needed to read VM disk data from vSphere storage systems. When this image cannot be pulled, the entire migration process fails because MTV cannot access VM disk data.

**Why VDDK Images Are Critical:**
- **VMware Disk Access**: VDDK images contain VMware libraries required to read VMDK files from vSphere
- **Format Conversion**: VDDK enables conversion of VMware disk formats to OpenShift-compatible formats
- **Storage Integration**: VDDK provides the interface to VMware vSphere storage backends
- **Migration Dependency**: Without VDDK, MTV cannot read or convert VMware VM disks

**Common Pull Failure Scenarios:**
1. **Registry Authentication Required**: The VDDK image is in a private registry requiring credentials
2. **Network Connectivity**: OpenShift cluster cannot reach the container registry
3. **Image Misconfiguration**: Incorrect image name, tag, or registry URL in provider settings
4. **Registry Unavailable**: Container registry is down or experiencing issues
5. **Proxy Issues**: Proxy configuration blocking registry access
6. **Disk Space**: Insufficient disk space on OpenShift nodes to pull the image
7. **Image Size**: VDDK images are large (several GB) causing download timeouts

**RedHat Documentation Reference:**
- [Resolving VDDK image pull errors](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/proc_resolving-vddk-image-pull-errors_troubleshooting-migration_mtv)

**Root Causes:**
- Image registry authentication required but not configured
- Network connectivity to image registry blocked
- Incorrect VDDK image name or tag
- Image registry unreachable or down
- Image pull secrets not configured
- Proxy configuration issues
- Image size too large for available disk space

**Troubleshooting Steps:**
1. **Check conversion pod status:**
   ```bash
   oc get pods -n openshift-mtv
   oc describe pod <conversion-pod-name> -n openshift-mtv
   oc logs <conversion-pod-name> -n openshift-mtv | grep -i "image"
   ```

2. **Verify VDDK image configuration:**
   ```bash
   oc get provider vsphere-provider -n openshift-mtv -o yaml
   oc describe provider vsphere-provider -n openshift-mtv
   ```

3. **Test image pull manually:**
   ```bash
   oc debug node/<node-name> -- chroot /host -- crictl pull quay.io/konveyor/forklift-vddk:latest
   ```

4. **Check image pull secrets:**
   ```bash
   oc get secrets -n openshift-mtv
   oc describe secret <registry-secret> -n openshift-mtv
   ```

5. **Verify registry connectivity:**
   ```bash
   oc exec -it <pod-name> -n openshift-mtv -- curl -v https://quay.io
   oc exec -it <pod-name> -n openshift-mtv -- ping quay.io
   ```

6. **Check node storage capacity:**
   ```bash
   oc describe nodes
   oc top nodes
   df -h # on nodes with oc debug
   ```

**Solutions:**
- **Configure image pull secrets:**
  ```bash
  oc create secret docker-registry registry-secret \
    --docker-server=quay.io \
    --docker-username=<username> \
    --docker-password=<password> \
    -n openshift-mtv
  ```

- **Update provider configuration with correct image:**
  ```yaml
  apiVersion: fork.konveyor.io/v1beta1
  kind: Provider
  metadata:
    name: vsphere-provider
    namespace: openshift-mtv
  spec:
    type: vsphere
    settings:
      vddk_init_image: quay.io/konveyor/forklift-vddk:latest
  ```

- **Configure proxy settings:**
  ```bash
  # Add proxy settings to provider or cluster configuration
  oc edit configmap mtv-config -n openshift-mtv
  # Add HTTP_PROXY, HTTPS_PROXY, NO_PROXY variables
  ```

- **Use alternative VDDK image:** Switch to different VDDK image or version
- **Pre-pull images on nodes:** Manually pull VDDK image on all nodes before migration
- **Check network policies:** Ensure network policies allow registry access
- **Verify registry availability:** Ensure image registry is accessible and operational

**Configuration Example:**
```yaml
# Provider with VDDK image configuration
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: vsphere-provider
  namespace: openshift-mtv
spec:
  type: vsphere
  secret:
    name: vcenter-credentials
  settings:
    vddk_init_image: quay.io/konveyor/forklift-vddk:latest
    url: "https://vcenter.example.com"
    skip_tls_verify: true
```

**Preventive Measures:**
- Pre-pull VDDK images on all nodes during cluster setup
- Configure image pull secrets for private registries
- Monitor registry connectivity and availability
- Use stable, tested VDDK image versions
- Implement image caching strategies
- Regular test image pull operations

---

### Issue 16: VDDK vSAN Errors

**Symptoms:**
- Migration fails with vSAN-specific errors
- Error message: "VDDK vSAN error" or "vSAN connectivity failed"
- Storage copy offload fails with vSAN issues
- VMs with vSAN storage fail to migrate

**Detailed Issue Description:**
VDDK vSAN errors occur when using VMware vSAN storage with storage copy offload or when migrating VMs that use vSAN datastores. vSAN (Virtual Storage Area Network) is VMware's distributed storage solution that combines local storage drives into a single shared storage cluster. VDDK requires specific compatibility and configuration to work with vSAN environments.

**Why vSAN Integration is Complex:**
- **Distributed Architecture**: vSAN uses distributed storage across multiple ESXi hosts
- **Storage Policies**: vSAN uses storage policies that define VM storage requirements
- **Direct Storage Access**: VDDK needs direct access to vSAN storage systems
- **vSAN API Requirements**: Specific vSAN API calls and permissions are required
- **Network Dependencies**: vSAN requires specific network configurations for storage traffic
- **Storage Copy Offload**: vSAN integration with storage copy offload requires additional configuration

**vSAN-Specific Migration Challenges:**
1. **vSAN Version Compatibility**: VDDK must be compatible with both vSphere and vSAN versions
2. **Storage Policy Conflicts**: vSAN storage policies may conflict with OpenShift storage requirements
3. **Network Connectivity**: vSAN storage network must be accessible from OpenShift
4. **Permission Requirements**: Special vSAN permissions needed for VDDK operations
5. **Storage Copy Offload**: vSAN storage copy offload requires specific vSAN configuration
6. **Multi-Hop Storage**: vSAN distributed architecture may require multi-hop storage access
7. **Performance Considerations**: vSAN performance characteristics affect migration speed

**RedHat Documentation Reference:**
- [Resolving VDDK vSAN errors](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/proc_resolving-vddk-vsan-errors_troubleshooting-migration_mtv)

**Root Causes:**
- vSAN version incompatibility with VDDK
- vSAN authentication configuration issues
- Network connectivity between vSAN and OpenShift
- vSAN storage policy restrictions
- Insufficient vSAN permissions
- vSAN API access restrictions
- Storage copy offload configuration issues with vSAN

**Troubleshooting Steps:**
1. **Check vCenter vSAN configuration:**
   ```bash
   # From vCenter or using govc
   govc datacenter.info
   govc datastore.info
   govc vsan.info
   ```

2. **Verify vCenter vSAN version compatibility:**
   ```bash
   govc about
   # Check vSAN version against VDDK compatibility matrix
   ```

3. **Test vSAN connectivity:**
   ```bash
   # Test network connectivity to vSAN
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- ping vcenter.example.com
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- telnet vcenter.example.com 443
   ```

4. **Review vCenter permissions:**
   ```bash
   # Check if MTV service account has vSAN permissions
   govc permissions.ls /<datacenter>/vsan
   ```

5. **Check storage copy offload configuration:**
   ```bash
   oc get provider vsphere-provider -n openshift-mtv -o yaml
   oc describe migrationplan <plan-name> -n openshift-mtv
   ```

6. **Review vSAN storage policies:**
   ```bash
   govc storage.policy.info
   govc vm.info <vm-name>
   ```

**Solutions:**
- **Update VDDK version:** Use VDDK version compatible with your vSAN version
- **Configure vSAN authentication:** Ensure proper vCenter credentials and vSAN-specific permissions
- **Disable storage copy offload:** If storage copy offload is causing issues, disable it
  ```yaml
  spec:
    settings:
      storage_copy_offload: false
  ```

- **Update vCenter permissions:** Grant required vSAN permissions to MTV service account
- **Check vSAN storage policy compatibility:** Ensure vSAN storage policies are compatible with migration
- **Use standard migration path:** If vSAN issues persist, use standard migration without storage copy offload
- **Verify network configuration:** Ensure proper network connectivity between OpenShift and vSAN

**Configuration Example:**
```yaml
# Provider with storage copy offload disabled for vSAN compatibility
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: vsphere-provider
  namespace: openshift-mtv
spec:
  type: vsphere
  secret:
    name: vcenter-credentials
  settings:
    vddk_init_image: quay.io/konveyor/forklift-vddk:latest
    url: "https://vcenter.example.com"
    skip_tls_verify: true
    # Disable storage copy offload for vSAN compatibility
    storage_copy_offload: false
```

**Preventive Measures:**
- Check VDDK and vSAN compatibility before migration
- Test migration with non-vSAN VMs first
- Ensure vCenter has appropriate vSAN permissions configured
- Monitor vSAN health and performance during migrations
- Have fallback migration strategies for vSAN environments
- Keep VDDK versions updated for latest vSAN support

---

## Storage Copy Offload Troubleshooting

### Issue 17: vSphere-ESXi Connectivity Issues

**Symptoms:**
- Storage copy offload fails with connectivity errors
- Error message: "Failed to connect to ESXi host"
- Migration stalls during storage copy
- SSH connection failures to ESXi

**Detailed Issue Description:**
Storage copy offload requires direct SSH connectivity from OpenShift to ESXi hosts. Connectivity issues can occur due to SSH configuration, firewall restrictions, network segmentation, or ESXi host access restrictions.

**RedHat Documentation Reference:**
- [vSphere-ESXi connectivity issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/vsphere-esxi-connectivity-issues_troubleshooting-storage-copy-offload_troubleshooting-migration_mtv)

**Root Causes:**
- SSH not enabled on ESXi hosts
- SSH service stopped or not responding on ESXi
- Firewall blocking SSH connections (port 22)
- Network segmentation preventing OpenShift to ESXi communication
- ESXi host access restrictions (allowlist/denylist)
- SSH key authentication issues
- Network connectivity issues between OpenShift and ESXi

**Troubleshooting Steps:**
1. **Test SSH connectivity to ESXi:**
   ```bash
   # From OpenShift worker node
   ssh root@esxi-host.example.com
   
   # From MTV controller pod
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- ssh root@esxi-host.example.com
   ```

2. **Check SSH service status on ESXi:**
   ```bash
   # From ESXi host
   esxcli network firewall ruleset list -r sshClient
   esxcli system ssh get
   ```

3. **Verify network connectivity:**
   ```bash
   ping esxi-host.example.com
   telnet esxi-host.example.com 22
   nc -zv esxi-host.example.com 22
   ```

4. **Check firewall rules on ESXi:**
   ```bash
   esxcli network firewall ruleset list
   esxcli network firewall ruleset allowedip -r sshClient
   ```

5. **Review storage copy offload configuration:**
   ```bash
   oc get migrationplan <plan-name> -n openshift-mtv -o yaml
   oc describe migrationplan <plan-name> -n openshift-mtv
   ```

**Solutions:**
- **Enable SSH on ESXi hosts:**
  ```bash
  # From ESXi host or vCenter
  esxcli system ssh enable
  esxcli network firewall ruleset set -e true -r sshClient
  ```

- **Configure SSH allowlist on ESXi:**
  ```bash
  # Allow SSH from OpenShift worker nodes
  esxcli network firewall ruleset allowedip add -r sshClient -a <openshift-worker-ip>/32
  ```

- **Configure network firewall rules:** Ensure firewalls between OpenShift and ESXi allow SSH (port 22)
- **Set up SSH key authentication:** Configure SSH keys for passwordless authentication
- **Review network segmentation:** Ensure proper network routing between OpenShift and ESXi
- **Check ESXi host access:** Ensure ESXi hosts are accessible from OpenShift network
- **Configure SSH timeout settings:** Adjust SSH timeout for stable connections

**Configuration Example:**
```yaml
# Migration plan with storage copy offload configuration
apiVersion: fork.konveyor.io/v1beta1
kind: MigrationPlan
metadata:
  name: migration-with-storage-copy-offload
  namespace: openshift-mtv
spec:
  migrations:
    - vm:
        id: "vm-123"
        name: "vm-name"
      storage_copy_offload:
        enabled: true
        # Optional: Configure SSH settings
        ssh_port: 22
        ssh_timeout: 30
```

**Preventive Measures:**
- Enable and test SSH connectivity before migrations
- Configure proper network routing and firewall rules
- Use SSH key authentication for security and reliability
- Monitor SSH service health on ESXi hosts
- Implement network monitoring between OpenShift and ESXi
- Document ESXi SSH configuration for reference

---

### Issue 18: OVA Connection Test Errors

**Symptoms:**
- OVA migration fails with connection test error
- Error message: "OVA connection test failed"
- Cannot access OVA source URL
- OVA import process fails

**Detailed Issue Description:**
OVA connection test errors occur when MTV cannot connect to the OVA source URL during the connection test phase. This can be due to network connectivity issues, URL accessibility problems, authentication requirements, or SSL/TLS certificate issues.

**RedHat Documentation Reference:**
- [Resolving OVA connection test errors](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/proc_resolving-ova-connection-test-errors_troubleshooting-migration_mtv)

**Root Causes:**
- OVA source URL not accessible from OpenShift
- Network connectivity issues to OVA source
- SSL/TLS certificate validation failures
- Authentication required for OVA access
- Proxy configuration issues
- DNS resolution failures
- Firewall blocking OVA access

**Troubleshooting Steps:**
1. **Test OVA URL accessibility:**
   ```bash
   # From MTV controller pod
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- curl -v <ova-url>
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- wget <ova-url>
   ```

2. **Check network connectivity:**
   ```bash
   ping <ova-host>
   telnet <ova-host> 443
   nslookup <ova-host>
   ```

3. **Verify SSL/TLS certificate:**
   ```bash
   openssl s_client -connect <ova-host>:443 -servername <ova-host>
   ```

4. **Check authentication requirements:**
   ```bash
   # Test with credentials if authentication is required
   curl -u username:password <ova-url>
   ```

5. **Review OVA provider configuration:**
   ```bash
   oc get provider <ova-provider> -n openshift-mtv -o yaml
   oc describe provider <ova-provider> -n openshift-mtv
   ```

6. **Test from OpenShift worker node:**
   ```bash
   oc debug node/<worker-node> -- chroot /host -- curl -v <ova-url>
   ```

**Solutions:**
- **Verify OVA URL accessibility:** Ensure the OVA source URL is accessible from OpenShift network
- **Configure network routing:** Ensure proper network routing to OVA source
- **Handle SSL/TLS certificates:** Add CA certificates to OpenShift trust store or disable SSL verification for testing
- **Configure authentication:** Add authentication credentials to OVA provider configuration
- **Set up proxy configuration:** Configure proxy if required to access OVA source
- **Check DNS resolution:** Ensure proper DNS configuration for OVA host
- **Configure firewall rules:** Ensure firewalls allow access to OVA source

**Configuration Example:**
```yaml
# OVA provider with SSL skip verification
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: ova-provider
  namespace: openshift-mtv
spec:
  type: ova
  settings:
    url: "https://ova-repository.example.com"
    skip_tls_verify: true
    # Optional: Authentication
    username: "ova-user"
    password: "ova-password"
```

**Preventive Measures:**
- Test OVA URL accessibility before migration
- Ensure proper network connectivity to OVA sources
- Handle SSL/TLS certificates appropriately
- Configure authentication for secure OVA sources
- Monitor OVA source availability
- Implement proper DNS and proxy configuration

---

### Issue 19: SSH Issues in Storage Copy Offload

**Symptoms:**
- Storage copy offload fails with SSH authentication errors
- Error message: "SSH authentication failed" or "SSH connection timeout"
- SSH key authentication not working
- SSH session hangs during storage copy

**Detailed Issue Description:**
SSH issues in storage copy offload occur when the SSH connection between OpenShift and ESXi hosts fails due to authentication problems, key misconfiguration, timeout settings, or SSH service issues.

**RedHat Documentation Reference:**
- [SSH issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/ssh-issues_troubleshooting-storage-copy-offload_troubleshooting-migration_mtv)

**Root Causes:**
- SSH key not configured or invalid
- SSH key permissions incorrect
- SSH service not running on ESXi
- SSH timeout too short for large transfers
- SSH key mismatch between OpenShift and ESXi
- SSH protocol version incompatibility
- SSH configuration restrictions

**Troubleshooting Steps:**
1. **Test SSH authentication:**
   ```bash
   # Manual SSH test
   ssh -v -i /path/to/private-key root@esxi-host.example.com
   ```

2. **Check SSH key configuration:**
   ```bash
   # From OpenShift
   oc get secrets -n openshift-mtv
   oc describe secret <ssh-key-secret> -n openshift-mtv
   ```

3. **Verify SSH service status:**
   ```bash
   # From ESXi host
   esxcli network firewall ruleset list -r sshServer
   esxcli system ssh get
   ```

4. **Check SSH key permissions:**
   ```bash
   # From OpenShift with oc debug
   ls -la /path/to/ssh-keys/
   chmod 600 /path/to/private-key
   ```

5. **Review SSH timeout settings:**
   ```bash
   oc get configmap mtv-config -n openshift-mtv -o yaml
   ```

6. **Test SSH from MTV controller pod:**
   ```bash
   oc exec -it <mtv-controller-pod> -n openshift-mtv -- ssh -v root@esxi-host.example.com
   ```

**Solutions:**
- **Configure SSH keys properly:**
  ```bash
  # Generate SSH key pair
  ssh-keygen -t rsa -b 4096 -f mtv-ssh-key
  
  # Copy public key to ESXi hosts
  ssh-copy-id -i mtv-ssh-key.pub root@esxi-host.example.com
  ```

- **Set up SSH key secret in OpenShift:**
  ```bash
  oc create secret generic ssh-keys \
    --from-file=private-key=mtv-ssh-key \
    --from-file=public-key=mtv-ssh-key.pub \
    -n openshift-mtv
  ```

- **Configure SSH timeout:**
  ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: mtv-config
    namespace: openshift-mtv
  data:
    ssh_timeout: "300"
    ssh_max_sessions: "10"
  ```

- **Enable SSH service on ESXi:**
  ```bash
  esxcli system ssh enable
  esxcli network firewall ruleset set -e true -r sshServer
  ```

- **Check SSH key permissions:** Ensure private key has 600 permissions
- **Update SSH protocol version:** Use SSH protocol 2
- **Configure SSH allowlist:** Allow SSH connections from OpenShift network

**Preventive Measures:**
- Test SSH connectivity before migrations
- Use SSH key authentication for security
- Monitor SSH service health on ESXi
- Configure appropriate SSH timeout settings
- Regularly rotate SSH keys
- Document SSH configuration for reference

---

### Issue 20: NetApp Issues in Storage Copy Offload

**Symptoms:**
- Storage copy offload fails with NetApp-specific errors
- Error message: "NetApp API connection failed" or "NetApp storage error"
- NetApp storage array connectivity issues
- Storage copy offload not working with NetApp storage

**Detailed Issue Description:**
NetApp issues in storage copy offload occur when using NetApp storage arrays with storage copy offload features. These can be due to NetApp API connectivity, authentication problems, storage configuration issues, or NetApp-specific feature incompatibility.

**RedHat Documentation Reference:**
- [NetApp issues](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/netapp-issues_troubleshooting-storage-copy-offload_troubleshooting-migration_mtv)

**Root Causes:**
- NetApp API authentication failures
- NetApp API connectivity issues
- NetApp storage configuration problems
- NetApp features not compatible with storage copy offload
- NetApp license restrictions
- NetApp API version incompatibility
- Network connectivity to NetApp storage

**Troubleshooting Steps:**
1. **Test NetApp API connectivity:**
   ```bash
   # Test NetAPI access
   curl -v -u admin:password https://netapp-fqdn/api/
   ```

2. **Check NetApp API authentication:**
   ```bash
   # Verify API credentials
   ssh admin@netapp-fqdn
   api show -vserver
   ```

3. **Review NetApp storage configuration:**
   ```bash
   # From NetApp CLI
   volume show
   lun show
   network interface show
   ```

4. **Check storage copy offload configuration:**
   ```bash
   oc get provider vsphere-provider -n openshift-mtv -o yaml
   oc describe migrationplan <plan-name> -n openshift-mtv
   ```

5. **Verify NetApp features:**
   ```bash
   # Check NetApp SnapMirror configuration
   snapmirror show
   # Check FlexClone configuration
   flexclone show
   ```

6. **Test network connectivity to NetApp:**
   ```bash
   ping netapp-fqdn
   telnet netapp-fqdn 443
   ```

**Solutions:**
- **Configure NetApp API authentication:**
  ```yaml
  apiVersion: fork.konveyor.io/v1beta1
  kind: Provider
  metadata:
    name: vsphere-provider
  namespace: openshift-mtv
  spec:
    type: vsphere
    settings:
      netapp_api_url: "https://netapp-fqdn/api"
      netapp_username: "admin"
      netapp_password: "password"
  ```

- **Enable required NetApp features:**
  ```bash
  # From NetApp CLI
  snapmirror on
  flexclone license add
  ```

- **Configure network connectivity:** Ensure proper network routing to NetApp storage
- **Check NetApp API version:** Use compatible API version with MTV
- **Verify NetApp storage configuration:** Ensure storage volumes are properly configured
- **Review NetApp licenses:** Ensure required licenses are active
- **Disable storage copy offload:** If NetApp issues persist, disable storage copy offload

**Configuration Example:**
```yaml
# Provider with NetApp storage copy offload configuration
apiVersion: fork.konveyor.io/v1beta1
kind: Provider
metadata:
  name: vsphere-provider
  namespace: openshift-mtv
spec:
  type: vsphere
  secret:
    name: vcenter-credentials
  settings:
    # NetApp specific configuration
    netapp_api_url: "https://netapp.example.com/api"
    netapp_username: "admin"
    netapp_password: "netapp-password"
    storage_copy_offload: true
    netapp_use_snapmirror: true
```

**Preventive Measures:**
- Test NetApp API connectivity before migrations
- Configure proper NetApp authentication
- Ensure NetApp features are compatible with storage copy offload
- Monitor NetApp storage health and performance
- Keep NetApp firmware and software updated
- Document NetApp configuration for reference

---

## Log Collection and Diagnostics

### Using Must-Gather Tool

The must-gather tool collects comprehensive diagnostic information from your MTV deployment for troubleshooting complex issues.

**RedHat Documentation Reference:**
- [Using the must-gather tool](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/using-the-must-gather-tool_troubleshooting-migration_mtv)

**Basic Usage:**
```bash
# Collect MTV must-gather data
oc adm must-gather --image=quay.io/konveyor/forklift-must-gather:latest \
  --dest-dir=/tmp/mtv-must-gather

# Collect must-gather with specific focus
oc adm must-gather --image=quay.io/konveyor/forklift-must-gather:latest \
  --dest-dir=/tmp/mtv-must-gather \
  /usr/bin/gather_kubevirt_resources
```

**Analyzing Collected Logs:**
```bash
cd /tmp/mtv-must-gather
# Review the collected logs and custom resources
# Logs are organized by namespace and resource type
```

**Must-Gather Output Structure:**
```
/tmp/mtv-must-gather/
├── namespaces/
│   ├── openshift-mtv/
│   │   ├── pods/
│   │   ├── events/
│   │   ├── configmaps/
│   │   └── secrets/
│   └── <target-namespaces>/
├── cluster-scoped-resources/
│   ├── providers/
│   ├── migrationplans/
│   └── storageclasses/
└── logs/
    ├── mtv-controller/
    └── conversion-hosts/
```

---

### Collecting Logs and Custom Resource Information

#### Downloading Logs from Web Console

**RedHat Documentation Reference:**
- [Downloading logs from web console](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/downloading-logs-web-console_troubleshooting-migration_mtv)

**Procedure:**
1. Navigate to the OpenShift web console
2. Go to the **Operators** → **Installed Operators** → **Migration Toolkit for Virtualization**
3. Click on the **MTV** operator
4. Navigate to the **MTV** namespace
5. Select the pod you want to troubleshoot
6. Click **Logs** to view pod logs
7. Use the download icon to save logs locally

#### Accessing Logs from Command Line

**RedHat Documentation Reference:**
- [Accessing logs from command line](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.11/html/migrating_your_virtual_machines_to_red_hat_openshift_virtualization/accessing-logs-command-line_troubleshooting-migration_mtv)

**MTV Controller Logs:**
```bash
# Get MTV controller pods
oc get pods -n openshift-mtv -l app=mtv-controller

# View controller logs
oc logs -f mtv-controller-<hash> -n openshift-mtv

# View previous controller logs
oc logs mtv-controller-<hash> -n openshift-mtv --previous=true
```

**Conversion Host Logs:**
```bash
# Get conversion host pods
oc get pods -n openshift-mtv -l app=conversion-host

# View conversion logs
oc logs -f conversion-host-<hash> -n openshift-mtv -c converter

# View virt-v2v logs
oc logs -f conversion-host-<hash> -n openshift-mtv -c virt-v2v
```

**Migration Resource Logs:**
```bash
# Get migration resources
oc get migration -n openshift-mtv

# View migration details
oc describe migration <migration-name> -n openshift-mtv

# View migration events
oc get events -n openshift-mtv --field-selector involvedObject.kind=Migration,involvedObject.name=<migration-name>
```

**Custom Resource Information:**
```bash
# Export provider configurations
oc get provider -n openshift-mtv -o yaml > provider-backup.yaml

# Export migration plans
oc get migrationplan -n openshift-mtv -o yaml > migrationplan-backup.yaml

# Export VM configurations
oc get vm -A -o yaml > vm-backup.yaml

# Export network attachment definitions
oc get network-attachment-definition -A -o yaml > nad-backup.yaml
```

**Event Collection:**
```bash
# Collect all MTV events
oc get events -n openshift-mtv --sort-by='.lastTimestamp' > mtv-events.txt

# Collect events for specific namespace
oc get events -n <target-namespace> --sort-by='.lastTimestamp' > namespace-events.txt

# Collect events for specific VM
oc get events -n <namespace> --field-selector involvedObject.name=<vm-name> > vm-events.txt
```

**System Diagnostic Commands:**
```bash
# Check node resource usage
oc top nodes
oc describe nodes

# Check pod resource usage
oc top pods -n openshift-mtv
oc describe pod <pod-name> -n openshift-mtv

# Check storage capacity
oc get sc
oc get pv
oc get pvc -A

# Check network status
oc get network-attachment-definition -A
oc get networkpolicy -A
```

**Log Aggregation Script:**
```bash
#!/bin/bash
# Comprehensive log collection script

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="/tmp/mtv-logs-$TIMESTAMP"
mkdir -p "$LOG_DIR"

# Collect MTV namespace logs
echo "Collecting MTV namespace logs..."
oc get pods -n openshift-mtv -o name | while read pod; do
  oc logs "$pod" -n openshift-mtv > "$LOG_DIR/${pod//\//-}.log" 2>&1
done

# Collect events
echo "Collecting events..."
oc get events -n openshift-mtv --sort-by='.lastTimestamp' > "$LOG_DIR/mtv-events.txt"

# Collect provider configurations
echo "Collecting provider configurations..."
oc get provider -n openshift-mtv -o yaml > "$LOG_DIR/providers.yaml"

# Collect migration plans
echo "Collecting migration plans..."
oc get migrationplan -n openshift-mtv -o yaml > "$LOG_DIR/migrationplans.yaml"

# Collect system information
echo "Collecting system information..."
oc get nodes -o yaml > "$LOG_DIR/nodes.yaml"
oc get sc -o yaml > "$LOG_DIR/storage-classes.yaml"

echo "Logs collected to: $LOG_DIR"
echo "Archive: tar -czf mtv-logs-$TIMESTAMP.tar.gz $LOG_DIR"
```

**Automated Log Collection Example:**
```bash
# Save the script above as collect-mtv-logs.sh
chmod +x collect-mtv-logs.sh

# Run the script
./collect-mtv-logs.sh

# Create archive
tar -czf mtv-diagnostic-logs.tar.gz /tmp/mtv-logs-*/
```

**Log Analysis Tips:**
- Look for error patterns in conversion host logs
- Check for network connectivity issues in controller logs
- Review storage provisioning errors in PVC events
- Analyze resource allocation failures in node descriptions
- Correlate timestamps across different logs for complex issues

**RedHat Support Information:**
When opening support cases, attach the following:
- Must-gather archive
- Specific log files showing errors
- Event logs for timeframes of failures
- Custom resource configurations
- Network and storage configurations

---

## Prevention Strategies

### Pre-Migration Prevention

**Validation Checklist:**
- Complete environment validation
- Test migration procedures in staging
- Validate network connectivity
- Verify storage capacity
- Test rollback procedures

**Monitoring Setup:**
- Configure alerting for critical metrics
- Set up log aggregation
- Implement dashboards
- Define escalation procedures

### In-Flight Monitoring

**Real-time Monitoring:**
- Migration progress tracking
- Resource utilization monitoring
- Network bandwidth monitoring
- Storage I/O monitoring

**Automated Checks:**
- Automated validation scripts
- Performance threshold checking
- Automated rollback triggers
- Notification system integration

---

## Contact Information

**Technical Support:**
- Migration Engineer: [contact]
- Technical Lead: [contact]
- Solution Architect: [contact]

**Emergency Contact:**
- On-call Engineer: [contact]
- Executive Sponsor: [contact]

---

**Document Status:** Complete  
**Next Review Date:** [TBD]  
**Approved By:** [Approver Name]  
**Approval Date:** [Date]