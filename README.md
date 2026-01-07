# MCP Server on Azure with API Management

A production-ready architecture for deploying Model Context Protocol (MCP) servers as Azure Web Apps, managed through Azure API Management (APIM).

## 🏗️ Architecture Overview

This project provides a complete infrastructure-as-code solution for deploying MCP servers on Azure with enterprise-grade features:

- **Azure Web Apps**: Host MCP server applications with Python runtime
- **Azure API Management**: Centralized API gateway for management, security, and monitoring
- **Application Insights**: Comprehensive logging and telemetry
- **Azure Key Vault**: Secure secrets management
- **Terraform**: Infrastructure as Code for reproducible deployments

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## 📁 Project Structure

```
.
├── ARCHITECTURE.md              # Detailed architecture documentation
├── README.md                    # This file
├── docker-compose.yml           # Local development with Docker
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── infrastructure/
│   ├── terraform/              # Terraform infrastructure code
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── resources.tf
│   │   ├── terraform.tfvars.example
│   │   └── README.md
│   └── apim-policies/          # APIM policy configurations
│       ├── rate-limiting-policy.xml
│       ├── jwt-validation-policy.xml
│       ├── ip-whitelist-policy.xml
│       ├── caching-policy.xml
│       ├── transformation-policy.xml
│       ├── production-policy.xml
│       └── README.md
├── scripts/
│   ├── deploy.sh               # Automated deployment script
│   ├── test-api.sh             # API testing script
│   └── cleanup.sh              # Resource cleanup script
└── src/
    ├── mcp_server.py           # MCP server implementation
    ├── app.py                  # Flask web wrapper
    ├── requirements.txt        # Python dependencies
    └── Dockerfile              # Container image definition
```

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
2. **Terraform**: [Install Terraform](https://developer.hashicorp.com/terraform/downloads)
3. **Azure Subscription**: Active Azure subscription
4. **Python 3.11+**: For local development

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd MCP-build

# Login to Azure
az login
az account set --subscription <subscription-id>
```

### 2. Configure Deployment

```bash
# Create Terraform variables file
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
nano terraform.tfvars
```

### 3. Deploy

#### Option A: Automated Deployment (Recommended)

```bash
# Run the deployment script from project root
./scripts/deploy.sh
```

#### Option B: Manual Deployment

```bash
# Deploy infrastructure
cd infrastructure/terraform
terraform init
terraform plan
terraform apply

# Build and deploy application
cd ../../src
zip -r deploy.zip . -x "*.pyc" -x "__pycache__/*"

# Get deployment details
RG_NAME=$(terraform output -raw resource_group_name)
APP_NAME=$(terraform output -raw web_app_name)

# Deploy to Web App
az webapp deployment source config-zip \
  --resource-group $RG_NAME \
  --name $APP_NAME \
  --src deploy.zip
```

### 4. Test Deployment

```bash
# Run automated tests
./scripts/test-api.sh

# Or test manually
curl https://<your-apim>.azure-api.net/mcp/api/v1/tools \
  -H "Ocp-Apim-Subscription-Key: <your-key>"
```

## 🔧 Local Development

### Using Docker

```bash
# Start the server
docker-compose up

# The server will be available at http://localhost:8000
curl http://localhost:8000/health
```

### Using Python Virtual Environment

```bash
# Create virtual environment
cd src
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the server
python app.py

# Test locally
curl http://localhost:8000/health
```

## 📊 Monitoring

### View Application Logs

```bash
# Stream logs
az webapp log tail \
  --resource-group <resource-group> \
  --name <webapp-name>

# Download logs
az webapp log download \
  --resource-group <resource-group> \
  --name <webapp-name>
```

### Application Insights

Access Application Insights through the Azure Portal or query using KQL:

```kql
// Request performance
requests
| where timestamp > ago(1h)
| summarize count(), avg(duration) by bin(timestamp, 5m)
| render timechart

// Error analysis
exceptions
| where timestamp > ago(24h)
| summarize count() by type, outerMessage
```

## 🔒 Security

### Authentication Options

1. **API Key (Default)**: Subscription key in APIM
2. **Azure AD / OAuth 2.0**: JWT token validation
3. **Client Certificates**: Mutual TLS authentication

### Applying Policies

```bash
# Apply a policy to your API
az apim api policy create \
  --resource-group <rg> \
  --service-name <apim-name> \
  --api-id <api-id> \
  --xml-policy @infrastructure/apim-policies/production-policy.xml
```

See [infrastructure/apim-policies/README.md](infrastructure/apim-policies/README.md) for detailed policy documentation.

## 💰 Cost Estimation

### Development Environment
- APIM Developer: ~$50/month
- App Service B1: ~$13/month
- Application Insights: ~$5/month
- **Total**: ~$68/month

### Production Environment
- APIM Standard: ~$750/month
- App Service S1 (x2): ~$140/month
- Application Insights: ~$20/month
- Key Vault: ~$5/month
- **Total**: ~$915/month

## 🔄 CI/CD Pipeline

GitHub Actions workflow is included at [.github/workflows/deploy.yml](.github/workflows/deploy.yml).

### Setup GitHub Secrets

```bash
# Create Azure service principal
az ad sp create-for-rbac \
  --name "mcp-server-github" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth

# Add to GitHub Secrets:
# - AZURE_CREDENTIALS (output from above command)
# - AZURE_RESOURCE_GROUP
# - AZURE_WEBAPP_NAME
```

## 📚 Available MCP Tools

The sample server includes these tools:

1. **echo**: Echoes back messages
2. **health_check**: Returns server health status
3. **get_environment**: Lists environment variables
4. **calculate**: Performs arithmetic operations

### Example: Call a Tool

```bash
curl -X POST https://<apim-url>/mcp/api/v1/tools/call \
  -H "Ocp-Apim-Subscription-Key: <key>" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "add",
      "a": 10,
      "b": 5
    }
  }'
```

## 🧹 Cleanup

To destroy all resources:

```bash
# Using cleanup script
./scripts/cleanup.sh

# Or manually with Terraform
cd infrastructure/terraform
terraform destroy
```

## 📖 Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture documentation
- [infrastructure/terraform/README.md](infrastructure/terraform/README.md) - Terraform deployment guide
- [infrastructure/apim-policies/README.md](infrastructure/apim-policies/README.md) - APIM policies documentation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is licensed under the MIT License.

## 🆘 Support

For issues and questions:
- Check the [ARCHITECTURE.md](ARCHITECTURE.md) documentation
- Review [infrastructure/terraform/README.md](infrastructure/terraform/README.md) for deployment issues
- Open an issue in the repository

## 🔗 References

- [Azure API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
