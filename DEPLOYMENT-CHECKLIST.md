# Deployment Checklist

Use this checklist to ensure a smooth deployment of your MCP server to Azure.

## Pre-Deployment

### Azure Account Setup
- [ ] Azure subscription is active
- [ ] User has Owner or Contributor role on subscription
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Correct subscription selected (`az account show`)

### Tools Installation
- [ ] Terraform >= 1.5 installed (`terraform --version`)
- [ ] Git installed (`git --version`)
- [ ] jq installed (for script parsing) (`jq --version`)
- [ ] curl installed (for testing) (`curl --version`)

### Configuration
- [ ] Cloned the repository
- [ ] Created `terraform.tfvars` from example
- [ ] Reviewed and updated configuration values:
  - [ ] `environment` (dev/staging/prod)
  - [ ] `location` (Azure region)
  - [ ] `project_name` (unique name)
  - [ ] `apim_sku` (Developer/Basic/Standard)
  - [ ] `app_service_sku` (B1/S1/P1V2)
- [ ] Updated APIM publisher email in `resources.tf`

## Infrastructure Deployment

### Terraform Execution
- [ ] Run `terraform init` successfully
- [ ] Run `terraform validate` - no errors
- [ ] Run `terraform plan` - review resources
- [ ] Run `terraform apply` - confirm with 'yes'
- [ ] Wait for APIM provisioning (30-45 minutes)
- [ ] Verify outputs saved to `deployment-outputs.json`

### Post-Infrastructure Checks
- [ ] Resource group created in Azure Portal
- [ ] APIM instance visible and running
- [ ] Web App created and running
- [ ] Application Insights created
- [ ] Key Vault created
- [ ] No deployment errors in Terraform output

## Application Deployment

### Build and Package
- [ ] Navigate to `src/` directory
- [ ] Python dependencies listed in `requirements.txt`
- [ ] Created deployment ZIP package
- [ ] ZIP excludes unnecessary files (.pyc, __pycache__, etc.)

### Web App Deployment
- [ ] Uploaded ZIP to Web App via `az webapp deployment`
- [ ] Configured startup command (gunicorn)
- [ ] Web App restarted successfully
- [ ] No deployment errors in output

### Web App Configuration
- [ ] Environment variables set:
  - [ ] `ENVIRONMENT`
  - [ ] `APPLICATIONINSIGHTS_CONNECTION_STRING`
  - [ ] `APPINSIGHTS_INSTRUMENTATIONKEY`
- [ ] Managed Identity enabled
- [ ] Key Vault access granted to Web App identity
- [ ] HTTPS-only enabled

## APIM Configuration

### API Setup
- [ ] MCP API created in APIM
- [ ] Backend service configured
- [ ] API operations imported (tools, health)
- [ ] Product created and published

### Policies
- [ ] Rate limiting policy applied
- [ ] CORS policy configured
- [ ] Security headers added
- [ ] Logging configured to Application Insights
- [ ] Error handling policy added

### Subscriptions
- [ ] Default subscription exists
- [ ] Subscription key retrieved
- [ ] Additional subscriptions created (if needed)

## Testing

### Direct Web App Testing
- [ ] Health endpoint responds: `/health`
- [ ] List tools endpoint works: `/api/v1/tools`
- [ ] Call tool endpoint works: `/api/v1/tools/call`
- [ ] Application logs show successful requests

### APIM Gateway Testing
- [ ] Health check through APIM
- [ ] List tools through APIM with subscription key
- [ ] Call echo tool successfully
- [ ] Call calculate tool successfully
- [ ] Verify rate limiting (send >100 requests)
- [ ] Test without subscription key (should fail)
- [ ] Verify CORS headers in response

### Automated Testing
- [ ] Run `./scripts/test-api.sh`
- [ ] All tests pass
- [ ] No errors in output

## Monitoring Setup

### Application Insights
- [ ] Application Insights receiving data
- [ ] Request telemetry visible
- [ ] Custom events logged
- [ ] Performance metrics available
- [ ] Log queries return results

### Alerts Configuration
- [ ] High error rate alert created
- [ ] Slow response time alert created
- [ ] High CPU usage alert created
- [ ] APIM throttling alert created

### Diagnostic Settings
- [ ] APIM diagnostic logging enabled
- [ ] Web App diagnostic logging enabled
- [ ] Logs flowing to Log Analytics

## Security

### Authentication
- [ ] APIM subscription key required
- [ ] JWT validation configured (if using Azure AD)
- [ ] IP filtering configured (if required)

### Secrets Management
- [ ] Sensitive values stored in Key Vault
- [ ] No secrets in code or configuration files
- [ ] Managed Identity used for authentication

### Network Security
- [ ] HTTPS-only enforced
- [ ] TLS 1.2 minimum
- [ ] Security headers configured
- [ ] CORS properly restricted (production)

### Access Control
- [ ] Azure RBAC roles assigned
- [ ] Key Vault access policies configured
- [ ] APIM subscription access restricted

## Documentation

### Code Documentation
- [ ] README.md updated with project-specific info
- [ ] Architecture diagram reflects actual deployment
- [ ] API endpoints documented
- [ ] Environment variables documented

### Operational Documentation
- [ ] Runbook created for common operations
- [ ] Incident response procedures documented
- [ ] Escalation paths defined
- [ ] Contact information updated

### User Documentation
- [ ] API documentation in APIM Developer Portal
- [ ] Sample requests provided
- [ ] Authentication instructions clear
- [ ] Rate limits documented

## CI/CD (Optional)

### GitHub Actions Setup
- [ ] Workflow file created
- [ ] Azure credentials secret added
- [ ] Resource group secret added
- [ ] Web App name secret added
- [ ] Workflow tested successfully

### Pipeline Testing
- [ ] Push to main triggers deployment
- [ ] Tests run before deployment
- [ ] Infrastructure deployment succeeds
- [ ] Application deployment succeeds
- [ ] Post-deployment tests pass

## Production Readiness

### Performance
- [ ] Load testing completed
- [ ] Performance benchmarks documented
- [ ] Scaling rules configured
- [ ] CDN considered (if needed)

### Reliability
- [ ] Health checks configured
- [ ] Auto-scaling enabled (if needed)
- [ ] Backup strategy defined
- [ ] Disaster recovery plan created

### Cost Optimization
- [ ] Resource SKUs appropriate for workload
- [ ] Auto-shutdown configured for dev/test
- [ ] Cost alerts configured
- [ ] Reserved instances considered (long-term)

### Compliance
- [ ] Data residency requirements met
- [ ] Encryption at rest enabled
- [ ] Encryption in transit enforced
- [ ] Audit logging enabled
- [ ] Compliance reports reviewed

## Post-Deployment

### Handover
- [ ] Operations team trained
- [ ] Access credentials shared (securely)
- [ ] Monitoring dashboard shared
- [ ] Support contacts updated

### Verification
- [ ] End-to-end testing in production
- [ ] User acceptance testing completed
- [ ] Performance validated
- [ ] Security scan completed

### Cleanup
- [ ] Development/test resources removed
- [ ] Unused resources deleted
- [ ] Cost optimization applied
- [ ] Documentation updated

## Rollback Plan

In case of issues:

- [ ] Previous deployment package available
- [ ] Terraform state backed up
- [ ] Rollback procedure documented
- [ ] Rollback tested in non-production

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| DevOps Engineer | | | |
| Security Officer | | | |
| Operations Manager | | | |

## Notes

Use this section for deployment-specific notes:

```
Deployment Date: _______________
Environment: _______________
Version: _______________
Deployed By: _______________

Special Configurations:
-
-
-

Known Issues:
-
-
-
```

---

**Deployment Status**: ⬜ Not Started | 🟡 In Progress | ✅ Complete | ❌ Failed
