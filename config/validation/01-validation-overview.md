# Validation Scripts and Pre-Flight Checks

This directory contains validation scripts and pre-flight check tools for MTV migration.

## Files Overview

### Pre-Flight Check Scripts
- `pre-flight-check.sh` - Comprehensive pre-flight validation script
- `vcenter-check.sh` - vCenter/ESXi connectivity check
- `openshift-check.sh` - OpenShift cluster check
- `network-check.sh` - Network connectivity validation
- `storage-check.sh` - Storage capacity and performance check

### VM-Specific Validation
- `vm-validation.sh` - VM readiness validation
- `windows-vm-check.sh` - Windows VM specific checks
- `linux-vm-check.sh` - Linux VM specific checks

## Pre-Flight Check Categories

### Infrastructure Checks
- vCenter/ESXi connectivity
- OpenShift cluster health
- Network connectivity
- Storage capacity and performance
- Resource availability

### Configuration Checks
- Network attachment definitions
- Storage classes
- Secrets and credentials
- Provider configuration
- RBAC permissions

### VM-Specific Checks
- VM power status
- VM tools status
- Snapshot status
- Disk consolidation
- Network adapter compatibility

## Application Instructions

1. **Run Pre-Flight Checks:** Execute scripts before starting migration
2. **Review Results:** Check all validation results pass
3. **Fix Issues:** Address any failed checks before proceeding
4. **Document Results:** Save validation results for audit trail

## Pre-Flight Check Execution

### Run All Checks
```bash
chmod +x config/validation/*.sh
./config/validation/pre-flight-check.sh
```

### Run Individual Checks
```bash
./config/validation/vcenter-check.sh
./config/validation/openshift-check.sh
./config/validation/network-check.sh
./config/validation/storage-check.sh
```

### Run VM-Specific Checks
```bash
./config/validation/vm-validation.sh --vm-name "web-server-01"
./config/validation/windows-vm-check.sh --vm-name "win-server-01"
./config/validation/linux-vm-check.sh --vm-name "linux-server-01"
```

## RedHat Best Practices

1. Always run pre-flight checks before migration
2. Document all validation results
3. Fix all critical issues before proceeding
4. Run checks in both source and target environments
5. Schedule regular pre-flight validation
6. Keep validation scripts updated with environment changes
7. Use automated checks for large-scale migrations
8. Maintain historical validation data for trend analysis