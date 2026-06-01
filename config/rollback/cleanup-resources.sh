#!/bin/bash

# Cleanup Resources Script
# This script cleans up orphaned resources and migration artifacts

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/mtv-cleanup-$(date +%Y%m%d-%H%M%S).log"

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
        echo "Cleanup cancelled."
        exit 0
    fi
}

# Cleanup failed migrations
cleanup_failed_migrations() {
    local NAMESPACE=$1
    
    info "Cleaning up failed migrations in namespace: $NAMESPACE"
    
    local FAILED_MIGRATIONS=$(oc get migration -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$FAILED_MIGRATIONS" ]; then
        for MIGRATION in $FAILED_MIGRATIONS; do
            info "Deleting failed migration: $MIGRATION"
            oc delete migration "$MIGRATION" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
            pass "Failed migration deleted: $MIGRATION"
        done
    else
        info "No failed migrations found"
    fi
}

# Cleanup orphaned PVCs
cleanup_orphaned_pvcs() {
    local NAMESPACE=$1
    
    info "Cleaning up orphaned PVCs in namespace: $NAMESPACE"
    
    # Find PVCs without associated VMs
    local ALL_PVCS=$(oc get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$ALL_PVCS" ]; then
        for PVC in $ALL_PVCS; do
            # Check if PVC is used by any VM
            local VM_USAGE=$(oc get pvc "$PVC" -n "$NAMESPACE" -o jsonpath='{.metadata.ownerReferences[*].name}' 2>/dev/null || echo "")
            
            if [ -z "$VM_USAGE" ]; then
                # Check if PVC is bound
                local PVC_STATUS=$(oc get pvc "$PVC" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
                
                if [ "$PVC_STATUS" = "Bound" ]; then
                    warn "Orphaned PVC found (bound but not used): $PVC"
                    read -p "Delete orphaned PVC $PVC? (yes/no): " DELETE_PVC
                    
                    if [ "$DELETE_PVC" = "yes" ]; then
                        oc delete pvc "$PVC" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
                        pass "Orphaned PVC deleted: $PVC"
                    fi
                fi
            fi
        done
    else
        info "No PVCs found in namespace"
    fi
}

# Cleanup orphaned DataVolumes
cleanup_orphaned_datavolumes() {
    local NAMESPACE=$1
    
    info "Cleaning up orphaned DataVolumes in namespace: $NAMESPACE"
    
    local ALL_DVS=$(oc get datavolume -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$ALL_DVS" ]; then
        for DV in $ALL_DVS; do
            local DV_STATUS=$(oc get datavolume "$DV" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
            
            if [ "$DV_STATUS" = "Failed" ] || [ "$DV_STATUS" = "Stopped" ]; then
                info "Deleting failed/stopped DataVolume: $DV"
                oc delete datavolume "$DV" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
                pass "DataVolume deleted: $DV"
            fi
        done
    else
        info "No DataVolumes found in namespace"
    fi
}

# Cleanup completed migration plans
cleanup_migration_plans() {
    local NAMESPACE=$1
    local DAYS_OLD=$2
    
    info "Cleaning up old migration plans in namespace: $NAMESPACE"
    
    if [ -n "$DAYS_OLD" ]; then
        local OLD_PLANS=$(oc get migrationplan -n "$NAMESPACE" -o jsonpath='{.items[?(@.metadata.creationTimestamp<"'$(date -d "$DAYS_OLD days ago" -u +%Y-%m-%dT%H:%M:%SZ)'")].metadata.name}' 2>/dev/null || echo "")
        
        if [ -n "$OLD_PLANS" ]; then
            for PLAN in $OLD_PLANS; do
                info "Deleting old migration plan: $PLAN"
                oc delete migrationplan "$PLAN" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
                pass "Old migration plan deleted: $PLAN"
            done
        else
            info "No old migration plans found"
        fi
    else
        info "Skipping migration plan cleanup (no age specified)"
    fi
}

# Cleanup test VMs
cleanup_test_vms() {
    local NAMESPACE=$1
    
    info "Cleaning up test VMs in namespace: $NAMESPACE"
    
    local TEST_VMS=$(oc get vm -n "$NAMESPACE" -l vm-type=test -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$TEST_VMS" ]; then
        for VM in $TEST_VMS; do
            info "Deleting test VM: $VM"
            oc stop vm "$VM" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1 || true
            oc delete vm "$VM" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
            pass "Test VM deleted: $VM"
        done
    else
        info "No test VMs found"
    fi
}

# Cleanup empty projects
cleanup_empty_projects() {
    info "Checking for empty projects"
    
    local ALL_PROJECTS=$(oc get projects -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    for PROJECT in $ALL_PROJECTS; do
        # Skip system projects
        if [[ "$PROJECT" =~ ^(openshift|kube|default)$ ]]; then
            continue
        fi
        
        # Check if project has any resources
        local RESOURCE_COUNT=$(oc get all -n "$PROJECT" 2>/dev/null | grep -c -v "NAME" || echo "0")
        
        if [ "$RESOURCE_COUNT" -eq 0 ]; then
            info "Empty project found: $PROJECT"
            read -p "Delete empty project $PROJECT? (yes/no): " DELETE_PROJECT
            
            if [ "$DELETE_PROJECT" = "yes" ]; then
                oc delete project "$PROJECT" >> "$LOG_FILE" 2>&1
                pass "Empty project deleted: $PROJECT"
            fi
        fi
    done
}

# Cleanup old logs
cleanup_old_logs() {
    local LOG_DIR=$1
    local DAYS_OLD=$2
    
    if [ -z "$LOG_DIR" ]; then
        LOG_DIR="/tmp"
    fi
    
    info "Cleaning up old logs from: $LOG_DIR"
    
    if [ -n "$DAYS_OLD" ]; then
        find "$LOG_DIR" -name "mtv-*.log" -type f -mtime +$DAYS_OLD -delete 2>/dev/null || true
        pass "Old logs cleaned up (older than $DAYS_OLD days)"
    else
        info "Skipping log cleanup (no age specified)"
    fi
}

# Generate cleanup report
generate_report() {
    local REPORT_FILE="/tmp/mtv-cleanup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    info "Generating cleanup report: $REPORT_FILE"
    
    cat > "$REPORT_FILE" << EOF
MTV Resource Cleanup Report
==========================
Date: $(date)
Cleanup Log: $LOG_FILE

Cleanup Actions:
- Failed migrations cleaned up
- Orphaned PVCs checked and cleaned
- Orphaned DataVolumes cleaned up
- Old migration plans cleaned up (if specified)
- Test VMs cleaned up
- Empty projects checked
- Old logs cleaned up (if specified)

Notes:
- Review log file for detailed information
- Some actions required confirmation
- Monitor environment after cleanup

Recommendations:
- Schedule regular cleanup operations
- Implement resource retention policies
- Monitor orphaned resource creation

EOF
    pass "Cleanup report generated: $REPORT_FILE"
}

# Main execution
main() {
    echo -e "${BLUE}=== MTV Resource Cleanup ===${NC}"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Parse arguments
    NAMESPACE="openshift-mtv"
    DAYS_OLD=""
    CLEANUP_ALL=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --days-old)
                DAYS_OLD="$2"
                shift 2
                ;;
            --cleanup-all)
                CLEANUP_ALL=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--namespace NAMESPACE] [--days-old DAYS] [--cleanup-all] [--force]"
                exit 1
                ;;
        esac
    done
    
    # Confirm cleanup
    if [ "$FORCE" != true ]; then
        confirm "This will clean up resources in namespace $NAMESPACE. Some actions will require confirmation."
    fi
    
    # Execute cleanup
    info "Starting resource cleanup"
    cleanup_failed_migrations "$NAMESPACE"
    cleanup_orphaned_pvcs "$NAMESPACE"
    cleanup_orphaned_datavolumes "$NAMESPACE"
    cleanup_migration_plans "$NAMESPACE" "$DAYS_OLD"
    cleanup_test_vms "$NAMESPACE"
    
    if [ "$CLEANUP_ALL" = true ]; then
        cleanup_empty_projects
        cleanup_old_logs "/tmp" "$DAYS_OLD"
    fi
    
    generate_report
    
    echo ""
    echo -e "${GREEN}=== Resource Cleanup Complete ===${NC}"
    echo "Review log file: $LOG_FILE"
}

# Run main function
main "$@"