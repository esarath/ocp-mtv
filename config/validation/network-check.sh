#!/bin/bash

# Network Configuration Check Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Network Configuration Check ==="

# Check Network Attachment Definitions
if oc get network-attachment-definition -n openshift-mtv &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: Network attachment definitions exist"
    
    local NAD_COUNT=$(oc get network-attachment-definition -n openshift-mtv | grep -c -v "NAME" || echo "0")
    echo "Total network attachment definitions: $NAD_COUNT"
    
    oc get network-attachment-definition -n openshift-mtv
else
    echo -e "${RED}✗ FAIL${NC}: No network attachment definitions found"
    echo "Create network attachment definitions before proceeding"
    exit 1
fi

# Check each network attachment definition
echo ""
echo "=== Network Attachment Definition Details ==="
oc get network-attachment-definition -n openshift-mtv -o name | while read -r NAD; do
    local NAD_NAME=$(echo "$NAD" | cut -d'/' -f2)
    echo "Checking: $NAD_NAME"
    
    # Check if NAD has valid configuration
    if oc get network-attachment-definition "$NAD_NAME" -n openshift-mtv -o jsonpath='{.spec.config}' &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: $NAD_NAME has valid configuration"
        
        # Extract bridge name if available
        local BRIDGE=$(oc get network-attachment-definition "$NAD_NAME" -n openshift-mtv -o jsonpath='{.spec.config}' | jq -r '.bridge // "N/A"' 2>/dev/null)
        if [ "$BRIDGE" != "N/A" ]; then
            echo "  Bridge: $BRIDGE"
        fi
        
        # Extract VLAN if available
        local VLAN=$(oc get network-attachment-definition "$NAD_NAME" -n openshift-mtv -o jsonpath='{.spec.config}' | jq -r '.vlan // "N/A"' 2>/dev/null)
        if [ "$VLAN" != "N/A" ]; then
            echo "  VLAN: $VLAN"
        fi
    else
        echo -e "${RED}✗ FAIL${NC}: $NAD_NAME has invalid configuration"
    fi
done

# Test network connectivity
echo ""
echo "=== Network Connectivity Test ==="

# Test DNS resolution
if command -v nslookup &> /dev/null; then
    if nslookup google.com &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: DNS resolution working"
    else
        echo -e "${YELLOW}⚠ WARN${NC}: DNS resolution may have issues"
    fi
fi

# Test internet connectivity
if command -v ping &> /dev/null; then
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: Internet connectivity available"
    else
        echo -e "${YELLOW}⚠ WARN${NC}: Internet connectivity not available (may be expected)"
    fi
fi

# Check network policies
echo ""
echo "=== Network Policies ==="
if oc get networkpolicy -n openshift-mtv &> /dev/null; then
    local NP_COUNT=$(oc get networkpolicy -n openshift-mtv | grep -c -v "NAME" || echo "0")
    if [ "$NP_COUNT" -gt 0 ]; then
        echo "Network policies: $NP_COUNT"
        oc get networkpolicy -n openshift-mtv
    else
        echo "No network policies configured"
    fi
else
    echo "No network policies found"
fi

# Check Multus configuration (if installed)
if oc get daemonset multus -n openshift-multus &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: Multus CNI is installed"
    oc get daemonset multus -n openshift-multus
else
    echo -e "${YELLOW}⚠ WARN${NC}: Multus CNI not found (may be required for network attachment definitions)"
fi

echo ""
echo -e "${GREEN}=== Network Configuration Check Passed ===${NC}"