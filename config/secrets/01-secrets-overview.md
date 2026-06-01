# Secrets Management Configuration

This directory contains secrets configuration for MTV migration.

## Files Overview

### Source Environment Secrets
- `vcenter-credentials-secret.yaml` - vCenter/ESXi credentials
- `esxi-credentials-secret.yaml` - Individual ESXi host credentials (optional)

### Target Environment Secrets
- `openshift-credentials-secret.yaml` - OpenShift API credentials
- `mtv-service-account-secret.yaml` - MTV service account credentials

### Application Secrets
- `database-credentials-secret.yaml` - Database connection credentials
- `app-credentials-secret.yaml` - Application-specific credentials

## Security Considerations

### Important Security Notes
- **Never commit secrets to version control**
- **Use external secret management** (Vault, AWS Secrets Manager, etc.)
- **Rotate credentials regularly**
- **Use least privilege access**
- **Enable encryption at rest**
- **Audit secret access**

### Secret Management Strategies
1. **Kubernetes Secrets:** Basic secret storage (base64 encoded)
2. **External Secrets Operator:** Sync secrets from external sources
3. **Vault Integration:** HashiCorp Vault integration
4. **Cloud Provider Secrets:** AWS Secrets Manager, Azure Key Vault

## Application Instructions

1. **Generate Secrets:** Use the provided scripts to generate encoded secrets
2. **Review and Customize:** Update with your actual credentials
3. **Apply to OpenShift:** `oc apply -f config/secrets/`
4. **Verify:** `oc get secrets -n openshift-mtv`

## Secret Generation

Generate base64-encoded secrets:
```bash
echo -n "your-username" | base64
echo -n "your-password" | base64
echo -n "your-api-token" | base64
```

## RedHat Best Practices

1. Use dedicated service accounts for migration
2. Implement least privilege access
3. Rotate credentials after migration completion
4. Use temporary credentials with expiration
5. Enable audit logging for secret access
6. Implement secret encryption at rest
7. Use network policies to restrict secret access