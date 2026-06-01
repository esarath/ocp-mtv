# Provider Configuration Files

This directory contains provider configuration for MTV migration.

## Files Overview

### Source Providers
- `vsphere-provider.yaml` - VMware vSphere/ESXi provider configuration
- `vsphere-provider-advanced.yaml` - Advanced vSphere provider with additional settings

### Target Providers
- `openshift-provider.yaml` - OpenShift Virtualization provider configuration
- `openshift-provider-advanced.yaml` - Advanced OpenShift provider with additional settings

## Provider Configuration Details

### vSphere Provider Configuration
- **Provider Type:** VMware vSphere
- **Authentication:** Username/password or token-based
- **Connection:** vCenter Server or individual ESXi hosts
- **Datacenter:** Target datacenter for VM discovery
- **Network:** Network mappings for VM network interfaces
- **Storage:** Storage mappings for VM disks

### OpenShift Provider Configuration
- **Provider Type:** OpenShift Virtualization
- **Authentication:** Service account token
- **Connection:** OpenShift API endpoint
- **Namespace:** Target namespace for migrated VMs
- **Network:** Network attachment definitions
- **Storage:** Storage classes for VM disks

## Application Instructions

1. **Review and Customize:** Update provider settings to match your environment
2. **Apply to OpenShift:** `oc apply -f config/providers/`
3. **Verify:** `oc get provider -n openshift-mtv`

## Provider Testing

Test provider connectivity:
```bash
# Test vSphere provider
oc get provider vsphere-provider -n openshift-mtv
oc describe provider vsphere-provider -n openshift-mtv

# Test OpenShift provider
oc get provider openshift-provider -n openshift-mtv
oc describe provider openshift-provider -n openshift-mtv
```

## RedHat Best Practices

1. Use dedicated service accounts for provider authentication
2. Implement proper timeout and retry settings
3. Configure appropriate resource limits
4. Enable debug logging for troubleshooting
5. Test provider connectivity before starting migrations
6. Monitor provider health during migration
7. Use provider-specific network and storage mappings