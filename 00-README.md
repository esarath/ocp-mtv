# VMware to OpenShift Virtualization Migration Guide
## Using Migration Toolkit for Virtualization (MTV)

**Document Store Location:** `C:\Users\tiny-win\Desktop\DATA_STORE\WS - A\ocp-mtv`

**Version:** 1.0  
**Last Updated:** 2026-05-29  
**Status:** Production-Ready

---

## Document Overview

This comprehensive, production-grade migration guide provides step-by-step procedures for migrating virtual machines from VMware vCenter/ESXi hosts to OpenShift Virtualization using the Migration Toolkit for Virtualization (MTV).

### Scope

- **VM Types:** Web servers, application servers, database servers
- **Migration Types:** Warm and cold migration scenarios
- **Source:** VMware vCenter/ESXi hosts
- **Destination:** OpenShift Virtualization (OpenShift Virtualization/KubeVirt)
- **Tool:** Migration Toolkit for Virtualization (MTV)

### Document Structure

This guide is organized into modular sections to facilitate focused reading and implementation:

```
ocp-mtv/
├── 00-README.md                    # This file - Index and overview
├── 01-planning-and-design.md       # Planning, proposal, and design phases
├── 02-high-level-design.md         # HLD - Architecture and infrastructure design
├── 03-low-level-design.md          # LLD - Detailed technical specifications
├── 04-networking-considerations.md # Advanced networking and VLAN configuration
├── 05-storage-planning.md          # Storage allocation and secrets management
├── 06-governance-security.md       # Approvals, compliance, and security requirements
├── 07-manual-migration.md          # Step-by-step manual migration procedures
├── 08-automated-migration.md       # Ansible and CI/CD pipeline automation
├── 09-interview-scenarios.md       # Interview scenarios and examples
├── 10-troubleshooting.md           # Common issues and troubleshooting steps
├── config/                         # Production-grade configuration files
│   ├── network/                    # Network attachment definitions
│   ├── storage/                    # Storage classes and PVCs
│   ├── secrets/                    # Secrets management
│   ├── providers/                  # Provider configurations
│   ├── migration-plans/            # Migration plan templates
│   ├── validation/                 # Pre-flight and post-migration scripts
│   ├── rollback/                   # Rollback and cleanup procedures
│   ├── ansible/                    # Ansible automation
│   └── ci-cd/                      # CI/CD pipeline configurations
```

---

## Quick Reference

### Migration Phases Summary

| Phase | Duration | Key Activities | Primary Owner |
|-------|----------|----------------|---------------|
| **Planning & Design** | 2-4 weeks | Assessment, HLD/LLD, resource planning | Solution Architect |
| **Proposal Preparation** | 1-2 weeks | Business case, ROI analysis, stakeholder approval | Project Manager |
| **Pre-Migration** | 1-3 weeks | Environment setup, networking, storage prep | Infrastructure Team |
| **Migration Execution** | Variable | VM migration (warm/cold), validation | Migration Engineer |
| **Post-Migration Validation** | 1-2 weeks | Testing, optimization, handover | QA/Operations Team |

### Critical Paths

1. **Networking Setup:** VLAN/port network configuration at OpenShift level (NOT pod networking)
2. **Storage Allocation:** Sufficient space for VM disks and migrations
3. **Secrets Management:** Secure handling of passwords/credentials across environments
4. **Special Cases:** Non-OS disks (NAS/SAN/NFS) attached to VMware RHEL systems

---

## Key Principles

### Networking Architecture
- **IMPORTANT:** Pod networking is NOT used for VM migrations
- Configure VLAN and port networks at the OpenShift level
- Use network segmentation, multiple VLANs, network policies, port groups
- Implement bridge bindings and node attachments for proper connectivity

### Storage Architecture
- Pre-allocate sufficient storage space for all VM migrations
- Handle secrets/passwords securely across source and destination
- Plan for non-OS disks/LUNs (NAS/SAN/NFS) attached to VMware RHEL systems
- Implement proper storage class mapping

### Migration Approaches
- **Manual Migration:** Step-by-step procedures for individual VMs
- **Automated Migration:** Ansible playbooks and CI/CD pipelines for repeatable, standardized migrations

---

## Getting Started

1. **Review Planning Phase:** Start with `01-planning-and-design.md`
2. **Understand Architecture:** Read `02-high-level-design.md` and `03-low-level-design.md`
3. **Configure Infrastructure:** Follow `04-networking-considerations.md` and `05-storage-planning.md`
4. **Establish Governance:** Review `06-governance-security.md`
5. **Review Configuration Files:** Examine production-ready configuration files in `config/` directory
6. **Execute Migration:** Choose manual (`07-manual-migration.md`) or automated (`08-automated-migration.md`)
7. **Validate:** Use post-migration validation procedures
8. **Troubleshoot:** Reference `10-troubleshooting.md` as needed

---

## Team Roles and Responsibilities

| Role | Responsibilities | Key Documents |
|------|------------------|---------------|
| **Solution Architect** | HLD/LLD design, technical strategy | 02-high-level-design.md, 03-low-level-design.md |
| **Project Manager** | Timeline, approvals, stakeholder management | 01-planning-and-design.md, 06-governance-security.md |
| **Network Engineer** | VLAN configuration, network policies | 04-networking-considerations.md |
| **Storage Engineer** | Storage allocation, LUN management | 05-storage-planning.md |
| **Migration Engineer** | Execute migrations, validation | 07-manual-migration.md, 08-automated-migration.md |
| **Security Engineer** | Compliance, secrets management | 06-governance-security.md |
| **DevOps Engineer** | CI/CD pipelines, automation | 08-automated-migration.md |
| **QA Engineer** | Testing, validation | 07-manual-migration.md, 10-troubleshooting.md |

---

## Migration Types

### Warm Migration
- **Description:** VMs remain running during migration
- **Downtime:** Minimal (seconds to minutes during final cutover)
- **Use Case:** Production systems requiring high availability
- **Complexity:** Higher (requires consistent network connectivity)

### Cold Migration
- **Description:** VMs are powered off during migration
- **Downtime:** Significant (duration of migration process)
- **Use Case:** Non-production systems, maintenance windows
- **Complexity:** Lower (simpler process, less risk)

---

## Configuration Files

Production-ready configuration files are provided in the `config/` directory for immediate deployment.

### Network Configuration (`config/network/`)
- **Network Attachment Definitions:** VLAN and bridge network configurations
- **Files:**
  - `vlan-10-production.yaml` - Production VLAN 10 network
  - `vlan-20-development.yaml` - Development VLAN 20 network
  - `vlan-30-management.yaml` - Management VLAN 30 network
  - `bridge-physical.yaml` - Physical bridge network
  - `bridge-ovs.yaml` - Open vSwitch bridge network

### Storage Configuration (`config/storage/`)
- **Storage Classes:** SSD, HDD, and NFS storage classes
- **Persistent Volume Claims:** Example PVCs for different VM types
- **DataVolumes:** Templates for VM disk migration
- **Files:**
  - `storage-class-ssd.yaml` - High-performance SSD storage
  - `storage-class-hdd.yaml` - Standard HDD storage
  - `storage-class-nfs.yaml` - NFS shared storage
  - `pvc-web-server-example.yaml` - Web server PVC example
  - `pvc-database-server-example.yaml` - Database PVC example
  - `pvc-app-server-example.yaml` - Application server PVC example

### Secrets Management (`config/secrets/`)
- **Credential Secrets:** vCenter, OpenShift, and application credentials
- **Generation Script:** Automated secret generation utility
- **Files:**
  - `vcenter-credentials-secret.yaml` - vCenter authentication
  - `openshift-credentials-secret.yaml` - OpenShift authentication
  - `database-credentials-secret.yaml` - Database credentials
  - `app-credentials-secret.yaml` - Application-specific secrets
  - `generate-secrets.sh` - Secret generation script

### Provider Configuration (`config/providers/`)
- **vSphere Provider:** VMware vCenter/ESXi provider configuration
- **OpenShift Provider:** OpenShift Virtualization provider configuration
- **Files:**
  - `vsphere-provider.yaml` - vSphere provider with basic configuration
  - `vsphere-provider-advanced.yaml` - vSphere provider with advanced settings
  - `openshift-provider.yaml` - OpenShift provider with basic configuration
  - `openshift-provider-advanced.yaml` - OpenShift provider with advanced settings

### Migration Plans (`config/migration-plans/`)
- **Cold Migration Templates:** For cold (VM powered off) migrations
- **Warm Migration Templates:** For warm (VM running) migrations
- **Batch Migration Templates:** For batch VM migrations
- **Files:**
  - `cold-migration-template.yaml` - Cold migration plan template
  - `cold-migration-web-server.yaml` - Web server cold migration example
  - `cold-migration-database.yaml` - Database cold migration example
  - `warm-migration-template.yaml` - Warm migration plan template
  - `warm-migration-web-server.yaml` - Web server warm migration example
  - `warm-migration-database.yaml` - Database warm migration example
  - `batch-migration-template.yaml` - Batch migration template
  - `batch-migration-production.yaml` - Production batch migration example

### Validation Scripts (`config/validation/`)
- **Pre-Flight Checks:** Environment validation before migration
- **Post-Migration Validation:** VM validation after migration
- **Files:**
  - `pre-flight-check.sh` - Comprehensive pre-flight validation
  - `vcenter-check.sh` - vCenter connectivity check
  - `openshift-check.sh` - OpenShift cluster health check
  - `network-check.sh` - Network configuration validation
  - `storage-check.sh` - Storage capacity and performance check
  - `post-migration-validation.sh` - Post-migration VM validation

### Rollback Procedures (`config/rollback/`)
- **VM Rollback:** Revert individual VM migrations
- **Cleanup Procedures:** Clean up migration artifacts and resources
- **Files:**
  - `vm-rollback.sh` - VM-specific rollback script
  - `cleanup-resources.sh` - Resource cleanup utility

### Ansible Automation (`config/ansible/`)
- **Playbooks:** Complete Ansible automation for all migration phases
- **Inventory:** Ansible inventory and group variables
- **Templates:** Jinja2 templates for migration plans
- **Files:**
  - `ansible.cfg` - Ansible configuration
  - `inventory/hosts` - Ansible inventory
  - `inventory/group_vars/all.yml` - Global variables
  - `inventory/group_vars/vmware.yml` - VMware-specific variables
  - `inventory/group_vars/openshift.yml` - OpenShift-specific variables
  - `playbooks/site.yml` - Main site playbook
  - `playbooks/pre-migration.yml` - Pre-migration tasks
  - `playbooks/cold-migration.yml` - Cold migration playbook
  - `playbooks/warm-migration.yml` - Warm migration playbook
  - `playbooks/post-migration.yml` - Post-migration validation
  - `playbooks/rollback.yml` - Rollback procedures
  - `templates/migration-plan.j2` - Migration plan template

### CI/CD Pipelines (`config/ci-cd/`)
- **Jenkins Pipelines:** Jenkinsfile configurations for different migration types
- **GitLab CI/CD:** GitLab pipeline configurations
- **GitHub Actions:** GitHub Actions workflows
- **Files:**
  - `jenkins/Jenkinsfile-cold-migration` - Cold migration Jenkins pipeline
  - `jenkins/Jenkinsfile-warm-migration` - Warm migration Jenkins pipeline
  - `jenkins/Jenkinsfile-batch-migration` - Batch migration Jenkins pipeline
  - `gitlab/.gitlab-ci-cold.yml` - Cold migration GitLab pipeline
  - `gitlab/.gitlab-ci-warm.yml` - Warm migration GitLab pipeline
  - `gitlab/.gitlab-ci-batch.yml` - Batch migration GitLab pipeline
  - `github/cold-migration.yml` - Cold migration GitHub Actions
  - `github/warm-migration.yml` - Warm migration GitHub Actions
  - `github/batch-migration.yml` - Batch migration GitHub Actions

## Configuration Application

### Quick Start with Configuration Files

1. **Customize Configuration:** Update configuration files with your environment details
2. **Apply Infrastructure:** `oc apply -f config/network/` and `oc apply -f config/storage/`
3. **Generate Secrets:** `./config/secrets/generate-secrets.sh`
4. **Configure Providers:** `oc apply -f config/providers/`
5. **Run Validation:** `./config/validation/pre-flight-check.sh`
6. **Execute Migration:** Use manual procedures or automated playbooks

### Automated Migration with Ansible

```bash
cd config/ansible
ansible-playbook playbooks/site.yml -e "vm_name=web-server-01"
```

### CI/CD Pipeline Execution

**Jenkins:** Import Jenkinsfiles and configure pipeline jobs
**GitLab:** Add pipeline files to repository and commit
**GitHub:** Add workflow files to `.github/workflows/` directory

## Special Considerations

### Windows VMs
- Additional drivers and tools required
- Licensing considerations
- Different network adapter types
- See `10-troubleshooting.md` for Windows-specific challenges

### Linux VMs
- Generally smoother migration process
- Kernel version compatibility
- Package management considerations
- See `10-troubleshooting.md` for Linux-specific challenges

### Non-OS Disks/LUNs
- NAS/SAN/NFS attached to VMware RHEL systems
- Requires special handling and reattachment procedures
- Documented in `05-storage-planning.md` and `10-troubleshooting.md`

---

## References and Resources

- **RedHat MTV Documentation:** https://www.redhat.com/architect/portfolio/detail/84-migrate-vms-vmware-openshift-demo
- **OpenShift Virtualization Documentation:** https://docs.openshift.com/container-platform/4.13/virt/
- **MTV User Guide:** https://access.redhat.com/documentation/en-us/migration_toolkit_for_virtualization/

---

## Document Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-05-29 | Initial production-ready version | Devin AI |

---

## Contact and Support

For questions or issues related to this migration guide, contact:
- **Technical Lead:** [Contact Information]
- **Project Manager:** [Contact Information]
- **Emergency Contact:** [Contact Information]

---

**Note:** This document is part of a comprehensive migration guide set. Refer to individual section documents for detailed implementation steps.