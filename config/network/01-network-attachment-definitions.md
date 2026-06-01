# Network Attachment Definitions

This directory contains NetworkAttachmentDefinitions for OpenShift Virtualization networking.

## Files Overview

### VLAN Network Attachments
- `vlan-10-production.yaml` - Production VLAN 10 network attachment
- `vlan-20-development.yaml` - Development VLAN 20 network attachment
- `vlan-30-management.yaml` - Management VLAN 30 network attachment

### Bridge Network Attachments
- `bridge-physical.yaml` - Physical bridge network attachment
- `bridge-ovs.yaml` - Open vSwitch bridge network attachment

## Network Configuration Details

### VLAN 10 - Production Network
- **Purpose:** Production application VMs
- **VLAN ID:** 10
- **Bridge:** br-ex
- **IP Range:** 192.168.10.0/24

### VLAN 20 - Development Network
- **Purpose:** Development and testing VMs
- **VLAN ID:** 20
- **Bridge:** br-ex
- **IP Range:** 192.168.20.0/24

### VLAN 30 - Management Network
- **Purpose:** Management and admin VMs
- **VLAN ID:** 30
- **Bridge:** br-ex
- **IP Range:** 192.168.30.0/24

## Application Instructions

1. **Review and Customize:** Update the VLAN IDs, bridge names, and IP ranges to match your environment
2. **Apply to OpenShift:** `oc apply -f config/network/`
3. **Verify:** `oc get network-attachment-definition -A`

## Network Policy Requirements

Ensure network policies allow traffic between the required networks:
- VM to VM communication
- VM to external services
- Load balancer to VM communication
- DNS resolution

## RedHat Best Practices

1. Use dedicated bridges for each VLAN
2. Implement network segmentation
3. Use IPAM for IP address management
4. Configure MTU settings appropriately
5. Test network connectivity before migration