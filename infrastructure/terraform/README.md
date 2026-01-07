# Terraform Infrastructure Deployment Guide

## Prerequisites

1. **Install Terraform**
   ```bash
   # macOS
   brew install terraform
   
   # Windows (Chocolatey)
   choco install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Install Azure CLI**
   ```bash
   # macOS
   brew install azure-cli
   
   # Windows
   winget install Microsoft.AzureCLI
   
   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

3. **Login to Azure**
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

## Deployment Steps

### 1. Initialize Terraform

```bash
cd infrastructure/terraform
terraform init
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

```hcl
environment     = "dev"
location        = "eastus"
project_name    = "mcpserver"
apim_sku        = "Developer"
app_service_sku = "B1"
```

### 3. Plan Deployment

Review the resources that will be created:

```bash
terraform plan
```

### 4. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Retrieve Outputs

```bash
terraform output
```

Important outputs:
- `apim_gateway_url` - Your API Gateway URL
- `web_app_url` - Your Web App URL
- `apim_developer_portal_url` - Developer Portal for API documentation

## Post-Deployment Steps

### 1. Deploy Application Code

Create a deployment package:

```bash
cd ../../src
zip -r deploy.zip . -x "*.pyc" -x "__pycache__/*"
```

Deploy to Web App:

```bash
# Get resource group and app name from Terraform outputs
RG_NAME=$(terraform output -raw resource_group_name)
APP_NAME=$(terraform output -raw web_app_name)

# Deploy the code
az webapp deployment source config-zip \
  --resource-group $RG_NAME \
  --name $APP_NAME \
  --src deploy.zip
```

### 2. Configure Startup Command

```bash
az webapp config set \
  --resource-group $RG_NAME \
  --name $APP_NAME \
  --startup-file "gunicorn --bind=0.0.0.0:8000 --timeout 600 app:flask_app"
```

### 3. Get APIM Subscription Key

```bash
# Get APIM name
APIM_NAME=$(terraform output -raw apim_management_url | cut -d'/' -f3 | cut -d'.' -f1)

# List subscriptions
az apim subscription list \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME

# Get specific subscription key
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id <subscription-id>
```

### 4. Test the API

```bash
# Get the gateway URL
GATEWAY_URL=$(terraform output -raw apim_gateway_url)

# Test list tools endpoint
curl "${GATEWAY_URL}/mcp/api/v1/tools" \
  -H "Ocp-Apim-Subscription-Key: <your-subscription-key>"

# Test call tool endpoint
curl "${GATEWAY_URL}/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: <your-subscription-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "echo",
    "arguments": {
      "message": "Hello from MCP!"
    }
  }'
```

## Monitoring

### View Application Logs

```bash
az webapp log tail \
  --resource-group $RG_NAME \
  --name $APP_NAME
```

### Application Insights

```bash
# Get Application Insights ID
AI_ID=$(terraform output -raw application_insights_connection_string)

# View in portal
echo "https://portal.azure.com/#@/resource$(az monitor app-insights component show --app $APP_NAME --resource-group $RG_NAME --query id -o tsv)"
```

## Updating Infrastructure

### Modify Resources

1. Edit `.tf` files or `terraform.tfvars`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

### Scale Web App

```bash
# Scale up (change SKU)
az appservice plan update \
  --resource-group $RG_NAME \
  --name <app-service-plan-name> \
  --sku S1

# Scale out (add instances)
az appservice plan update \
  --resource-group $RG_NAME \
  --name <app-service-plan-name> \
  --number-of-workers 3
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

## Troubleshooting

### Common Issues

1. **APIM takes long to provision**
   - APIM can take 30-45 minutes to create
   - This is normal for the first deployment

2. **Web App not responding**
   ```bash
   # Check logs
   az webapp log tail --resource-group $RG_NAME --name $APP_NAME
   
   # Restart app
   az webapp restart --resource-group $RG_NAME --name $APP_NAME
   ```

3. **APIM subscription key not working**
   ```bash
   # Regenerate key
   az apim subscription regenerate-key \
     --resource-group $RG_NAME \
     --service-name $APIM_NAME \
     --subscription-id <subscription-id> \
     --key-type primary
   ```

4. **Application Insights not receiving data**
   - Verify connection string in Web App settings
   - Check that instrumentation key is correct
   - Allow 5-10 minutes for data to appear

## Cost Management

### View Current Costs

```bash
# Install cost management extension
az extension add --name costmanagement

# View costs for resource group
az costmanagement query \
  --type ActualCost \
  --dataset-filter "{\"and\":[{\"dimensions\":{\"name\":\"ResourceGroup\",\"operator\":\"In\",\"values\":[\"$RG_NAME\"]}}]}" \
  --timeframe MonthToDate
```

### Optimize Costs

- **Development**: Use Developer SKU for APIM and B1 for App Service
- **Production**: Consider Reserved Instances for long-term savings
- **Scale down**: When not in use, scale to lower tiers

## Security Best Practices

1. **Use Key Vault for secrets**
   ```bash
   # Add secret to Key Vault
   KV_NAME=$(terraform output -raw key_vault_name)
   az keyvault secret set \
     --vault-name $KV_NAME \
     --name "api-key" \
     --value "your-secret-value"
   ```

2. **Enable VNet Integration** (Production)
   - Set `enable_vnet = true` in terraform.tfvars
   - Redeploy infrastructure

3. **Configure Custom Domain**
   ```bash
   # Add custom domain to Web App
   az webapp config hostname add \
     --resource-group $RG_NAME \
     --webapp-name $APP_NAME \
     --hostname api.yourdomain.com
   
   # Add SSL certificate
   az webapp config ssl upload \
     --resource-group $RG_NAME \
     --name $APP_NAME \
     --certificate-file cert.pfx
   ```

## Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
