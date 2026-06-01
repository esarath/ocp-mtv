#!/bin/bash

# Storage Configuration Check Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Storage Configuration Check ==="

# Check Storage Classes
if oc get sc &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: Storage classes exist"
    
    local SC_COUNT=$(oc get sc | grep -c -v "NAME" || echo "0")
    echo "Total storage classes: $SC_COUNT"
    
    oc get sc
else
    echo -e "${RED}✗ FAIL${NC}: No storage classes found"
    echo "Create storage classes before proceeding"
    exit 1
fi

# Check for default storage class
echo ""
echo "=== Default Storage Class ==="
local DEFAULT_SC=$(oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null)
if [ -n "$DEFAULT_SC" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Default storage class configured"
    echo "Default storage class: $DEFAULT_SC"
else
    echo -e "${YELLOW}⚠ WARN${NC}: No default storage class configured"
    echo "Consider setting a default storage class"
fi

# Check storage class details
echo ""
echo "=== Storage Class Details ==="
oc get sc -o name | while read -r SC; do
    local SC_NAME=$(echo "$SC" | cut -d'/' -f2)
    echo "Checking: $SC_NAME"
    
    local PROVISIONER=$(oc get sc "$SC_NAME" -o jsonpath='{.provisioner}')
    local RECLAIM_POLICY=$(oc get sc "$SC_NAME" -o jsonpath='{.reclaimPolicy}')
    local VOLUME_BINDING_MODE=$(oc get sc "$SC_NAME" -o jsonpath='{.volumeBindingMode}')
    
    echo "  Provisioner: $PROVISIONER"
    echo "  Reclaim Policy: $RECLAIM_POLICY"
    echo "  Volume Binding Mode: $VOLUME_BINDING_MODE"
    
    # Check if storage class allows volume expansion
    local ALLOW_EXPANSION=$(oc get sc "$SC_NAME" -o jsonpath='{.allowVolumeExpansion}')
    if [ "$ALLOW_EXPANSION" = "true" ]; then
        echo "  Volume Expansion: Supported ✓"
    else
        echo "  Volume Expansion: Not supported"
    fi
done

# Check Persistent Volume Claims in MTV namespace
echo ""
echo "=== Existing Persistent Volume Claims ==="
if oc get pvc -n openshift-mtv &> /dev/null; then
    local PVC_COUNT=$(oc get pvc -n openshift-mtv | grep -c -v "NAME" || echo "0")
    if [ "$PVC_COUNT" -gt 0 ]; then
        echo "Existing PVCs in openshift-mtv: $PVC_COUNT"
        oc get pvc -n openshift-mtv
    else
        echo "No PVCs found in openshift-mtv namespace"
    fi
else
    echo "No PVCs found in openshift-mtv namespace"
fi

# Check storage capacity
echo ""
echo "=== Storage Capacity ==="

# Check available storage on each node
if oc get nodes &> /dev/null; then
    echo "Storage capacity by node:"
    oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.ephemeral-storage}{"\n"}{end}' 2>/dev/null || echo "Ephemeral storage information not available"
fi

# Check Persistent Volumes
echo ""
echo "=== Persistent Volumes ==="
if oc get pv &> /dev/null; then
    local PV_COUNT=$(oc get pv | grep -c -v "NAME" || echo "0")
    echo "Total persistent volumes: $PV_COUNT"
    
    local AVAILABLE_PV=$(oc get pv | grep -c "Available" || echo "0")
    local BOUND_PV=$(oc get pv | grep -c "Bound" || echo "0")
    
    echo "Available: $AVAILABLE_PV"
    echo "Bound: $BOUND_PV"
else
    echo "No persistent volumes found"
fi

# Check CSI drivers
echo ""
echo "=== CSI Drivers ==="
if oc get csidriver &> /dev/null; then
    local CSI_COUNT=$(oc get csidriver | grep -c -v "NAME" || echo "0")
    echo "CSI drivers: $CSI_COUNT"
    oc get csidriver
else
    echo "No CSI drivers found"
fi

# Check storage performance (requires test PVC creation)
echo ""
echo "=== Storage Performance Check ==="
echo "Storage performance check requires creating a test PVC"
echo "This check will be skipped for safety"
echo "To manually test storage performance:"
echo "1. Create a test PVC"
echo "2. Write test data to the volume"
echo "3. Measure write/read performance"

echo ""
echo -e "${GREEN}=== Storage Configuration Check Passed ===${NC}"