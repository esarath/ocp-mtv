# Migration Plan Templates and Examples

This directory contains migration plan templates for different migration scenarios.

## Files Overview

### Cold Migration Plans
- `cold-migration-template.yaml` - Cold migration plan template
- `cold-migration-web-server.yaml` - Example cold migration for web server
- `cold-migration-database.yaml` - Example cold migration for database server

### Warm Migration Plans
- `warm-migration-template.yaml` - Warm migration plan template
- `warm-migration-web-server.yaml` - Example warm migration for web server
- `warm-migration-database.yaml` - Example warm migration for database server

### Batch Migration Plans
- `batch-migration-template.yaml` - Batch migration plan template
- `batch-migration-production.yaml` - Example batch migration for production

## Migration Plan Structure

### Core Components
- **Provider Sources:** VMware vSphere provider
- **Provider Destinations:** OpenShift provider
- **Network Mappings:** Source to destination network mapping
- **Storage Mappings:** Source to destination storage mapping
- **VM Selection:** VMs to migrate with specific configurations

### Migration Types
- **Cold Migration:** VM powered off during migration
- **Warm Migration:** VM running during migration with cutover
- **Batch Migration:** Multiple VMs migrated together

## Application Instructions

1. **Review Templates:** Choose appropriate template for your migration type
2. **Customize:** Update VM names, network mappings, storage mappings
3. **Apply Migration Plan:** `oc apply -f config/migration-plans/`
4. **Monitor Migration:** `oc get migration -n openshift-mtv -w`

## Migration Plan Customization

### Required Customization
- VM name and ID from vCenter
- Network mappings (source network to destination network)
- Storage mappings (source datastore to destination storage class)
- Target namespace in OpenShift
- Target VM name (if different from source)

### Optional Customization
- Resource requests and limits
- CPU and memory specifications
- Disk size adjustments
- Network interface configurations
- Custom labels and annotations

## RedHat Best Practices

1. Test migration plans in non-production environment first
2. Start with single VM migrations before batch migrations
3. Use descriptive migration plan names
4. Document network and storage mappings
5. Monitor migration progress closely
6. Have rollback procedures ready
7. Validate migrated VMs before cutover
8. Keep migration plans in version control