# CI/CD Pipeline Configurations

This directory contains CI/CD pipeline configurations for automated MTV migration.

## Files Overview

### Jenkins Pipelines
- `jenkins/Jenkinsfile-cold-migration` - Cold migration Jenkins pipeline
- `jenkins/Jenkinsfile-warm-migration` - Warm migration Jenkins pipeline
- `jenkins/Jenkinsfile-batch-migration` - Batch migration Jenkins pipeline

### GitLab CI/CD
- `gitlab/.gitlab-ci-cold.yml` - Cold migration GitLab CI pipeline
- `gitlab/.gitlab-ci-warm.yml` - Warm migration GitLab CI pipeline
- `gitlab/.gitlab-ci-batch.yml` - Batch migration GitLab CI pipeline

### GitHub Actions
- `github/cold-migration.yml` - Cold migration GitHub Actions workflow
- `github/warm-migration.yml` - Warm migration GitHub Actions workflow
- `github/batch-migration.yml` - Batch migration GitHub Actions workflow

## Pipeline Features

### Common Features
- Automated pre-flight validation
- Environment configuration
- Migration execution
- Post-migration validation
- Automated rollback on failure
- Notification and reporting
- Audit trail and logging

### Pipeline Stages
1. **Pre-Migration**
   - Environment validation
   - Pre-flight checks
   - Configuration validation

2. **Migration**
   - Migration plan creation
   - Migration execution
   - Progress monitoring

3. **Post-Migration**
   - VM validation
   - Network testing
   - Application testing

4. **Cleanup/Reporting**
   - Report generation
   - Artifact cleanup
   - Notification

## Application Instructions

### Jenkins
1. Install Jenkins with required plugins
2. Create pipeline job with Jenkinsfile
3. Configure credentials and environment variables
4. Run pipeline job

### GitLab CI/CD
1. Add pipeline file to repository
2. Configure GitLab CI/CD variables
3. Commit and push to trigger pipeline
4. Monitor pipeline execution

### GitHub Actions
1. Add workflow file to repository
2. Configure GitHub secrets
3. Commit and push to trigger workflow
4. Monitor workflow execution

## Environment Variables

### Required Variables
- `VM_NAME`: VM name to migrate
- `MIGRATION_TYPE`: cold or warm
- `TARGET_NAMESPACE`: Target OpenShift namespace
- `NETWORK_MAPPING`: Source to destination network mapping
- `STORAGE_MAPPING`: Source to destination storage mapping

### Optional Variables
- `CUTOVER_SECONDS`: Warm migration cutover window
- `SYNC_INTERVAL_SECONDS`: Warm migration sync interval
- `SKIP_VALIDATION`: Skip pre/post validation
- `AUTO_ROLLBACK`: Enable automatic rollback on failure

## RedHat Best Practices

1. Use secret management for sensitive data
2. Implement proper approval gates
3. Use parallel execution where possible
4. Implement proper error handling
5. Generate comprehensive reports
6. Configure appropriate notifications
7. Use pipeline artifacts for audit trail
8. Test pipelines in non-production environments