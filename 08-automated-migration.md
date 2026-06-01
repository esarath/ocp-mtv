# Automated Migration with Ansible and CI/CD

**Document:** 08-automated-migration.md  
**Phase:** Automation and Pipeline Implementation  
**Status:** Automation Implementation Guide

---

## Table of Contents
1. [Automation Overview](#automation-overview)
2. [Ansible Automation](#ansible-automation)
3. [CI/CD Pipeline Configuration](#cicd-pipeline-configuration)
4. [Pipeline Stages](#pipeline-stages)
5. [Automation Scripts](#automation-scripts)
6. [Pipeline Orchestration](#pipeline-orchestration)
7. [Monitoring and Reporting](#monitoring-and-reporting)
8. [Error Handling and Recovery](#error-handling-and-recovery)
9. [Pipeline Maintenance](#pipeline-maintenance)

---

## Production-Grade Automated Migration

This document now includes production-grade automated migration procedures using the provided Ansible playbooks and CI/CD pipeline configurations in the `config/` directory. All automation follows RedHat best practices and is ready for production deployment.

### Quick Start Automation

For immediate automated POC deployment, use the provided Ansible playbooks:

```bash
cd config/ansible
ansible-playbook playbooks/site.yml -e "vm_name=web-server-01"
```

### Ansible Automation Deployment

#### Step 1: Configure Ansible Environment

**Install Required Dependencies:**
```bash
# Install Ansible
pip install ansible ansible-core

# Install required collections
ansible-galaxy collection install kubernetes.core community.general
ansible-galaxy collection install community.kubernetes

# Verify installation
ansible --version
ansible-galaxy collection list
```

**Configure Ansible:**
```bash
cd config/ansible
# Review and customize ansible.cfg
nano ansible.cfg

# Review and customize inventory
nano inventory/hosts
nano inventory/group_vars/all.yml
nano inventory/group_vars/vmware.yml
nano inventory/group_vars/openshift.yml
```

#### Step 2: Test Ansible Connectivity

**Test vCenter Connectivity:**
```bash
cd config/ansible
ansible -m vmware_datacenter_info -i inventory/hosts vmware
```

**Test OpenShift Connectivity:**
```bash
cd config/ansible
ansible -m kubernetes.core.k8s_info -a "api_version=v1 kind=Node" -i inventory/hosts openshift
```

#### Step 3: Run Automated Migration

**Full Migration with Site Playbook:**
```bash
cd config/ansible
ansible-playbook playbooks/site.yml \
  -e "vm_name=web-server-01" \
  -e "migration_type=cold" \
  -e "target_namespace=production" \
  -e "network_mapping=VM Network:vlan-10-production" \
  -e "storage_mapping=datastore-ssd:storage-class-hdd"
```

**Phase-Specific Migration:**

**Pre-Migration Only:**
```bash
cd config/ansible
ansible-playbook playbooks/pre-migration.yml \
  -e "vm_name=web-server-01"
```

**Cold Migration Only:**
```bash
cd config/ansible
ansible-playbook playbooks/cold-migration.yml \
  -e "vm_name=web-server-01" \
  -e "target_namespace=production" \
  -e "network_mapping=VM Network:vlan-10-production" \
  -e "storage_mapping=datastore-ssd:storage-class-hdd"
```

**Warm Migration Only:**
```bash
cd config/ansible
ansible-playbook playbooks/warm-migration.yml \
  -e "vm_name=database-server-01" \
  -e "target_namespace=production" \
  -e "network_mapping=VM Network:vlan-10-production" \
  -e "storage_mapping=datastore-ssd:storage-class-ssd" \
  -e "cutover_seconds=600" \
  -e "sync_interval_seconds=300"
```

**Post-Migration Validation Only:**
```bash
cd config/ansible
ansible-playbook playbooks/post-migration.yml \
  -e "vm_name=web-server-01" \
  -e "target_namespace=production" \
  -e "app_type=web-server"
```

**Rollback Only:**
```bash
cd config/ansible
ansible-playbook playbooks/rollback.yml \
  -e "vm_name=web-server-01" \
  -e "target_namespace=production" \
  -e "restore_source_vm=true"
```

#### Step 4: Environment Variable Configuration

**Using Environment Variables:**
```bash
export VM_NAME="web-server-01"
export MIGRATION_TYPE="cold"
export TARGET_NAMESPACE="production"
export NETWORK_MAPPING="VM Network:vlan-10-production"
export STORAGE_MAPPING="datastore-ssd:storage-class-hdd"

cd config/ansible
ansible-playbook playbooks/site.yml
```

**Using Variables File:**
```bash
# Create variables file
cat > migration-vars.yml << EOF
---
vm_name: "web-server-01"
migration_type: "cold"
target_namespace: "production"
network_mapping: "VM Network:vlan-10-production"
storage_mapping: "datastore-ssd:storage-class-hdd"
EOF

# Run playbook with variables file
cd config/ansible
ansible-playbook playbooks/site.yml -e "@migration-vars.yml"
```

### CI/CD Pipeline Deployment

#### Jenkins Deployment

**Prerequisites:**
- Jenkins installed with required plugins (Pipeline, Kubernetes, Ansible)
- Jenkins agent configured with kubectl and ansible
- Credentials configured in Jenkins

**Deployment Steps:**

1. **Import Jenkinsfiles:**
```bash
# Copy Jenkinsfiles to Jenkins workspace
cp config/ci-cd/jenkins/Jenkinsfile-cold-migration /path/to/jenkins/jobs/cold-migration/
cp config/ci-cd/jenkins/Jenkinsfile-warm-migration /path/to/jenkins/jobs/warm-migration/
cp config/ci-cd/jenkins/Jenkinsfile-batch-migration /path/to/jenkins/jobs/batch-migration/
```

2. **Create Pipeline Jobs:**
- Create Pipeline job in Jenkins
- Select "Pipeline script from SCM"
- Configure repository and Jenkinsfile path
- Configure parameters as defined in Jenkinsfile

3. **Run Pipeline:**
- Build job with parameters
- Monitor pipeline execution
- Review console output and reports

#### GitLab CI/CD Deployment

**Prerequisites:**
- GitLab project configured
- GitLab Runner installed and configured
- Runner configured with appropriate tags

**Deployment Steps:**

1. **Add CI/CD Files to Repository:**
```bash
cp config/ci-cd/gitlab/.gitlab-ci-cold.yml .gitlab-ci.yml
git add .gitlab-ci.yml
git commit -m "Add GitLab CI/CD pipeline"
git push
```

2. **Configure GitLab CI/CD Variables:**
- Navigate to Project Settings → CI/CD → Variables
- Add required variables (VM_NAME, TARGET_NAMESPACE, etc.)
- Configure secrets (vCenter credentials, OpenShift token)

3. **Run Pipeline:**
- Pipeline triggers automatically on commit
- Monitor pipeline execution in GitLab UI
- Review job logs and artifacts

#### GitHub Actions Deployment

**Prerequisites:**
- GitHub repository configured
- GitHub Actions enabled
- Secrets configured in repository settings

**Deployment Steps:**

1. **Add Workflow Files:**
```bash
mkdir -p .github/workflows
cp config/ci-cd/github/cold-migration.yml .github/workflows/
cp config/ci-cd/github/warm-migration.yml .github/workflows/
cp config/ci-cd/github/batch-migration.yml .github/workflows/
git add .github/workflows/
git commit -m "Add GitHub Actions workflows"
git push
```

2. **Configure GitHub Secrets:**
- Navigate to Repository Settings → Secrets
- Add required secrets (VMCENTER_PASSWORD, OPENSHIFT_TOKEN, etc.)
- Configure environment variables

3. **Run Workflow:**
- Navigate to Actions tab in GitHub
- Select workflow and run with parameters
- Monitor workflow execution
- Review logs and artifacts

---

## Automation Overview

### Automation Strategy

**Automation Goals:**
- Standardize migration procedures
- Reduce human error
- Increase migration speed
- Provide repeatability
- Enable audit trails
- Facilitate scaling

**Automation Architecture:**
```
┌─────────────────────────────────────────────────────────────────┐
                    AUTOMATION ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Ansible     │    │  CI/CD       │    │  Monitoring  │
│  Playbooks   │────▶│  Pipeline    │────▶│  & Reporting │
│              │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Source      │    │  OpenShift   │    │  Reporting   │
│  VMware      │    │  MTV         │    │  Dashboard   │
│  Environment │    │  Environment │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
```

### Automation Components

**Primary Components:**
1. **Ansible Playbooks:** Migration execution scripts
2. **CI/CD Pipeline:** Orchestration and scheduling
3. **Monitoring:** Real-time status tracking
4. **Reporting:** Automated reporting and documentation

**Secondary Components:**
1. **Git Repository:** Version control for automation scripts
2. **Artifact Repository:** Storage for automation artifacts
3. **Notification System:** Alerting and notifications
4. **Backup System:** Automated backup integration

---

## Ansible Automation

### Ansible Project Structure

**Ansible Repository Structure:**
```
ansible-migration/
├── inventory/
│   ├── hosts
│   └── group_vars/
│       ├── all.yml
│       ├── vmware.yml
│       └── openshift.yml
├── playbooks/
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
├── templates/
│   ├── migration-plan.j2
│   ├── network-attachment.j2
│   └── storage-class.j2
├── files/
│   ├── scripts/
│   └── configs/
└── ansible.cfg
```

### Ansible Configuration

**ansible.cfg:**
```ini
[defaults]
inventory = inventory/hosts
roles_path = roles/
remote_user = ansible-user
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

### Inventory Configuration

**inventory/hosts:**
```ini
[vmware]
vcenter.example.com ansible_user=vsphere ansible_connection=local

[openshift]
api.openshift.example.com ansible_user=kubeadmin ansible_connection=kubernetes

[migration_servers]
worker-1.example.com
worker-2.example.com
worker-3.example.com
```

**inventory/group_vars/all.yml:**
```yaml
---
migration_project:
  name: "VMware to OpenShift Migration"
  version: "1.0"
  
defaults:
  vcenter_server: "vcenter.example.com"
  openshift_api: "https://api.openshift.example.com:6443"
  mtv_namespace: "openshift-mtv"
  target_namespace: "production"
  
networking:
  production_vlan: "vlan-10-production"
  development_vlan: "vlan-20-development"
  management_vlan: "vlan-30-management"
  
storage:
  ssd_class: "storage-class-ssd"
  hdd_class: "storage-class-hdd"
  nfs_class: "storage-class-nfs"
```

### Ansible Playbooks

**Pre-Migration Playbook (playbooks/pre-migration.yml):**
```yaml
---
- name: VMware to OpenShift Pre-Migration Preparation
  hosts: vmware, openshift
  gather_facts: yes
  vars:
    vm_name: "{{ vm_name | default('web-server-01') }}"
    migration_type: "{{ migration_type | default('cold') }}"
    
  tasks:
    - name: Include VMware preparation tasks
      include_tasks: roles/vmware-prep/tasks/main.yml
      when: "'vmware' in group_names"
      
    - name: Include OpenShift preparation tasks
      include_tasks: roles/openshift-prep/tasks/main.yml
      when: "'openshift' in group_names"
      
    - name: Validate pre-migration requirements
      include_tasks: roles/validation/tasks/pre-migration.yml
```

**Cold Migration Playbook (playbooks/cold-migration.yml):**
```yaml
---
- name: VMware to OpenShift Cold Migration
  hosts: localhost
  gather_facts: yes
  vars:
    vm_name: "{{ vm_name | default('web-server-01') }}"
    target_namespace: "{{ target_namespace | default('production') }}"
    network_mapping: "{{ network_mapping | default('VM Network:vlan-10-production') }}"
    storage_mapping: "{{ storage_mapping | default('datastore-ssd:storage-class-ssd') }}"
    
  tasks:
    - name: Shutdown source VM
      include_tasks: roles/vmware-prep/tasks/shutdown-vm.yml
      vars:
        vm_name: "{{ vm_name }}"
        
    - name: Create migration plan
      include_tasks: roles/migration-exec/tasks/create-plan.yml
      vars:
        vm_name: "{{ vm_name }}"
        migration_type: "cold"
        target_namespace: "{{ target_namespace }}"
        
    - name: Execute migration
      include_tasks: roles/migration-exec/tasks/execute-migration.yml
      vars:
        migration_plan: "{{ vm_name }}-cold-migration"
        
    - name: Post-migration validation
      include_tasks: roles/validation/tasks/post-migration.yml
      vars:
        vm_name: "{{ vm_name }}"
        target_namespace: "{{ target_namespace }}"
```

**Warm Migration Playbook (playbooks/warm-migration.yml):**
```yaml
---
- name: VMware to OpenShift Warm Migration
  hosts: localhost
  gather_facts: yes
  vars:
    vm_name: "{{ vm_name | default('database-server-01') }}"
    target_namespace: "{{ target_namespace | default('production') }}"
    cutover_seconds: "{{ cutover_seconds | default(300) }}"
    
  tasks:
    - name: Create warm migration plan
      include_tasks: roles/migration-exec/tasks/create-plan.yml
      vars:
        vm_name: "{{ vm_name }}"
        migration_type: "warm"
        target_namespace: "{{ target_namespace }}"
        cutover_seconds: "{{ cutover_seconds }}"
        
    - name: Start warm migration
      include_tasks: roles/migration-exec/tasks/start-warm.yml
      vars:
        migration_plan: "{{ vm_name }}-warm-migration"
        
    - name: Monitor synchronization
      include_tasks: roles/migration-exec/tasks/monitor-sync.yml
      vars:
        migration_plan: "{{ vm_name }}-warm-migration"
        
    - name: Execute cutover
      include_tasks: roles/migration-exec/tasks/execute-cutover.yml
      vars:
        migration_plan: "{{ vm_name }}-warm-migration"
        
    - name: Post-cutover validation
      include_tasks: roles/validation/tasks/post-migration.yml
      vars:
        vm_name: "{{ vm_name }}"
        target_namespace: "{{ target_namespace }}"
```

### Ansible Roles

**VMware Preparation Role (roles/vmware-prep/tasks/main.yml):**
```yaml
---
- name: Check VMware connectivity
  uri:
    url: "https://{{ vcenter_server }}/api/vcenter/vm"
    method: GET
    user: "{{ vmware_user }}"
    password: "{{ vmware_password }}"
    validate_certs: no
  register: vmware_check

- name: Document VM configuration
  shell: |
    govc vm.info {{ vm_name }} > {{ playbook_dir }}/backups/{{ vm_name }}-config.txt
    govc vm.info -network {{ vm_name }} > {{ playbook_dir }}/backups/{{ vm_name }}-network.txt
    govc vm.info -disk {{ vm_name }} > {{ playbook_dir }}/backups/{{ vm_name }}-storage.txt

- name: Create pre-migration snapshot
  shell: govc snapshot.create {{ vm_name }} pre-migration-backup
  when: create_snapshot | default(true)

- name: Check for existing snapshots
  shell: govc snapshot.tree {{ vm_name }}
  register: snapshot_check
  ignore_errors: yes

- name: Warn if snapshots exist
  debug:
    msg: "VM {{ vm_name }} has existing snapshots - consider consolidation"
  when: snapshot_check.rc == 0
```

**OpenShift Preparation Role (roles/openshift-prep/tasks/main.yml):**
```yaml
---
- name: Check OpenShift connectivity
  k8s_info:
    api_version: config.openshift.io/v1
    kind: ClusterVersion
    name: version
  register: openshift_check

- name: Validate MTV operator
  k8s_info:
    api_version: operators.coreos.com/v1alpha1
    kind: ClusterServiceVersion
    namespace: openshift-mtv
  register: mtv_check

- name: Validate network attachment definitions
  k8s_info:
    api_version: k8s.cni.cncf.io/v1
    kind: NetworkAttachmentDefinition
    namespace: "{{ mtv_namespace }}"
  register: network_check

- name: Validate storage classes
  k8s_info:
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
  register: storage_check
```

**Migration Execution Role (roles/migration-exec/tasks/create-plan.yml):**
```yaml
---
- name: Generate migration plan from template
  template:
    src: migration-plan.j2
    dest: "{{ playbook_dir }}/templates/{{ vm_name }}-{{ migration_type }}-plan.yaml"
  vars:
    migration_plan_name: "{{ vm_name }}-{{ migration_type }}-migration"
    migration_type: "{{ migration_type }}"
    target_namespace: "{{ target_namespace }}"
    
- name: Apply migration plan
  k8s:
    state: present
    src: "{{ playbook_dir }}/templates/{{ vm_name }}-{{ migration_type }}-plan.yaml"
    namespace: "{{ mtv_namespace }}"
```

**Validation Role (roles/validation/tasks/post-migration.yml):**
```yaml
---
- name: Wait for VM to be created
  k8s_info:
    apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    name: "{{ vm_name }}"
    namespace: "{{ target_namespace }}"
  register: vm_check
  until: vm_check.resources[0].status.printableStatus == "Running"
  retries: 30
  delay: 10

- name: Get VM IP address
  k8s_info:
    apiVersion: kubevirt.io/v1alpha3
    kind: VirtualMachineInstance
    name: "{{ vm_name }}"
    namespace: "{{ target_namespace }}"
  register: vmi_info

- name: Test network connectivity
  wait_for:
    host: "{{ vmi_info.resources[0].status.interfaces[0].ipAddress }}"
    port: 22
    delay: 5
    timeout: 300

- name: Test application health
  uri:
    url: "http://{{ vmi_info.resources[0].status.interfaces[0].ipAddress }}/health"
    method: GET
    status_code: 200
  register: health_check
  ignore_errors: yes

- name: Report validation results
  debug:
    msg: "VM {{ vm_name }} validation {{ 'passed' if health_check.status == 200 else 'failed' }}"
```

---

## CI/CD Pipeline Configuration

### Jenkins Pipeline

**Jenkinsfile:**
```groovy
pipeline {
    agent any
    
    environment {
        VM_NAME = "${params.VM_NAME}"
        MIGRATION_TYPE = "${params.MIGRATION_TYPE}"
        TARGET_NAMESPACE = "${params.TARGET_NAMESPACE}"
        ANSIBLE_PLAYBOOK = "playbooks/${MIGRATION_TYPE}-migration.yml"
    }
    
    parameters {
        string(name: 'VM_NAME', defaultValue: 'web-server-01', description: 'VM to migrate')
        choice(name: 'MIGRATION_TYPE', choices: ['cold', 'warm'], description: 'Migration type')
        string(name: 'TARGET_NAMESPACE', defaultValue: 'production', description: 'Target namespace')
        booleanParam(name: 'CREATE_SNAPSHOT', defaultValue: true, description: 'Create pre-migration snapshot')
        booleanParam(name: 'AUTO_ROLLBACK', defaultValue: false, description: 'Auto rollback on failure')
    }
    
    stages {
        stage('Pre-Migration Validation') {
            steps {
                script {
                    sh "ansible-playbook -i inventory/hosts playbooks/pre-migration.yml --extra-vars \"vm_name=${VM_NAME} migration_type=${MIGRATION_TYPE} create_snapshot=${CREATE_SNAPSHOT}\""
                }
            }
        }
        
        stage('Migration Execution') {
            steps {
                script {
                    sh "ansible-playbook -i inventory/hosts ${ANSIBLE_PLAYBOOK} --extra-vars \"vm_name=${VM_NAME} target_namespace=${TARGET_NAMESPACE}\""
                }
            }
        }
        
        stage('Post-Migration Validation') {
            steps {
                script {
                    sh "ansible-playbook -i inventory/hosts playbooks/post-migration.yml --extra-vars \"vm_name=${VM_NAME} target_namespace=${TARGET_NAMESPACE}\""
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    sh "ansible-playbook -i inventory/hosts playbooks/cleanup.yml --extra-vars \"vm_name=${VM_NAME}\""
                }
            }
        }
    }
    
    post {
        success {
            echo 'Migration completed successfully'
            emailext (
                subject: "Migration Successful: ${VM_NAME}",
                body: "Migration of ${VM_NAME} completed successfully.",
                to: "${env.NOTIFICATION_EMAIL}"
            )
        }
        
        failure {
            script {
                if (params.AUTO_ROLLBACK) {
                    echo 'Migration failed, initiating rollback'
                    sh "ansible-playbook -i inventory/hosts playbooks/rollback.yml --extra-vars \"vm_name=${VM_NAME}\""
                }
            }
            emailext (
                subject: "Migration Failed: ${VM_NAME}",
                body: "Migration of ${VM_NAME} failed. Check Jenkins logs for details.",
                to: "${env.NOTIFICATION_EMAIL}"
            )
        }
    }
}
```

### GitLab CI/CD Pipeline

**.gitlab-ci.yml:**
```yaml
stages:
  - validate
  - execute
  - validate-post
  - cleanup

variables:
  ANSIBLE_INVENTORY: inventory/hosts
  MTV_NAMESPACE: openshift-mtv
  TARGET_NAMESPACE: production

before_script:
  - which ansible
  - ansible --version
  - ansible-galaxy collection install community.kubernetes
  - ansible-galaxy collection install community.vmware

validate-pre-migration:
  stage: validate
  script:
    - ansible-playbook -i ${ANSIBLE_INVENTORY} playbooks/pre-migration.yml --extra-vars "vm_name=${VM_NAME} migration_type=${MIGRATION_TYPE}"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "web"'
  artifacts:
    paths:
      - backups/
    expire_in: 1 day

execute-migration:
  stage: execute
  script:
    - ansible-playbook -i ${ANSIBLE_INVENTORY} playbooks/${MIGRATION_TYPE}-migration.yml --extra-vars "vm_name=${VM_NAME} target_namespace=${TARGET_NAMESPACE}"
  dependencies:
    - validate-pre-migration
  rules:
    - if: '$CI_PIPELINE_SOURCE == "web"'

validate-post-migration:
  stage: validate-post
  script:
    - ansible-playbook -i ${ANSIBLE_INVENTORY} playbooks/post-migration.yml --extra-vars "vm_name=${VM_NAME} target_namespace=${TARGET_NAMESPACE}"
  dependencies:
    - execute-migration
  rules:
    - if: '$CI_PIPELINE_SOURCE == "web"'

cleanup:
  stage: cleanup
  script:
    - ansible-playbook -i ${ANSIBLE_INVENTORY} playbooks/cleanup.yml --extra-vars "vm_name=${VM_NAME}"
  dependencies:
    - validate-post-migration
  rules:
    - if: '$CI_PIPELINE_SOURCE == "web"'
  when: always

rollback-on-failure:
  stage: execute
  script:
    - ansible-playbook -i ${ANSIBLE_INVENTORY} playbooks/rollback.yml --extra-vars "vm_name=${VM_NAME}"
  rules:
    - if: '$CI_JOB_STATUS == "failed"'
  when: on_failure
```

### GitHub Actions Pipeline

**.github/workflows/migration.yml:**
```yaml
name: VM Migration Pipeline

on:
  workflow_dispatch:
    inputs:
      vm_name:
        description: 'VM to migrate'
        required: true
        default: 'web-server-01'
      migration_type:
        description: 'Migration type'
        required: true
        type: choice
        options:
          - cold
          - warm
      target_namespace:
        description: 'Target namespace'
        required: true
        default: 'production'
      auto_rollback:
        description: 'Auto rollback on failure'
        required: false
        type: boolean
        default: false

jobs:
  migration:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install Ansible
      run: |
        pip install ansible-core
        pip install kubernetes
        pip install pyvmomi
    
    - name: Install Ansible collections
      run: |
        ansible-galaxy collection install community.kubernetes
        ansible-galaxy collection install community.vmware
    
    - name: Pre-migration validation
      run: |
        ansible-playbook -i inventory/hosts playbooks/pre-migration.yml \
          --extra-vars "vm_name=${{ github.event.inputs.vm_name }} \
                        migration_type=${{ github.event.inputs.migration_type }}"
    
    - name: Execute migration
      run: |
        ansible-playbook -i inventory/hosts playbooks/${{ github.event.inputs.migration_type }}-migration.yml \
          --extra-vars "vm_name=${{ github.event.inputs.vm_name }} \
                        target_namespace=${{ github.event.inputs.target_namespace }}"
    
    - name: Post-migration validation
      run: |
        ansible-playbook -i inventory/hosts playbooks/post-migration.yml \
          --extra-vars "vm_name=${{ github.event.inputs.vm_name }} \
                        target_namespace=${{ github.event.inputs.target_namespace }}"
    
    - name: Rollback on failure
      if: failure() && github.event.inputs.auto_rollback == 'true'
      run: |
        ansible-playbook -i inventory/hosts playbooks/rollback.yml \
          --extra-vars "vm_name=${{ github.event.inputs.vm_name }}"
```

---

## Pipeline Stages

### Stage 1: Pre-Migration Validation

**Purpose:** Validate environment readiness before migration

**Tasks:**
- Source VM validation
- Target environment validation
- Network connectivity validation
- Storage capacity validation
- Security validation
- Backup validation

**Success Criteria:**
- All validations pass
- Sufficient resources available
- Backup completed successfully
- No blocking issues identified

### Stage 2: Migration Execution

**Purpose:** Execute the migration process

**Tasks:**
- Cold migration: Shutdown source VM
- Warm migration: Start synchronization
- Create migration plan
- Execute migration
- Monitor progress

**Success Criteria:**
- Migration completes successfully
- VM created in target environment
- Data integrity maintained

### Stage 3: Post-Migration Validation

**Purpose:** Validate migrated VM functionality

**Tasks:**
- VM startup validation
- Network connectivity validation
- Application functionality validation
- Performance validation
- Security validation

**Success Criteria:**
- VM runs successfully
- Network connectivity established
- Application functions correctly
- Performance meets baseline

### Stage 4: Cleanup

**Purpose:** Clean up migration artifacts

**Tasks:**
- Remove migration plans
- Remove temporary resources
- Update documentation
- Archive migration logs
- Remove source VM (if validated)

**Success Criteria:**
- Migration artifacts removed
- Documentation updated
- Logs archived
- Source VM removed (if applicable)

---

## Automation Scripts

### Migration Script Template

**scripts/migrate-vm.sh:**
```bash
#!/bin/bash
# Automated VM migration script

set -e

# Configuration
VM_NAME=${1:-"web-server-01"}
MIGRATION_TYPE=${2:-"cold"}
TARGET_NAMESPACE=${3:-"production"}
ANSIBLE_PLAYBOOK="playbooks/${MIGRATION_TYPE}-migration.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Validate inputs
if [ -z "$VM_NAME" ]; then
    error "VM name is required"
fi

if [ "$MIGRATION_TYPE" != "cold" ] && [ "$MIGRATION_TYPE" != "warm" ]; then
    error "Migration type must be 'cold' or 'warm'"
fi

log "Starting ${MIGRATION_TYPE} migration of ${VM_NAME} to ${TARGET_NAMESPACE}"

# Pre-migration validation
log "Running pre-migration validation"
ansible-playbook -i inventory/hosts playbooks/pre-migration.yml \
    --extra-vars "vm_name=${VM_NAME} migration_type=${MIGRATION_TYPE}" || \
    error "Pre-migration validation failed"

# Execute migration
log "Executing ${MIGRATION_TYPE} migration"
ansible-playbook -i inventory/hosts ${ANSIBLE_PLAYBOOK} \
    --extra-vars "vm_name=${VM_NAME} target_namespace=${TARGET_NAMESPACE}" || \
    error "Migration execution failed"

# Post-migration validation
log "Running post-migration validation"
ansible-playbook -i inventory/hosts playbooks/post-migration.yml \
    --extra-vars "vm_name=${VM_NAME} target_namespace=${TARGET_NAMESPACE}" || \
    error "Post-migration validation failed"

log "Migration of ${VM_NAME} completed successfully"
```

### Validation Script

**scripts/validate-migration.sh:**
```bash
#!/bin/bash
# Migration validation script

set -e

VM_NAME=$1
NAMESPACE=$2

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Check VM status
log "Checking VM status for ${VM_NAME}"
VM_STATUS=$(oc get vm ${VM_NAME} -n ${NAMESPACE} -o jsonpath='{.status.printableStatus}')
log "VM Status: ${VM_STATUS}"

# Check VMI status
log "Checking VMI status"
VMI_STATUS=$(oc get vmi ${VM_NAME} -n ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Not running")
log "VMI Phase: ${VMI_STATUS}"

# Get VM IP
log "Getting VM IP address"
VM_IP=$(oc get vmi ${VM_NAME} -n ${NAMESPACE} -o jsonpath='{.status.interfaces[0].ipAddress}' 2>/dev/null || echo "N/A")
log "VM IP: ${VM_IP}"

# Test connectivity
if [ "$VM_IP" != "N/A" ]; then
    log "Testing network connectivity"
    ping -c 3 $VM_IP || log "WARNING: Network connectivity failed"
    
    log "Testing SSH connectivity"
    nc -zv $VM_IP 22 || log "WARNING: SSH port not accessible"
fi

# Test application health
if [ "$VM_IP" != "N/A" ]; then
    log "Testing application health endpoint"
    curl -f http://${VM_IP}/health || log "WARNING: Health check failed"
fi

log "Validation complete"
```

---

## Pipeline Orchestration

### Pipeline Scheduler

**Automated Scheduling:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: migration-scheduler
  namespace: openshift-mtv
spec:
  schedule: "0 2 * * *"  # Run at 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: migration-runner
            image: ansible-runner:latest
            command:
            - /bin/sh
            - -c
            - |
              # Run migration script
              /scripts/migrate-vm.sh web-server-01 cold production
          restartPolicy: OnFailure
```

### Pipeline Triggers

**Trigger Configuration:**
```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: migration-trigger
  namespace: openshift-mtv
spec:
  params:
    - name: vm-name
      description: Name of VM to migrate
    - name: migration-type
      description: Type of migration (cold or warm)
    - name: target-namespace
      description: Target namespace
  resourcetemplates:
    - apiVersion: v1
      kind: Pod
      metadata:
        generateName: migration-
      spec:
        containers:
        - name: ansible-runner
          image: ansible-runner:latest
          command:
          - ansible-playbook
          - -i
          - inventory/hosts
          - playbooks/$(tt.params.migration-type)-migration.yml
          - --extra-vars
          - "vm_name=$(tt.params.vm-name) target_namespace=$(tt.params.target-namespace)"
```

---

## Monitoring and Reporting

### Pipeline Monitoring

**Monitoring Metrics:**
- Pipeline execution time
- Migration success rate
- Resource utilization
- Error rates
- Validation results

**Grafana Dashboard Configuration:**
```json
{
  "dashboard": {
    "title": "Migration Pipeline Monitoring",
    "panels": [
      {
        "title": "Pipeline Execution Time",
        "targets": [
          {
            "expr": "pipeline_duration_seconds"
          }
        ]
      },
      {
        "title": "Migration Success Rate",
        "targets": [
          {
            "expr": "migration_success_total / migration_total * 100"
          }
        ]
      }
    ]
  }
}
```

### Automated Reporting

**Report Generation:**
```python
#!/usr/bin/env python3
# Automated migration report generator

import json
import datetime
import requests

def generate_migration_report(vm_name, status, duration, issues):
    report = {
        "vm_name": vm_name,
        "status": status,
        "duration": duration,
        "timestamp": datetime.datetime.now().isoformat(),
        "issues": issues
    }
    
    # Send to reporting system
    requests.post("http://reporting-system/api/migrations", json=report)
    
    # Generate summary
    print(f"Migration Report for {vm_name}")
    print(f"Status: {status}")
    print(f"Duration: {duration}")
    print(f"Issues: {len(issues)}")
    
    return report

if __name__ == "__main__":
    generate_migration_report(
        vm_name="web-server-01",
        status="success",
        duration="45 minutes",
        issues=[]
    )
```

---

## Error Handling and Recovery

### Error Handling Strategy

**Error Categories:**
1. **Validation Errors:** Pre-migration validation failures
2. **Execution Errors:** Migration execution failures
3. **Post-Validation Errors:** Post-migration validation failures
4. **Network Errors:** Connectivity issues
5. **Storage Errors:** Storage issues
6. **Application Errors:** Application-specific failures

### Automated Rollback

**Rollback Configuration:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rollback-config
  namespace: openshift-mtv
data:
  rollback-on-failure: "true"
  rollback-timeout: "1800"
  preserve-logs: "true"
```

### Recovery Procedures

**Recovery Automation:**
```yaml
- name: Check migration status
  k8s_info:
    apiVersion: fork.konveyor.io/v1beta1
    kind: Migration
    name: "{{ migration_plan }}"
    namespace: "{{ mtv_namespace }}"
  register: migration_status
  
- name: Execute rollback if migration failed
  include_tasks: roles/rollback/tasks/main.yml
  when: migration_status.resources[0].status.phase == "Failed"
```

---

## Pipeline Maintenance

### Version Control

**Git Workflow:**
- Main branch: Production pipelines
- Development branch: Pipeline development
- Feature branches: New features
- Pull requests: Code review

### Pipeline Updates

**Update Process:**
1. Create feature branch
2. Implement changes
3. Test in development environment
4. Create pull request
5. Code review and approval
6. Merge to main branch
7. Deploy to production

### Backup and Recovery

**Pipeline Backup:**
```bash
#!/bin/bash
# Backup pipeline configuration

BACKUP_DIR="/backup/pipelines"
DATE=$(date +%Y%m%d-%H%M%S)

# Backup playbooks
tar -czf ${BACKUP_DIR}/playbooks-${DATE}.tar.gz playbooks/

# Backup inventory
tar -czf ${BACKUP_DIR}/inventory-${DATE}.tar.gz inventory/

# Backup templates
tar -czf ${BACKUP_DIR}/templates-${DATE}.tar.gz templates/
```

---

## Next Steps

Upon completion of automation implementation:
- **Review Interview Scenarios:** 09-interview-scenarios.md
- **Review Troubleshooting Guide:** 10-troubleshooting.md

---

**Document Status:** Complete  
**Next Review Date:** [TBD]  
**Approved By:** [Approver Name]  
**Approval Date:** [Date]