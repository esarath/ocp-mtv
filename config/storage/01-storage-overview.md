# Storage Configuration Files

This directory contains storage configuration for OpenShift Virtualization migrations.

## Files Overview

### Storage Classes
- `storage-class-ssd.yaml` - High-performance SSD storage class
- `storage-class-hdd.yaml` - Standard HDD storage class
- `storage-class-nfs.yaml` - NFS storage class for shared storage

### Example Persistent Volume Claims
- `pvc-web-server-example.yaml` - Example PVC for web server VM
- `pvc-database-server-example.yaml` - Example PVC for database server VM
- `pvc-app-server-example.yaml` - Example PVC for application server VM

### DataVolume Templates
- `datavolume-template.yaml` - DataVolume template for VM migration

## Storage Configuration Details

### SSD Storage Class
- **Purpose:** High-performance VM storage
- **Provisioner:** csi-driver.example.com
- **Performance:** High IOPS, low latency
- **Use Case:** Database servers, high-performance applications

### HDD Storage Class
- **Purpose:** Standard VM storage
- **Provisioner:** csi-driver.example.com
- **Performance:** Standard IOPS, cost-effective
- **Use Case:** Web servers, development VMs

### NFS Storage Class
- **Purpose:** Shared storage for multiple VMs
- **Provisioner:** nfs.csi.k8s.io
- **Performance:** Moderate, shared access
- **Use Case:** File servers, shared data VMs

## Application Instructions

1. **Review and Customize:** Update provisioner, parameters, and reclaim policy to match your environment
2. **Apply to OpenShift:** `oc apply -f config/storage/`
3. **Verify:** `oc get sc` and `oc get pvc -A`

## Storage Capacity Planning

Calculate required storage capacity:
- Sum of all VM disk sizes
- 20% overhead for migration processing
- 10% growth capacity
- Snapshots and backup space

## RedHat Best Practices

1. Use separate storage classes for different performance requirements
2. Implement storage policies for data protection
3. Configure proper reclaim policies based on data criticality
4. Monitor storage performance during migration
5. Test storage performance before production migration
6. Ensure sufficient storage capacity before starting migrations