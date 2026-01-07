# Quick Start Guide

Get your MCP server running on Azure in under 10 minutes!

## Prerequisites Checklist

- [ ] Azure CLI installed (`az --version`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Azure subscription with Owner or Contributor access
- [ ] Git installed

## Step-by-Step Deployment

### 1. Login to Azure (2 minutes)

```bash
# Login
az login

# Set your subscription
az account list --output table
az account set --subscription "<your-subscription-id>"

# Verify
az account show
```

### 2. Clone and Configure (2 minutes)

```bash
# Clone the repo
git clone <repo-url>
cd MCP-build

# Configure Terraform
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit the file (optional - defaults work fine for dev)
# nano terraform.tfvars
```

### 3. Deploy Everything (5 minutes)

```bash
# Go back to project root
cd ../..

# Run automated deployment
./scripts/deploy.sh
```

⏱️ **Wait 30-45 minutes** for APIM to provision (this is normal!)

### 4. Test Your API (1 minute)

```bash
# Run automated tests
./scripts/test-api.sh
```

## What Gets Deployed?

✅ Resource Group  
✅ Azure API Management (Developer SKU)  
✅ Azure Web App (B1 tier, Python 3.11)  
✅ Application Insights  
✅ Key Vault  
✅ MCP Server Application  

## Access Your Resources

After deployment completes, you'll see:

```
APIM Gateway URL: https://<name>.azure-api.net
APIM Developer Portal: https://<name>.developer.azure-api.net
Web App URL: https://<name>.azurewebsites.net
```

## Get Your API Key

```bash
# From deployment outputs
cat deployment-outputs.json | jq -r '.apim_gateway_url.value'

# Get subscription key
az apim subscription list \
  --resource-group $(cat deployment-outputs.json | jq -r '.resource_group_name.value') \
  --service-name $(cat deployment-outputs.json | jq -r '.apim_gateway_url.value' | cut -d'/' -f3 | cut -d'.' -f1) \
  --query "[0].{Key:primaryKey}" -o tsv
```

## Test Your MCP Server

### 1. List Available Tools

```bash
curl "https://<apim-name>.azure-api.net/mcp/api/v1/tools" \
  -H "Ocp-Apim-Subscription-Key: <your-key>"
```

### 2. Call the Echo Tool

```bash
curl -X POST "https://<apim-name>.azure-api.net/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: <your-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "echo",
    "arguments": {
      "message": "Hello Azure!"
    }
  }'
```

### 3. Perform a Calculation

```bash
curl -X POST "https://<apim-name>.azure-api.net/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: <your-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "multiply",
      "a": 6,
      "b": 7
    }
  }'
```

## Common Issues

### Issue: "Terraform not found"
**Solution**: Install Terraform
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Issue: "Azure CLI not found"
**Solution**: Install Azure CLI
```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Issue: "APIM is taking too long"
**Answer**: This is normal! APIM provisioning takes 30-45 minutes on first deployment.

### Issue: "Deployment failed"
**Solution**: Check the error message, common causes:
- Insufficient Azure permissions
- Resource name already taken (change `project_name` in terraform.tfvars)
- Subscription quota limits

## Local Development

Want to develop locally first?

```bash
# Using Docker
docker-compose up

# Or using Python
cd src
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Test locally:
```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/v1/tools
```

## Next Steps

1. **Customize Your MCP Server**  
   Edit `src/mcp_server.py` to add your own tools

2. **Configure APIM Policies**  
   See `infrastructure/apim-policies/README.md`

3. **Set Up Monitoring**  
   Configure alerts in Application Insights

4. **Enable CI/CD**  
   Configure GitHub Actions with secrets

5. **Add Custom Domain**  
   Configure custom domain for APIM

## Cost Management

**Development costs**: ~$68/month

To minimize costs:
```bash
# Stop the web app when not in use
az webapp stop \
  --resource-group <rg-name> \
  --name <app-name>

# Destroy everything when done testing
./scripts/cleanup.sh
```

## Getting Help

- 📖 [Full Architecture Docs](ARCHITECTURE.md)
- 🔧 [Terraform Guide](infrastructure/terraform/README.md)
- 🔒 [APIM Policies](infrastructure/apim-policies/README.md)
- 🐛 [Open an Issue](https://github.com/your-repo/issues)

## Clean Up

When you're done:

```bash
# This will destroy all resources
./scripts/cleanup.sh
```

---

**Congratulations! 🎉**  
You now have a production-ready MCP server running on Azure!
