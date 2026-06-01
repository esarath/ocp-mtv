# Networking Considerations

**Document:** 04-networking-considerations.md  
**Phase:** Network Architecture and Configuration  
**Status:** Network Implementation Guide

---

## Table of Contents
1. [Network Architecture Overview](#network-architecture-overview)
2. [VLAN Configuration](#vlan-configuration)
3. [Network Segmentation](#network-segmentation)
4. [Port Groups](#port-groups)
5. [Bridge Bindings](#bridge-bindings)
6. [Node Attachments](#node-attachments)
7. [Network Policies](#network-policies)
8. [IP Address Management](#ip-address-management)
9. [DNS Configuration](#dns-configuration)
10. [Load Balancer Integration](#load-balancer-integration)
11. [Network Migration Procedures](#network-migration-procedures)
12. [Network Validation and Testing](#network-validation-and-testing)
13. [Troubleshooting Network Issues](#troubleshooting-network-issues)

---

## Network Architecture Overview

### Critical Design Principle

**IMPORTANT: Do NOT use pod networking for VM migrations**

Instead, configure VLAN and port networks at the OpenShift level using:
- Multus CNI for multiple network interfaces
- Network Attachment Definitions for VLAN configuration
- Bridge bindings for physical network connectivity
- Node attachments for network-to-node mapping

### Network Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    NETWORK ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────┘

Physical Network Layer
┌─────────────────────────────────────────────────────────────────┐
│  Physical Switches (VLAN 10, 20, 30, 40, 50)                    │
│  - Trunk ports to worker nodes                                    │
│  - VLAN tagging for segmentation                                  │
└─────────────────────────────────────────────────────────────────┘
                            ▲
                            │
OpenShift Node Layer
┌─────────────────────────────────────────────────────────────────┐
│  Worker Node 1          Worker Node 2          Worker Node 3    │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐│
│  │ br-ex (Bridge) │    │ br-ex (Bridge) │    │ br-ex (Bridge) ││
│  │ VLAN Tagging   │    │ VLAN Tagging   │    │ VLAN Tagging   ││
│  └────────────────┘    └────────────────┘    └────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                            ▲
                            │
OpenShift Network Layer
┌─────────────────────────────────────────────────────────────────┐
│  Network Attachment Definitions                                  │
│  ├─ vlan-10-production (VLAN 10)                               │
│  ├─ vlan-20-development (VLAN 20)                              │
│  ├─ vlan-30-management (VLAN 30)                              │
│  └─ vlan-40-storage (VLAN 40)                                  │
└─────────────────────────────────────────────────────────────────┘
                            ▲
                            │
VM Network Layer
┌─────────────────────────────────────────────────────────────────┐
│  VM Interfaces (Multus CNI)                                     │
│  ├─ web-server-01: eth0 (vlan-10-production)                  │
│  ├─ app-server-01: eth0 (vlan-10-production)                  │
│  └─ db-server-01: eth0 (vlan-10-production)                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## VLAN Configuration

### VLAN Design Requirements

**VLAN Allocation Strategy:**
- **VLAN 10:** Production applications (web servers, application servers)
- **VLAN 20:** Development and testing environments
- **VLAN 30:** Management and administrative access
- **VLAN 40:** Storage networks (if required)
- **VLAN 50:** Backup and replication traffic
- **VLAN 60:** Migration data transfer

### VLAN Configuration Details

**VLAN 10 - Production Network:**
- **Purpose:** Production application traffic
- **IP Range:** 10.0.10.0/24
- **Gateway:** 10.0.10.1
- **DNS:** 8.8.8.8, 8.8.4.4
- **MTU:** 1500
- **QoS:** High priority

**VLAN 20 - Development Network:**
- **Purpose:** Development and testing
- **IP Range:** 10.0.20.0/24
- **Gateway:** 10.0.20.1
- **DNS:** 8.8.8.8, 8.8.4.4
- **MTU:** 1500
- **QoS:** Standard priority

**VLAN 30 - Management Network:**
- **Purpose:** Administrative access
- **IP Range:** 10.0.30.0/24
- **Gateway:** 10.0.30.1
- **DNS:** 8.8.8.8, 8.8.4.4
- **MTU:** 1500
- **QoS:** Management priority

### Network Attachment Definition Configuration

**VLAN 10 - Production:**
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan-10-production
  namespace: openshift-mtv
  annotations:
    k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/br-ex
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "bridge",
    "bridge": "br-ex",
    "vlan": 10,
    "ipam": {
      "type": "static",
      "subnet": "10.0.10.0/24",
      "rangeStart": "10.0.10.100",
      "rangeEnd": "10.0.10.200",
      "gateway": "10.0.10.1",
      "routes": [
        {
          "dst": "0.0.0.0/0",
          "gw": "10.0.10.1"
        }
      ],
      "dns": {
        "nameservers": ["8.8.8.8", "8.8.4.4"]
      }
    }
  }'
```

**VLAN 20 - Development:**
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan-20-development
  namespace: openshift-mtv
  annotations:
    k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/br-ex
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "bridge",
    "bridge": "br-ex",
    "vlan": 20,
    "ipam": {
      "type": "static",
      "subnet": "10.0.20.0/24",
      "rangeStart": "10.0.20.100",
      "rangeEnd": "10.0.20.200",
      "gateway": "10.0.20.1",
      "routes": [
        {
          "dst": "0.0.0.0/0",
          "gw": "10.0.20.1"
        }
      ],
      "dns": {
        "nameservers": ["8.8.8.8", "8.8.4.4"]
      }
    }
  }'
```

**VLAN 30 - Management:**
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan-30-management
  namespace: openshift-mtv
  annotations:
    k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/br-ex
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "bridge",
    "bridge": "br-ex",
    "vlan": 30,
    "ipam": {
      "type": "static",
      "subnet": "10.0.30.0/24",
      "rangeStart": "10.0.30.100",
      "rangeEnd": "10.0.30.200",
      "gateway": "10.0.30.1",
      "routes": [
        {
          "dst": "0.0.0.0/0",
          "gw": "10.0.30.1"
        }
      ],
      "dns": {
        "nameservers": ["8.8.8.8", "8.8.4.4"]
      }
    }
  }'
```

---

## Network Segmentation

### Segmentation Strategy

**Network Segmentation Categories:**

1. **Production Segmentation:**
   - Web Server Network (VLAN 10)
   - Application Server Network (VLAN 11)
   - Database Server Network (VLAN 12)

2. **Development Segmentation:**
   - Development Network (VLAN 20)
   - Testing Network (VLAN 21)
   - Staging Network (VLAN 22)

3. **Management Segmentation:**
   - Administrative Access (VLAN 30)
   - Monitoring Network (VLAN 31)
   - Backup Network (VLAN 32)

4. **Infrastructure Segmentation:**
   - Storage Network (VLAN 40)
   - Migration Network (VLAN 60)
   - Replication Network (VLAN 50)

### Segmentation Implementation

**Network Policy for Web Servers:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-server-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      role: web-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: load-balancer
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: application-server
    ports:
    - protocol: TCP
      port: 8080
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

**Network Policy for Database Servers:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      role: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: application-server
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: backup-server
    ports:
    - protocol: TCP
      port: 22
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

---

## Port Groups

### VMware Port Group Mapping

**Port Group to VLAN Mapping:**

| VMware Port Group | VLAN ID | OpenShift Network Attachment | Purpose |
|-------------------|---------|----------------------------|---------|
| VM Network        | 10      | vlan-10-production         | Production |
| Development Net   | 20      | vlan-20-development        | Development |
| Management Net    | 30      | vlan-30-management         | Management |
| Storage Net       | 40      | vlan-40-storage            | Storage |
| Backup Net        | 50      | vlan-50-backup             | Backup |

### Port Group Configuration in MTV

**Network Mapping Configuration:**
```yaml
apiVersion: fork.konveyor.io/v1beta1
kind: NetworkMap
metadata:
  name: vmware-port-group-mapping
  namespace: openshift-mtv
spec:
  map:
    - destination:
        name: vlan-10-production
        namespace: openshift-mtv
        type: multus
      source:
        id: "portgroup-123"
        name: "VM Network"
    - destination:
        name: vlan-20-development
        namespace: openshift-mtv
        type: multus
      source:
        id: "portgroup-456"
        name: "Development Net"
    - destination:
        name: vlan-30-management
        namespace: openshift-mtv
        type: multus
      source:
        id: "portgroup-789"
        name: "Management Net"
```

---

## Bridge Bindings

### Bridge Configuration

**Node Network Configuration Policy for Bridge:**
```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bridge-configuration
  namespace: openshift-mtv
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: br-ex
      type: linux-bridge
      state: up
      bridge:
        options:
          stp:
            enabled: false
          vlan:
            filtering: true
        port:
        - name: ens192
          vlan:
            tag-native: 0
            trunk-tags:
            - id: 10
            - id: 20
            - id: 30
            - id: 40
      ipv4:
        enabled: false
    - name: ens192
      type: ethernet
      state: up
      ipv4:
        enabled: false
```

### Bridge Validation

**Bridge Configuration Validation:**
```bash
# Verify bridge configuration on node
oc debug node/worker-1 -- chroot /host ip link show br-ex

# Check bridge VLAN configuration
oc debug node/worker-1 -- chroot /host bridge vlan show

# Verify bridge ports
oc debug node/worker-1 -- chroot /host bridge link
```

---

## Node Attachments

### Node Network Interface Configuration

**Node Network Interface:**
```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: node-interface-configuration
  namespace: openshift-mtv
spec:
  nodeSelector:
    kubernetes.io/hostname: worker-1.example.com
  desiredState:
    interfaces:
    - name: ens192
      type: ethernet
      state: up
      ipv4:
        enabled: false
      mtu: 9000
```

### Multi-Homed Network Configuration

**Multiple Network Interfaces per Node:**
```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: multi-homed-network
  namespace: openshift-mtv
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: ens192
      type: ethernet
      state: up
      ipv4:
        enabled: false
    - name: ens224
      type: ethernet
      state: up
      ipv4:
        address:
        - ip: 10.0.30.10
          prefix: 24
        dhcp: false
        enabled: true
```

---

## Network Policies

### Default Deny Policy

**Default Deny All Network Traffic:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow Specific Traffic

**Allow DNS Traffic:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### VM-Specific Network Policies

**Web Server Network Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-server-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      kubevirt.io: vm-name
      vm.kubevirt.io/name: web-server-01
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: load-balancer
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to:
    - podSelector:
        matchLabels:
          kubevirt.io: vm-name
          vm.kubevirt.io/name: app-server-01
    ports:
    - protocol: TCP
      port: 8080
```

---

## IP Address Management

### IP Allocation Strategy

**Static IP Assignment:**
- Allocate static IPs for production VMs
- Use DHCP for development environments
- Maintain IP address register
- Document IP assignments

**IP Address Register Template:**
```
IP Address Allocation Register

├── IP Address
├── VM Name
├── Original VMware Network
├── Migrated OpenShift Network
├── Allocation Type (Static/DHCP)
├── Purpose
├── Owner
└── Notes
```

### IP Address Preservation

**IP Address Preservation Strategy:**
1. **Pre-Migration:**
   - Document source VM IP addresses
   - Reserve target IP addresses
   - Configure network attachment definitions with static IP ranges

2. **Migration:**
   - Configure migrated VM with same IP address
   - Update network attachment definitions
   - Test network connectivity

3. **Post-Migration:**
   - Update DNS records (if IP changed)
   - Update load balancer configurations
   - Update monitoring configurations

---

## DNS Configuration

### DNS Update Procedures

**DNS Record Update Script:**
```bash
#!/bin/bash
# DNS update script for migrated VMs
VM_NAME=$1
OLD_IP=$2
NEW_IP=$3
DNS_SERVER="dns-server.example.com"

nsupdate -k /etc/rndc.key <<EOF
server $DNS_SERVER
zone example.com
update delete $VM_NAME.example.com. A
update add $VM_NAME.example.com. 300 A $NEW_IP
send
EOF
```

### DNS Integration with OpenShift

**DNS Operator Configuration:**
```yaml
apiVersion: operator.openshift.io/v1
kind: DNS
metadata:
  name: default
spec:
  servers:
  - name: example-dns-server
    zones:
    - example.com
    nameservers:
    - 10.0.10.5:53
```

---

## Load Balancer Integration

### Load Balancer Configuration

**HAProxy Configuration for Migrated VMs:**
```haproxy
frontend web-servers-frontend
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/
    default_backend web-servers-backend

backend web-servers-backend
    balance roundrobin
    option httpchk GET /health
    server web-server-01 10.0.10.50:80 check
    server web-server-02 10.0.10.51:80 check

backend app-servers-backend
    balance roundrobin
    option httpchk GET /health
    server app-server-01 10.0.11.50:8080 check
    server app-server-02 10.0.11.51:8080 check
```

### OpenShift Route Configuration

**OpenShift Route for Web Server:**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-server-route
  namespace: production
spec:
  host: web-server.example.com
  port:
    targetPort: 80
  to:
    kind: Service
    name: web-server-service
  tls:
    termination: edge
    certificate: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    key: |
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
```

---

## Network Migration Procedures

### Pre-Migration Network Validation

**Network Connectivity Test:**
```bash
#!/bin/bash
# Pre-migration network validation
SOURCE_IP=$1
TARGET_NETWORK=$2

# Test connectivity to target network
ping -c 3 $SOURCE_IP

# Test VLAN connectivity
# Configure test interface with target VLAN
# Test network segmentation
# Verify network policies
```

### Network Migration Execution

**Step-by-Step Network Migration:**

1. **Pre-Migration:**
   ```bash
   # Document current network configuration
   # Verify VLAN connectivity
   # Configure network attachment definitions
   # Test network policies
   ```

2. **Migration:**
   ```bash
   # Configure VM with target network
   # Execute migration
   # Validate network connectivity
   # Update DNS records
   ```

3. **Post-Migration:**
   ```bash
   # Update load balancer configurations
   # Update monitoring configurations
   # Cleanup old network configurations
   ```

---

## Network Port Requirements

### Required Network Ports for MTV Migration

**Source to Destination Connectivity (VMware to OpenShift):**

| Port | Protocol | Source | Destination | Purpose | Required For |
|------|----------|--------|-------------|---------|--------------|
| 443 | TCP | vCenter Server | OpenShift Controller | vCenter API access | VMware provider connection |
| 6443 | TCP | OpenShift API Server | MTV Controller | OpenShift API access | OpenShift provider connection |
| 8443 | TCP | vCenter Server (optional) | MTV Controller | Secure vCenter API access | Secure VMware provider |
| 22 | TCP | Conversion Host | vCenter/ESXi | SSH for data transfer | Direct data transfer method |
| 443 | TCP | ESXi Hosts | MTV Controller (optional) | ESXi API access | Direct ESXi connection |
| 443 | TCP | vCenter Server | DNS Server | DNS resolution | VMware infrastructure DNS |

**OpenShift Cluster Internal Communication:**

| Port | Protocol | Component | Purpose | Required For |
|------|----------|-----------|---------|--------------|
| 6443 | TCP | OpenShift API Server | Kubernetes API traffic | OpenShift control plane |
| 22623 | TCP | OpenShift API Server | Kubernetes API (internal) | Internal cluster communication |
| 443 | TCP | OpenShift Console | Web console access | UI and console access |
| 8443 | TCP | OpenShift Console | Secure web console access | Secure UI access |
| 2379 | TCP | OpenShift Controller | OpenShift controller API | Cluster management |
| 10250 | TCP | OpenShift Ingress | HTTP traffic ingress | Ingress controller |
| 10251 | TCP | OpenShift Ingress | HTTPS traffic ingress | Secure ingress controller |
| 5000 | TCP | OpenShift SDN | OpenShift SDN traffic | OVN-Kubernetes networking |
| 4789 | TCP | OpenShift SDN | Geneve encapsulation | Cluster networking |

**MTV Controller Communication:**

| Port | Protocol | Source | Destination | Purpose | Required For |
|------|----------|--------|-------------|---------|--------------|
| 443 | TCP | User/Client | MTV Controller | Web UI access | MTV web interface |
| 8443 | TCP | User/Client | MTV Controller | Secure web UI access | Secure MTV interface |
| 9443 | TCP | Conversion Host | MTV Controller | Conversion host communication | Migration coordination |
| 443 | TCP | Conversion Host | vCenter | vCenter API access | Source data access |

**VM Networking Requirements (Post-Migration):**

| Port | Protocol | Application | Purpose | Required For |
|------|----------|-----------|---------|--------------|
| 80 | TCP | Web Servers | HTTP traffic | Web server access |
| 443 | TCP | Web Servers | HTTPS traffic | Secure web access |
| 22 | TCP | SSH Server | SSH access | System administration |
| 3389 | TCP | Windows VMs | RDP access | Windows remote desktop |
| 5432 | TCP | PostgreSQL Database | PostgreSQL protocol | Database access |
| 3306 | TCP | MySQL Database | MySQL protocol | Database access |
| 1433 | TCP | MS SQL Database | MS SQL protocol | Database access |
| 1521 | TCP | Oracle Database | Oracle protocol | Database access |
| 27017 | TCP | MongoDB Database | MongoDB protocol | Database access |
| 6379 | TCP | Redis | Redis protocol | Cache access |
| 9090 | TCP | Prometheus | Metrics collection | Monitoring |
| 3000 | TCP | Loki | Log aggregation | Logging |
| 5672 | TCP | Nexus | Repository access | Package repository |
| 50000 | TCP | Jenkins CI/CD | Jenkins agent | Build automation |

**Network Policy Requirements:**

**Required Network Policy Rules:**

```yaml
# Allow MTV controller to communicate with OpenShift API
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mtv-controller-policy
  namespace: openshift-mtv
spec:
  podSelector:
    matchLabels:
      app: mtv-controller
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      matchLabels:
        control-plane: "master"
    ports:
    - protocol: TCP
      port: 6443
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8443
```

### Firewall Configuration

**Source Environment Firewall (VMware):**

**Required Firewall Rules:**
```bash
# Allow OpenShift cluster to access vCenter:
# vCenter Server → OpenShift Cluster: TCP 443

# If using secure vCenter:
# vCenter Server → OpenShift Cluster: TCP 8443

# Allow DNS resolution:
# DNS Server → OpenShift Cluster: UDP/TCP 53

# Example ESXi firewall configuration:
esxcli network firewall ruleset add -i ruleset-name
esxcli network firewall ruleset allow -i ruleset-name -r 100 -a 0.0.0.0/0 -t tcp -d 443
esxcli network firewall refresh
```

**Destination Environment Firewall (OpenShift):**

**Required Firewall Rules:**
```bash
# Allow OpenShift cluster to access VMware infrastructure:
# OpenShift Cluster → vCenter Server: TCP 443/8443
# OpenShift Cluster → ESXi Hosts: TCP 443 (if using direct access)

# Allow MTV controller communication:
# MTV Controller → OpenShift API: TCP 6443
# User/Client → MTV Controller: TCP 443/8443

# OpenShift firewall configuration (using firewalld):
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --reload
```

### VLAN and Port Group Configuration

**Port Group to VLAN Mapping with Port Requirements:**

| Port Group | VLAN | Port Requirements | Access Control | Security Zone |
|-----------|------|------------------|----------------|---------------|
| VM Network | 10 | 80, 443, 22, 3389 | Production applications | Production Zone |
| Development Net | 20 | 80, 443, 22, 8080 | Development teams | Development Zone |
| Management Net | 30 | 22, 3389, 6443, 8443, 9090 | Administrators | Management Zone |
| Database Net | 12 | 5432, 3306, 1433, 1521 | Database servers | Database Zone |
| Backup Net | 50 | 22, 873 (rsync), 3306, 5432 | Backup servers | Backup Zone |

### Network Configuration Validation

**Pre-Migration Port Validation:**
```bash
# Test vCenter connectivity from OpenShift
telnet vcenter.example.com 443

# Test OpenShift API connectivity from MTV Controller
curl -k https://api.openshift.example.com:6443/healthz

# Test DNS resolution
nslookup vcenter.example.com
nslookup api.openshift.example.com

# Test firewall rules
nmap -p 443,8443,6443 vcenter.example.com
nmap -p 6443 api.openshift.example.com
```

**Post-Migration Port Validation:**
```bash
# Test application ports on migrated VMs
nc -zv <vm-ip> 80    # HTTP
nc -zv <vm-ip> 443   # HTTPS
nc -zv <vm-ip> 22    # SSH
nc -zv <vm-ip> 3389  # RDP (Windows)

# Test database connectivity
nc -zv <db-ip> 5432   # PostgreSQL
nc -zv <db-ip> 3306   # MySQL
nc -zv <db-ip> 1433   # MS SQL
```

### Network Troubleshooting

**Common Network Port Issues:**

**Issue 1: MTV Cannot Connect to vCenter**
```bash
# Symptom: "Failed to connect to vCenter" error in MTV
# Cause: Port 443/8443 blocked or vCenter not accessible

# Troubleshooting:
1. Test connectivity: telnet vcenter.example.com 443
2. Check firewall rules on vCenter and OpenShift
3. Verify vCenter certificate validity
4. Check vCenter API service status
5. Test DNS resolution
```

**Issue 2: VM Cannot Access External Services**
```bash
# Symptom: Migrated VM cannot reach external services
# Cause: Network policies blocking egress traffic, VLAN misconfiguration

# Troubleshooting:
1. Check network policies: oc get network-policy -A
2. Verify VLAN configuration: oc describe network-attachment-definition
3. Check VM network interface: oc get vmi vm-name -o yaml
4. Test egress: oc exec -it vm-name -- curl -I https://google.com
5. Check firewall rules on upstream network devices
```

### Network Validation Checklist

**Pre-Migration Validation:**
- [ ] VLAN connectivity verified
- [ ] Bridge configuration validated
- [ ] Network attachment definitions created
- [ ] Network policies configured
- [ ] IP address allocation confirmed
- [ ] DNS resolution tested
- [ ] Load balancer configuration updated

**Post-Migration Validation:**
- [ ] VM network connectivity tested
- [ ] Network policies applied correctly
- [ ] DNS records updated
- [ ] Load balancer traffic flowing
- [ ] Monitoring configured
- [ ] Performance baseline established

### Network Testing Procedures

**Network Connectivity Test:**
```bash
#!/bin/bash
# Network connectivity test for migrated VM
VM_IP=$1
VM_NAME=$2

echo "Testing network connectivity for $VM_NAME ($VM_IP)"

# Test basic connectivity
ping -c 5 $VM_IP

# Test specific ports
nc -zv $VM_IP 22    # SSH
nc -zv $VM_IP 80    # HTTP
nc -zv $VM_IP 443   # HTTPS
nc -zv $VM_IP 3306  # MySQL
nc -zv $VM_IP 5432  # PostgreSQL

# Test DNS resolution
nslookup $VM_NAME.example.com

# Test traceroute
traceroute $VM_IP
```

---

## Troubleshooting Network Issues

### Common Network Issues

**Issue 1: VM Cannot Obtain IP Address**
```bash
# Check network attachment definition
oc get network-attachment-definition -n openshift-mtv

# Check bridge configuration
oc debug node/worker-1 -- chroot /host ip link show br-ex

# Check IPAM configuration
oc describe network-attachment-definition vlan-10-production -n openshift-mtv

# Solution: Verify VLAN configuration and IPAM settings
```

**Issue 2: VM Network Connectivity Lost After Migration**
```bash
# Check VM network interface configuration
oc get vmi vm-name -n production -o yaml

# Check network policy
oc get network-policy -n production

# Check bridge VLAN tagging
oc debug node/worker-1 -- chroot /host bridge vlan show

# Solution: Verify VLAN mapping and network policies
```

**Issue 3: Network Policies Blocking Traffic**
```bash
# Check network policies
oc get network-policy -n production

# Describe specific policy
oc describe network-policy web-server-policy -n production

# Test with temporary policy removal
oc delete network-policy web-server-policy -n production

# Solution: Adjust network policies to allow required traffic
```

**Issue 4: DNS Resolution Failing**
```bash
# Check DNS configuration
oc get dns cluster

# Check VM DNS settings
oc exec -it vm-name -- cat /etc/resolv.conf

# Test DNS resolution
nslookup vm-name.example.com

# Solution: Update DNS configuration and restart VM
```

### Network Debugging Commands

**Network Debugging:**
```bash
# Check VM network status
oc get vmi -n production
oc describe vmi vm-name -n production

# Check network attachment definitions
oc get network-attachment-definition -A
oc describe network-attachment-definition vlan-10-production -n openshift-mtv

# Check bridge configuration
oc debug node/worker-1 -- chroot /host ip link show
oc debug node/worker-1 -- chroot /host bridge link

# Check network policies
oc get network-policy -A
oc describe network-policy -A

# Test network connectivity from VM
oc rsh vmi vm-name -n production -- ping -c 3 8.8.8.8
```

---

## Next Steps

Upon completion of network configuration:
- **Implement Storage Configuration:** 05-storage-planning.md
- **Configure Governance and Security:** 06-governance-security.md

---

**Document Status:** Complete  
**Next Review Date:** [TBD]  
**Approved By:** [Approver Name]  
**Approval Date:** [Date]