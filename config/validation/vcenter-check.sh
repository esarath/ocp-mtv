#!/bin/bash

# vCenter Connectivity Check Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== vCenter Connectivity Check ==="

# Check govc installation
if ! command -v govc &> /dev/null; then
    echo -e "${RED}✗ FAIL${NC}: govc is not installed"
    echo "Install govc from: https://github.com/vmware/govmomi"
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: govc is installed"
govc version

# Check environment variables
if [ -z "$GOVC_URL" ]; then
    echo -e "${RED}✗ FAIL${NC}: GOVC_URL is not set"
    echo "Set GOVC_URL: export GOVC_URL=https://vcenter.example.com"
    exit 1
fi

if [ -z "$GOVC_USERNAME" ]; then
    echo -e "${RED}✗ FAIL${NC}: GOVC_USERNAME is not set"
    echo "Set GOVC_USERNAME: export GOVC_USERNAME=administrator@vsphere.local"
    exit 1
fi

if [ -z "$GOVC_PASSWORD" ]; then
    echo -e "${RED}✗ FAIL${NC}: GOVC_PASSWORD is not set"
    echo "Set GOVC_PASSWORD: export GOVC_PASSWORD=your-password"
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: Environment variables are set"

# Test vCenter connectivity
if govc about &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: vCenter connectivity successful"
    govc about
else
    echo -e "${RED}✗ FAIL${NC}: vCenter connectivity failed"
    echo "Check credentials and network connectivity"
    exit 1
fi

# Check datacenter
if govc datacenter.info &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: Datacenter accessible"
    govc datacenter.info
else
    echo -e "${YELLOW}⚠ WARN${NC}: Datacenter not accessible"
fi

# Check VM inventory
if govc ls "/$(govc datacenter.info | grep 'Name:' | awk '{print $2}')/vm" &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: VM inventory accessible"
    echo "Total VMs: $(govc ls "/$(govc datacenter.info | grep 'Name:' | awk '{print $2}')/vm" | wc -l)"
else
    echo -e "${YELLOW}⚠ WARN${NC}: VM inventory not accessible"
fi

echo ""
echo -e "${GREEN}=== vCenter Connectivity Check Passed ===${NC}"