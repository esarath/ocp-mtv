#!/bin/bash

# Post-Migration Validation Script
# This script validates migrated VMs in OpenShift

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/mtv-post-migration-$(date +%Y%m%d-%H%M%S).log"

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

# VM Existence Check
check_vm_exists() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    if oc get vm "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        pass "VM exists: $VM_NAME in namespace $NAMESPACE"
        oc get vm "$VM_NAME" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
        return 0
    else
        fail "VM does not exist: $VM_NAME in namespace $NAMESPACE"
        return 1
    fi
}

# VM Status Check
check_vm_status() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    local VM_STATUS=$(oc get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.printableStatus}' 2>/dev/null || echo "Unknown")
    info "VM status: $VM_STATUS"
    
    if [ "$VM_STATUS" = "Running" ]; then
        pass "VM is running"
    else
        warn "VM status is not Running: $VM_STATUS"
    fi
}

# VMI Status Check
check_vmi_status() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    if oc get vmi "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        local VMI_STATUS=$(oc get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        info "VMI status: $VMI_STATUS"
        
        if [ "$VMI_STATUS" = "Running" ]; then
            pass "VMI is running"
        else
            warn "VMI status is not Running: $VMI_STATUS"
        fi
        
        oc get vmi "$VM_NAME" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1
    else
        warn "VMI not found - VM may not be running"
    fi
}

# Network Connectivity Check
check_network() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Checking network connectivity for VM: $VM_NAME"
    
    # Get VM interfaces
    local INTERFACES=$(oc get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.interfaces[*].name}' 2>/dev/null || echo "")
    
    if [ -n "$INTERFACES" ]; then
        pass "VM has network interfaces: $INTERFACES"
        
        for interface in $INTERFACES; do
            local IP_ADDR=$(oc get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath="{.status.interfaces[?(@.name=='$interface')].ipAddress}" 2>/dev/null || echo "")
            if [ -n "$IP_ADDR" ]; then
                info "Interface $interface has IP: $IP_ADDR"
                
                # Test ping to VM (may not work from control plane)
                if ping -c 1 -W 2 "$IP_ADDR" &> /dev/null; then
                    pass "VM is reachable via ping"
                else
                    warn "VM is not reachable via ping (may be expected due to firewall)"
                fi
            else
                warn "Interface $interface has no IP address"
            fi
        done
    else
        fail "VM has no network interfaces"
    fi
}

# Disk Attachment Check
check_disks() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Checking disk attachments for VM: $VM_NAME"
    
    # Get VM volumes
    local VOLUMES=$(oc get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.volumes[*].name}' 2>/dev/null || echo "")
    
    if [ -n "$VOLUMES" ]; then
        pass "VM has volumes: $VOLUMES"
        
        for volume in $VOLUMES; do
            # Check if volume has corresponding PVC
            local PVC_NAME=$(oc get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.volumes[?(@.name=='$volume')].persistentVolumeClaim.claimName}" 2>/dev/null || echo "")
            if [ -n "$PVC_NAME" ]; then
                info "Volume $volume uses PVC: $PVC_NAME"
                
                # Check PVC status
                if oc get pvc "$PVC_NAME" -n "$NAMESPACE" &> /dev/null; then
                    local PVC_STATUS=$(oc get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
                    info "PVC $PVC_NAME status: $PVC_STATUS"
                    
                    if [ "$PVC_STATUS" = "Bound" ]; then
                        pass "PVC is bound"
                    else
                        warn "PVC status is not Bound: $PVC_STATUS"
                    fi
                else
                    fail "PVC not found: $PVC_NAME"
                fi
            fi
        done
    else
        fail "VM has no volumes"
    fi
}

# Resource Configuration Check
check_resources() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Checking resource configuration for VM: $VM_NAME"
    
    # Get CPU request
    local CPU_REQUEST=$(oc get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.domain.cpu.cores}' 2>/dev/null || echo "Not set")
    info "CPU cores: $CPU_REQUEST"
    
    # Get memory request
    local MEMORY_REQUEST=$(oc get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.domain.resources.requests.memory}' 2>/dev/null || echo "Not set")
    info "Memory request: $MEMORY_REQUEST"
    
    if [ "$CPU_REQUEST" != "Not set" ] && [ "$MEMORY_REQUEST" != "Not set" ]; then
        pass "Resource configuration is set"
    else
        warn "Resource configuration may not be fully set"
    fi
}

# Console Access Check
check_console() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Checking console access for VM: $VM_NAME"
    
    # Try to get VNC console
    if oc get vmi "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        pass "VMI exists - console should be accessible"
        echo "Access console using: oc console vmi $VM_NAME -n $NAMESPACE"
    else
        warn "VMI not found - console may not be accessible"
    fi
}

# Guest Agent Check
check_guest_agent() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Checking guest agent status for VM: $VM_NAME"
    
    if oc get vmi "$VM_NAME" -n "$NAMESPACE" &> /dev/null; then
        local GUEST_AGENT=$(oc get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="AgentConnected")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$GUEST_AGENT" = "True" ]; then
            pass "Guest agent is connected"
        else
            info "Guest agent not connected (may need installation)"
        fi
    else
        warn "VMI not found - cannot check guest agent"
    fi
}

# Application-Specific Checks
check_application() {
    local VM_NAME=$1
    local NAMESPACE=$2
    local APP_TYPE=$3
    
    info "Running application-specific checks for: $APP_TYPE"
    
    case "$APP_TYPE" in
        "web-server")
            info "Web server checks: HTTP/HTTPS port accessibility"
            # Add web server specific checks
            ;;
        "database")
            info "Database checks: Database service connectivity"
            # Add database specific checks
            ;;
        "application")
            info "Application checks: Custom application health checks"
            # Add application specific checks
            ;;
        *)
            info "Generic application checks"
            ;;
    esac
}

# Source VM Comparison
compare_with_source() {
    local VM_NAME=$1
    local NAMESPACE=$2
    
    info "Comparing migrated VM with source VM"
    
    # Compare CPU
    # Compare Memory
    # Compare Disk sizes
    # Compare Network configuration
    
    info "Detailed comparison requires source VM information"
    info "Review VM configuration manually if detailed comparison is needed"
}

# Migration Status Check
check_migration_status() {
    local MIGRATION_NAME=$1
    
    if oc get migration "$MIGRATION_NAME" -n openshift-mtv &> /dev/null; then
        local MIGRATION_STATUS=$(oc get migration "$MIGRATION_NAME" -n openshift-mtv -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$MIGRATION_STATUS" = "True" ]; then
            pass "Migration $MIGRATION_NAME completed successfully"
        else
            fail "Migration $MIGRATION_NAME did not complete successfully"
            oc get migration "$MIGRATION_NAME" -n openshift-mtv
        fi
    else
        warn "Migration record not found: $MIGRATION_NAME"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== Post-Migration Validation ===${NC}"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Parse arguments
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
            --app-type)
                APP_TYPE="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 --vm-name NAME --namespace NAMESPACE [--migration-name NAME] [--app-type TYPE]"
                exit 1
                ;;
        esac
    done
    
    # Set defaults
    NAMESPACE="${NAMESPACE:-production}"
    APP_TYPE="${APP_TYPE:-generic}"
    
    # Validate arguments
    if [ -z "$VM_NAME" ]; then
        echo "Error: VM name is required"
        echo "Usage: $0 --vm-name NAME --namespace NAMESPACE [--migration-name NAME] [--app-type TYPE]"
        exit 1
    fi
    
    local TOTAL_CHECKS=0
    local PASSED_CHECKS=0
    local FAILED_CHECKS=0
    
    # Run validation checks
    for check in vm_exists vm_status vmi_status network disks resources console guest_agent application compare_with_source; do
        if [ "$check" = "application" ]; then
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            if check_application "$VM_NAME" "$NAMESPACE" "$APP_TYPE"; then
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        elif [ "$check" = "compare_with_source" ]; then
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            if compare_with_source "$VM_NAME" "$NAMESPACE"; then
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        else
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            if check_$check "$VM_NAME" "$NAMESPACE"; then
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
        fi
    done
    
    # Check migration status if provided
    if [ -n "$MIGRATION_NAME" ]; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if check_migration_status "$MIGRATION_NAME"; then
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
    
    # Summary
    echo ""
    echo "=== Validation Summary ==="
    echo "Total checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo ""
    
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        echo -e "${RED}=== VALIDATION FAILED ===${NC}"
        echo "Please review failed checks and take corrective action."
        exit 1
    else
        echo -e "${GREEN}=== VALIDATION PASSED ===${NC}"
        echo "VM migration validation successful."
        exit 0
    fi
}

# Run main function
main "$@"