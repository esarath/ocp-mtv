# Ansible Automation for MTV Migration

This directory contains Ansible playbooks and roles for automated MTV migration.

## Files Overview

### Ansible Configuration
- `ansible.cfg` - Ansible configuration file
- `inventory/hosts` - Ansible inventory file
- `inventory/group_vars/` - Group variables for different host groups

### Playbooks
- `playbooks/site.yml` - Main site playbook
- `playbooks/pre-migration.yml` - Pre-migration tasks
- `playbooks/cold-migration.yml` - Cold migration playbook
- `playbooks/warm-migration.yml` - Warm migration playbook
- `playbooks/post-migration.yml` - Post-migration validation
- `playbooks/rollback.yml` - Rollback procedures

### Roles
- `roles/vmware-prep/` - VMware source preparation
- `roles/openshift-prep/` - OpenShift target preparation
- `roles/migration-exec/` - Migration execution
- `roles/validation/` - Pre-flight and post-migration validation
- `roles/cleanup/` - Cleanup and rollback procedures

### Templates
- `templates/migration-plan.j2` - Migration plan template
- `templates/network-attachment.j2` - Network attachment definition template
- `templates/storage-class.j2` - Storage class template

## Ansible Structure

```
ansible/
├── ansible.cfg
├── inventory/
│   ├── hosts
│   └── group_vars/
│       ├── all.yml
│       ├── vmware.yml
│       └── openshift.yml
├── playbooks/
│   ├── site.yml
│   ├── pre-migration.yml
│   ├── cold-migration.yml
│   ├── warm-migration.yml
│   ├── post-migration.yml
│   └── rollback.yml
├── roles/
│   ├── vmware-prep/
│   ├── openshift-prep/
│   ├── migration-exec/
│   ├── validation/
│   └── cleanup/
└── templates/
    ├── migration-plan.j2
    ├── network-attachment.j2
    └── storage-class.j2
```

## Application Instructions

### Setup
1. Install Ansible: `pip install ansible ansible-collection-kubernetes`
2. Configure inventory: Edit `inventory/hosts` and `inventory/group_vars/`
3. Install collections: `ansible-galaxy collection install kubernetes.core`
4. Test connectivity: `ansible -m ping all`

### Run Playbooks
```bash
# Run full migration
ansible-playbook playbooks/site.yml

# Run specific phases
ansible-playbook playbooks/pre-migration.yml
ansible-playbook playbooks/cold-migration.yml
ansible-playbook playbooks/warm-migration.yml
ansible-playbook playbooks/post-migration.yml

# Run with specific VM
ansible-playbook playbooks/cold-migration.yml -e "vm_name=web-server-01"
```

### Run with Variables
```bash
# Cold migration
ansible-playbook playbooks/cold-migration.yml \
  -e "vm_name=web-server-01" \
  -e "target_namespace=production" \
  -e "network_mapping=VM Network:vlan-10-production"

# Warm migration
ansible-playbook playbooks/warm-migration.yml \
  -e "vm_name=database-server-01" \
  -e "cutover_seconds=600"
```

## RedHat Best Practices

1. Use idempotent playbooks that can be run multiple times safely
2. Implement proper error handling and rollback mechanisms
3. Use Ansible vault for sensitive data storage
4. Test playbooks in non-production environments first
5. Implement proper logging and reporting
6. Use tags for granular playbook execution control
7. Implement proper variable validation
8. Use role-based structure for reusability