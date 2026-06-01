# Rollback and Cleanup Procedures

This directory contains rollback and cleanup procedures for MTV migration.

## Files Overview

### Rollback Scripts
- `vm-rollback.sh` - VM rollback procedure to revert migration
- `migration-rollback.sh` - Migration plan rollback procedure
- `environment-rollback.sh` - Complete environment rollback

### Cleanup Scripts
- `cleanup-migration.sh` - Clean up migration artifacts
- `cleanup-vms.sh` - Clean up failed or test VMs
- `cleanup-resources.sh` - Clean up orphaned resources

## Rollback Scenarios

### VM Rollback
- Rollback single VM migration
- Rollback batch migration
- Partial rollback (specific VMs from batch)

### Migration Rollback
- Cancel active migration
- Revert completed migration
- Clean up failed migrations

### Environment Cleanup
- Clean up test resources
- Remove migration artifacts
 Reset MTV environment

## Rollback Procedures

### Before Rollback
1. Stop all running migrations
2. Document current state
3. Create backups of configurations
4. Notify stakeholders

### During Rollback
1. Delete migrated VMs
2. Clean up PVCs and PVs
3. Remove migration plans
4. Revert source VMs if needed

### After Rollback
1. Verify environment state
2. Update documentation
3. Notify stakeholders
4. Document lessons learned

## Application Instructions

1. **Review Rollback Plan:** Ensure rollback plan aligns with requirements
2. **Backup State:** Create backup of current configuration
3. **Execute Rollback:** Run appropriate rollback script
4. **Verify State:** Verify environment is in expected state
5. **Document Results:** Document rollback results

## Rollback Execution

### Rollback Single VM
```bash
chmod +x config/rollback/*.sh
./config/rollback/vm-rollback.sh --vm-name "web-server-01" --namespace "production"
```

### Rollback Migration
```bash
./config/rollback/migration-rollback.sh --migration-name "web-server-01-migration"
```

### Cleanup Resources
```bash
./config/rollback/cleanup-resources.sh --namespace "production"
```

## Safety Considerations

### Data Protection
- Verify data backup before rollback
- Ensure data integrity during rollback
- Test rollback procedures in non-production

### Service Impact
- Minimize service disruption
- Coordinate with business stakeholders
- Perform rollback during maintenance window

### Resource Cleanup
- Verify resource dependencies
- Clean up orphaned resources
- Monitor resource usage during rollback

## RedHat Best Practices

1. Always have rollback plans before migration
2. Test rollback procedures in non-production environment
3. Document all rollback procedures and results
4. Monitor rollback execution closely
5. Verify complete cleanup after rollback
6. Update documentation based on rollback experience
7. Use automated rollback procedures for consistency
8. Coordinate rollback with appropriate teams