#!/bin/bash

# OpenShift Cluster Check Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== OpenShift Cluster Check ==="

# Check oc installation
if ! command -v oc &> /dev/null; then
    echo -e "${RED}✗ FAIL${NC}: oc is not installed"
    echo "Install oc from: https://docs.openshift.com/cli-tools/openshift-cli"
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: oc is installed"
oc version

# Check OpenShift connectivity
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗ FAIL${NC}: Not logged in to OpenShift"
    echo "Login using: oc login https://api.openshift.example.com:6443"
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: Logged in to OpenShift"
echo "User: $(oc whoami)"
echo "Server: $(oc whoami -c server)"

# Check cluster health
if oc get nodes &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: OpenShift cluster accessible"
    
    local NODE_COUNT=$(oc get nodes | grep -c "Ready" || echo "0")
    local TOTAL_NODES=$(oc get nodes | grep -c -v "NAME" || echo "0")
    
    echo "Total nodes: $TOTAL_NODES"
    echo "Ready nodes: $NODE_COUNT"
    
    if [ "$NODE_COUNT" -lt "$TOTAL_NODES" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: Some nodes are not ready"
        oc get nodes
    fi
else
    echo -e "${RED}✗ FAIL${NC}: Cannot get OpenShift nodes"
    exit 1
fi

# Check cluster operators
if oc get clusteroperator &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: Cluster operators accessible"
    
    local DEGRADED=$(oc get clusteroperator | grep -c "True" | grep -i "Degraded" || echo "0")
    if [ "$DEGRADED" -gt 0 ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $DEGRADED cluster operators are degraded"
        oc get clusteroperator
    else
        echo -e "${GREEN}✓ PASS${NC}: All cluster operators are healthy"
    fi
else
    echo -e "${YELLOW}⚠ WARN${NC}: Cannot check cluster operators"
fi

# Check OpenShift Virtualization
if oc get hyperconverged -n openshift-cnv &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: OpenShift Virtualization is installed"
    oc get hyperconverged -n openshift-cnv
else
    echo -e "${RED}✗ FAIL${NC}: OpenShift Virtualization is not installed"
    echo "Install OpenShift Virtualization before proceeding with MTV"
fi

# Check MTV operator
if oc get subscription -n openshift-mtv &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: MTV operator is installed"
    oc get subscription -n openshift-mtv
else
    echo -e "${YELLOW}⚠ WARN${NC}: MTV operator subscription not found"
fi

if oc get deployment -n openshift-mtv &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: MTV deployment is running"
    oc get deployment -n openshift-mtv
else
    echo -e "${YELLOW}⚠ WARN${NC}: MTV deployment not found"
fi

# Check resource availability
echo ""
echo "=== Resource Availability ==="
local AVAILABLE_CPU=$(oc get nodes -o jsonpath='{.items[0].status.allocatable.cpu}' 2>/dev/null)
local AVAILABLE_MEM=$(oc get nodes -o jsonpath='{.items[0].status.allocatable.memory}' 2>/dev/null)
echo "Available CPU (first node): $AVAILABLE_CPU"
echo "Available Memory (first node): $AVAILABLE_MEM"

echo ""
echo -e "${GREEN}=== OpenShift Cluster Check Passed ===${NC}"