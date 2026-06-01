#!/bin/bash

# MTV Pre-Flight Validation Script
# This script performs comprehensive pre-flight checks for MTV migration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/mtv-pre-flight-$(date +%Y%m%d-%H%M%S).log"

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

# Check command availability
check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# vCenter Connectivity Check
check_vcenter() {
    echo ""
    echo "=== vCenter Connectivity Check ==="
    
    # Check govc
    if check_command govc; then
        pass "govc is installed"
        govc version >> "$LOG_FILE" 2>&1
    else
        fail "govc is not installed"
        return 1
    fi
    
    # Check vCenter connectivity
    if [ -n "$GOVC_URL" ] && [ -n "$GOVC_USERNAME" ] && [ -n "$GOVC_PASSWORD" ]; then
        if govc about &> /dev/null; then
            pass "vCenter connectivity successful"
            govc about >> "$LOG_FILE" 2>&1
        else
            fail "vCenter connectivity failed"
            return 1
        fi
    else
        warn "vCenter credentials not set in environment variables"
    fi
    
    return 0
}

# OpenShift Cluster Check
check_openshift() {
    echo ""
    echo "=== OpenShift Cluster Check ==="
    
    # Check oc
    if check_command oc; then
        pass "oc is installed"
        oc version >> "$LOG_FILE" 2>&1
    else
        fail "oc is not installed"
        return 1
    fi
    
    # Check OpenShift connectivity
    if oc whoami &> /dev/null; then
        pass "OpenShift connectivity successful"
        oc whoami >> "$LOG_FILE" 2>&1
    else
        fail "OpenShift connectivity failed - not logged in"
        return 1
    fi
    
    # Check cluster health
    if oc get nodes &> /dev/null; then
        pass "OpenShift cluster is accessible"
        local NODE_COUNT=$(oc get nodes | grep -c "Ready")
        info "Ready nodes: $NODE_COUNT"
        
        # Check for not-ready nodes
        local NOT_READY=$(oc get nodes | grep -c "NotReady" || true)
        if [ "$NOT_READY" -gt 0 ]; then
            warn "$NOT_READY nodes are not ready"
        fi
    else
        fail "Cannot get OpenShift nodes"
        return 1
    fi
    
    # Check MTV namespace
    if oc get namespace openshift-mtv &> /dev/null; then
        pass "openshift-mtv namespace exists"
    else
        warn "openshift-mtv namespace does not exist"
    fi
    
    return 0
}

# Network Configuration Check
check_network() {
    echo ""
    echo "=== Network Configuration Check ==="
    
    # Check network attachment definitions
    if oc get network-attachment-definition -n openshift-mtv &> /dev/null; then
        local NAD_COUNT=$(oc get network-attachment-definition -n openshift-mtv | grep -c -v "NAME" || echo "0")
        if [ "$NAD_COUNT" -gt 0 ]; then
            pass "Network attachment definitions exist ($NAD_COUNT found)"
            oc get network-attachment-definition -n openshift-mtv >> "$LOG_FILE" 2>&1
        else
            fail "No network attachment definitions found"
            return 1
        fi
    else
        fail "Cannot get network attachment definitions"
        return 1
    fi
    
    # Test network connectivity
    if check_command ping; then
        if ping -c 1 8.8.8.8 &> /dev/null; then
            pass "Internet connectivity available"
        else
            warn "Internet connectivity not available (may be expected)"
        fi
    fi
    
    return 0
}

# Storage Configuration Check
check_storage() {
    echo ""
    echo "=== Storage Configuration Check ==="
    
    # Check storage classes
    if oc get sc &> /dev/null; then
        local SC_COUNT=$(oc get sc | grep -c -v "NAME" || echo "0")
        if [ "$SC_COUNT" -gt 0 ]; then
            pass "Storage classes exist ($SC_COUNT found)"
            oc get sc >> "$LOG_FILE" 2>&1
            
            # Check for default storage class
            local DEFAULT_SC=$(oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
            if [ -n "$DEFAULT_SC" ]; then
                info "Default storage class: $DEFAULT_SC"
            else
                warn "No default storage class configured"
            fi
        else
            fail "No storage classes found"
            return 1
        fi
    else
        fail "Cannot get storage classes"
        return 1
    fi
    
    # Check storage capacity
    local SC_DEFAULT=$(oc get sc -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$SC_DEFAULT" ]; then
        info "Storage capacity check not fully implemented - requires PVC creation"
    fi
    
    return 0
}

# Secrets Check
check_secrets() {
    echo ""
    echo "=== Secrets Check ==="
    
    # Check vCenter credentials
    if oc get secret vcenter-credentials -n openshift-mtv &> /dev/null; then
        pass "vCenter credentials secret exists"
    else
        fail "vCenter credentials secret does not exist"
        return 1
    fi
    
    # Check OpenShift credentials
    if oc get secret openshift-credentials -n openshift-mtv &> /dev/null; then
        pass "OpenShift credentials secret exists"
    else
        fail "OpenShift credentials secret does not exist"
        return 1
    fi
    
    return 0
}

# Provider Configuration Check
check_providers() {
    echo ""
    echo "=== Provider Configuration Check ==="
    
    # Check vSphere provider
    if oc get provider vsphere-provider -n openshift-mtv &> /dev/null; then
        pass "vSphere provider exists"
        oc get provider vsphere-provider -n openshift-mtv >> "$LOG_FILE" 2>&1
    else
        fail "vSphere provider does not exist"
        return 1
    fi
    
    # Check OpenShift provider
    if oc get provider openshift-provider -n openshift-mtv &> /dev/null; then
        pass "OpenShift provider exists"
        oc get provider openshift-provider -n openshift-mtv >> "$LOG_FILE" 2>&1
    else
        fail "OpenShift provider does not exist"
        return 1
    fi
    
    return 0
}

# VM Specific Checks
check_vm() {
    local VM_NAME=$1
    
    echo ""
    echo "=== VM Specific Check: $VM_NAME ==="
    
    if [ -z "$VM_NAME" ]; then
        warn "No VM name specified, skipping VM checks"
        return 0
    fi
    
    # Check VM exists in vCenter
    if govc vm.info "$VM_NAME" &> /dev/null; then
        pass "VM exists in vCenter: $VM_NAME"
        govc vm.info "$VM_NAME" >> "$LOG_FILE" 2>&1
    else
        fail "VM does not exist in vCenter: $VM_NAME"
        return 1
    fi
    
    # Check VM power status
    local VM_POWER=$(govc vm.power "$VM_NAME" | grep "Power" || echo "Unknown")
    info "VM power status: $VM_POWER"
    
    # Check for snapshots
    if govc snapshot.tree "$VM_NAME" &> /dev/null; then
        local SNAPSHOTS=$(govc snapshot.tree "$VM_NAME" | grep -c "•" || echo "0")
        if [ "$SNAPSHOTS" -gt 0 ]; then
            warn "VM has $SNAPSHOTS snapshot(s) - consider removing before migration"
        else
            pass "VM has no snapshots"
        fi
    fi
    
    return 0
}

# Resource Availability Check
check_resources() {
    echo ""
    echo "=== Resource Availability Check ==="
    
    # Check node resources
    if oc get nodes &> /dev/null; then
        local TOTAL_CPU=$(oc get nodes -o jsonpath='{.items[*].status.capacity.cpu}' | tr ' ' '+' | bc)
        local TOTAL_MEM=$(oc get nodes -o jsonpath='{.items[*].status.capacity.memory}')
        
        info "Total cluster CPU: $TOTAL_CPU cores"
        info "Total cluster memory: $TOTAL_MEM"
        
        # Check allocatable resources
        local ALLOCATABLE_CPU=$(oc get nodes -o jsonpath='{.items[*].status.allocatable.cpu}' | tr ' ' '+' | bc)
        info "Allocatable CPU: $ALLOCATABLE_CPU cores"
    fi
    
    return 0
}

# Main execution
main() {
    echo -e "${BLUE}=== MTV Pre-Flight Validation ===${NC}"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            --skip-vcenter)
                SKIP_VCENTER=true
                shift
                ;;
            --skip-openshift)
                SKIP_OPENSHIFT=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--vm-name NAME] [--skip-vcenter] [--skip-openshift]"
                exit 1
                ;;
        esac
    done
    
    # Run checks
    local TOTAL_CHECKS=0
    local PASSED_CHECKS=0
    local FAILED_CHECKS=0
    
    # vCenter check
    if [ "$SKIP_VCENTER" != true ]; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if check_vcenter; then
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
    
    # OpenShift check
    if [ "$SKIP_OPENSHIFT" != true ]; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if check_openshift; then
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
    
    # Infrastructure checks
    for check in network storage secrets providers resources; do
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if check_$check; then
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done
    
    # VM specific check
    if [ -n "$VM_NAME" ]; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if check_vm "$VM_NAME"; then
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
        echo "Please fix the failed checks before proceeding with migration."
        exit 1
    else
        echo -e "${GREEN}=== VALIDATION PASSED ===${NC}"
        echo "Environment is ready for migration."
        exit 0
    fi
}

# Run main function
main "$@"