#!/bin/bash

# VM Rollback Script
# This script rolls back a migrated VM from OpenShift

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/mtv-vm-rollback-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Pass/Fail reporting
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    log "PASS: $1"
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    log "FAIL: $1"
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    log "WARN: $1"
}

info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
    log "INFO: $1"
}

# Confirm action
confirm() {
    local MESSAGE=$1
    echo ""
    echo -e "${YELLOW}WARNING: This action cannot be undone!${NC}"
    echo "$MESSAGE"
    read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Rollback cancelled."
        exit 0
    fi
}

# Stop VM
stop_vm() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    if oc get vm "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        if oc get vmi "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
            info "Stopping VM: $VM_NAME"
            oc stop vm "$VM_NAME" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
            pass "VM stopped: $VM_NAME"
        else
            info "VM is already stopped: $VM_NAME"
        fi
    else
        warn "VM does not exist: $VM_NAME"
    fi
}

# Delete VM
delete_vm() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    if oc get vm "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        info "Deleting VM: $VM_NAME"
        oc delete vm "$VM_NAME" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
        pass "VM deleted: $VM_NAME"
    else
        warn "VM does not exist: $VM_NAME"
    fi
}

# Delete PVCs
delete_pvcs() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Deleting PVCs for VM: $VM_NAME"
    
    # Get PVCs associated with the VM
    local PVCS=$(oc get pvc -n "$NAMESPACE" -o jsonpath='{.items[?(@.metadata.annotations.mtv\.konveyor\.io/source-vm=="'$VM_NAME'")].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$PVCS" ]; then
        for PVC in $PVCS; do
            info "Deleting PVC: $PVC"
            oc delete pvc "$PVC" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
            pass "PVC deleted: $PVC"
        done
    else
        info "No PVCs found associated with VM: $VM_NAME"
    fi
}

# Delete DataVolumes
delete_datavolumes() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Deleting DataVolumes for VM: $VM_NAME"
    
    local DVS=$(oc get datavolume -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$DVS" ]; then
        for DV in $DVS; do
            if [[ "$DV" == *"$VM_NAME"* ]]; then
                info "Deleting DataVolume: $DV"
                oc delete datavolume "$DV" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
                pass "DataVolume deleted: $DV"
            fi
        done
    else
        info "No DataVolumes found for VM: $VM_NAME"
    fi
}

# Delete migration plan
delete_migration_plan() {
    local MIGRATION_NAME=$1
    
    if [ -n "$MIGRATION_NAME" ]; then
        if oc get migrationplan "$MIGRATION_NAME" -n openshift-mtv &> /dev/null; then
            info "Deleting migration plan: $MIGRATION_NAME"
            oc delete migrationplan "$MIGRATION_NAME" -n openshift-mtv >> "$LOG_FILE" 2>&1
            pass "Migration plan deleted: $MIGRATION_NAME"
        else
            warn "Migration plan does not exist: $MIGRATION_NAME"
        fi
    fi
}

# Restore source VM
restore_source_vm() {
    local VM_NAME=$1
    local RESTORE_SOURCE=$2
    
    if [ "$RESTORE_SOURCE" = true ]; then
        if command -v govc &> /dev/null; then
            info "Restoring source VM from vCenter: $VM_NAME"
            
            # Check if VM exists in vCenter
            if govc vm.info "$VM_NAME" &> /dev/null; then
                # Power on source VM if it was powered off
                local VM_POWER=$(govc vm.power "$VM_NAME" | grep "Powered" || echo "")
                if [[ "$VM_POWER" == *"off"* ]]; then
                    info "Powering on source VM: $VM_NAME"
                    govc vm.power -on "$VM_NAME" >> "$LOG_FILE" 2>&1
                    pass "Source VM powered on: $VM_NAME"
                else
                    info "Source VM is already running: $VM_NAME"
                fi
            else
                warn "Source VM not found in vCenter: $VM_NAME"
            fi
        else
            warn "govc not installed - cannot restore source VM"
        fi
    else
        info "Source VM restoration not requested"
    fi
}

# Verify rollback
verify_rollback() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Verifying rollback for VM: $VM_NAME"
    
    if oc get vm "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        fail "VM still exists after rollback: $VM_NAME"
        return 1
    else
        pass "VM successfully removed: $VM_NAME"
    fi
    
    # Check for orphaned PVCs
    local ORPHANED_PVCS=$(oc get pvc -n "$NAMESPACE" -o jsonpath='{.items[?(@.metadata.annotations.mtv\.konveyor\.io/source-vm=="'$VM_NAME'")].metadata.name}' 2>/dev/null || echo "")
    if [ -z "$ORPHANED_PVCS" ]; then
        pass "No orphaned PVCs found"
    else
        warn "Orphaned PVCs found: $ORPHANED_PVCS"
    fi
}

# Generate rollback report
generate_report() {
    local VM_NAME=$1
    local NAMESPACE=$2
    local REPORT_FILE="/tmp/mtv-rollback-report-$(date +%Y%m%d-%H%M%S).txt"
    
    info "Generating rollback report: $REPORT_FILE"
    
    cat > "$REPORT_FILE" << EOF
MTV VM Rollback Report
======================
Date: $(date)
VM Name: $VM_NAME
Namespace: $NAMESPACE
Rollback Log: $LOG_FILE

Rollback Actions:
- VM stopped and deleted
- PVCs deleted
- DataVolumes deleted
- Migration plan deleted (if specified)
- Source VM restored (if specified)

Verification:
- VM removed from OpenShift
- Orphaned resources checked

Notes:
- Review log file for detailed information
- Source VM restoration may require additional steps
- Monitor source VM after restoration

EOF
    pass "Rollback report generated: $REPORT_FILE"
}

# Main execution
main() {
    echo -e "${BLUE}=== MTV VM Rollback ===${NC}"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Parse arguments
    RESTORE_SOURCE=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --migration-name)
                MIGRATION_NAME="$2"
                shift 2
                ;;
            --restore-source)
                RESTORE_SOURCE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 --vm-name NAME --namespace NAMESPACE [--migration-name NAME] [--restore-source] [--force]"
                exit 1
                ;;
        esac
    done
    
    # Set defaults
    NAMESPACE="${NAMESPACE:-production}"
    
    # Validate arguments
    if [ -z "$VM_NAME" ]; then
        echo "Error: VM name is required"
        echo "Usage: $0 --vm-name NAME --namespace NAMESPACE [--migration-name NAME] [--restore-source] [--force]"
        exit 1
    fi
    
    # Confirm rollback
    if [ "$FORCE" != true ]; then
        confirm "This will rollback VM $VM_NAME from namespace $NAMESPACE. This action cannot be undone."
    fi
    
    # Execute rollback
    info "Starting rollback for VM: $VM_NAME"
    stop_vm "$VM_NAME" "$NAMESPACE"
    delete_vm "$VM_NAME" "$NAMESPACE"
    delete_pvcs "$VM_NAME" "$NAMESPACE"
    delete_datavolumes "$VM_NAME" "$NAMESPACE"
    delete_migration_plan "$MIGRATION_NAME"
    restore_source_vm "$VM_NAME" "$RESTORE_SOURCE"
    verify_rollback "$VM_NAME" "$NAMESPACE"
    generate_report "$VM_NAME" "$NAMESPACE"
    
    echo ""
    echo -e "${GREEN}=== VM Rollback Complete ===${NC}"
    echo "Review log file: $LOG_FILE"
}

# Run main function
main "$@"