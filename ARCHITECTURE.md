# MCP Server on Azure Architecture

## Overview
This architecture deploys Model Context Protocol (MCP) servers as Azure Web Apps, with Azure API Management (APIM) providing API gateway functionality, security, and management capabilities.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure Subscription                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Resource Group                         │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────┐            │  │
│  │  │   Azure API Management (APIM)            │            │  │
│  │  │   - Developer/Standard SKU               │            │  │
│  │  │   - API Gateway                          │            │  │
│  │  │   - Rate Limiting                        │            │  │
│  │  │   - Authentication                       │            │  │
│  │  │   - Logging & Monitoring                 │            │  │
│  │  └──────────────┬───────────────────────────┘            │  │
│  │                 │                                          │  │
│  │                 │ Routes to backends                      │  │
│  │                 │                                          │  │
│  │  ┌──────────────┴───────────────────────────────────┐    │  │
│  │  │                                                    │    │  │
│  │  │    ┌─────────────────┐    ┌─────────────────┐   │    │  │
│  │  │    │   App Service   │    │   App Service   │   │    │  │
│  │  │    │   Plan (Linux)  │    │   Plan (Linux)  │   │    │  │
│  │  │    │   - B1/S1 SKU   │    │   - B1/S1 SKU   │   │    │  │
│  │  │    └────────┬────────┘    └────────┬────────┘   │    │  │
│  │  │             │                      │             │    │  │
│  │  │    ┌────────▼────────┐    ┌───────▼────────┐   │    │  │
│  │  │    │  MCP Server 1   │    │  MCP Server 2  │   │    │  │
│  │  │    │  (Web App)      │    │  (Web App)     │   │    │  │
│  │  │    │  - Python 3.11  │    │  - Python 3.11 │   │    │  │
│  │  │    │  - MCP Runtime  │    │  - MCP Runtime │   │    │  │
│  │  │    └─────────────────┘    └────────────────┘   │    │  │
│  │  │                                                  │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │   Application Insights                           │    │  │
│  │  │   - Logging & Telemetry                          │    │  │
│  │  │   - Performance Monitoring                       │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │   Key Vault                                      │    │  │
│  │  │   - API Keys                                     │    │  │
│  │  │   - Secrets Management                           │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘

External Clients
       │
       ▼
[APIM Gateway URL]
       │
       ▼
[MCP Servers]
```

## Components

### 1. Azure API Management (APIM)
**Purpose**: API Gateway and Management Layer

**Features**:
- **Routing**: Routes requests to appropriate MCP server backends
- **Security**: API key validation, OAuth2, JWT validation
- **Rate Limiting**: Throttling policies to protect backends
- **Transformation**: Request/response transformation
- **Monitoring**: Built-in analytics and logging
- **Versioning**: API version management
- **Developer Portal**: API documentation and testing

**SKU Options**:
- **Developer**: $50/month - For development/testing
- **Basic**: $150/month - Production with SLA
- **Standard**: $750/month - Production with advanced features

### 2. Azure App Service (Web Apps)
**Purpose**: Host MCP Server Applications

**Configuration**:
- **Runtime**: Python 3.11+
- **OS**: Linux
- **Deployment**: Git, Docker, or ZIP deployment
- **Scaling**: Manual or autoscale based on metrics
- **Networking**: VNet integration (optional)

**SKU Options**:
- **Free (F1)**: Development only, no SLA
- **Basic (B1)**: $13/month - Production workloads
- **Standard (S1)**: $70/month - Production with staging slots

### 3. Application Insights
**Purpose**: Monitoring and Diagnostics

**Features**:
- Request tracking
- Performance metrics
- Failure analysis
- Custom telemetry
- Distributed tracing

### 4. Azure Key Vault
**Purpose**: Secrets Management

**Stores**:
- API keys
- Connection strings
- Certificates
- Encryption keys

## Request Flow

1. **Client Request**: Client sends request to APIM gateway URL
   ```
   POST https://<apim-name>.azure-api.net/mcp/v1/tools/call
   ```

2. **APIM Processing**:
   - Validates API key/authentication
   - Applies rate limiting policies
   - Logs request to Application Insights
   - Routes to appropriate backend

3. **Backend Processing**:
   - Web App receives request
   - MCP server processes request
   - Returns response

4. **Response Flow**:
   - APIM applies response policies
   - Logs response metrics
   - Returns to client

## Security Model

### Authentication Options

1. **API Key (Subscription Key)**
   ```http
   Ocp-Apim-Subscription-Key: <key>
   ```

2. **OAuth 2.0 / Azure AD**
   ```http
   Authorization: Bearer <token>
   ```

3. **Client Certificate**
   - Mutual TLS authentication

### Network Security

1. **IP Whitelisting**: Restrict access by IP address
2. **VNet Integration**: Place services in private VNet
3. **Private Endpoints**: Direct private connectivity
4. **NSG Rules**: Network security group rules

### APIM Policies

```xml
<policies>
    <inbound>
        <!-- Rate limiting -->
        <rate-limit calls="100" renewal-period="60" />
        
        <!-- Validate JWT -->
        <validate-jwt header-name="Authorization">
            <openid-config url="..." />
        </validate-jwt>
        
        <!-- Set backend URL -->
        <set-backend-service base-url="https://mcp-server.azurewebsites.net" />
    </inbound>
    <backend>
        <forward-request timeout="30" />
    </backend>
    <outbound>
        <!-- Add CORS headers -->
        <cors>
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
        </cors>
    </outbound>
    <on-error>
        <log-to-eventhub />
    </on-error>
</policies>
```

## Deployment Options

### Option 1: Terraform
- Infrastructure as Code
- Version controlled
- Reproducible deployments
- See `/infrastructure/terraform/`

### Option 2: Bicep
- Native Azure IaC
- Better Azure integration
- See `/infrastructure/bicep/`

### Option 3: Azure Portal
- Manual deployment
- Good for learning/testing
- Not recommended for production

## Scaling Strategy

### Horizontal Scaling
- Add more App Service instances
- Use APIM load balancing
- Configure autoscale rules

### Vertical Scaling
- Upgrade App Service Plan SKU
- Increase APIM capacity units

### Example Autoscale Rule
```json
{
  "metric": "CpuPercentage",
  "threshold": 70,
  "direction": "Increase",
  "instanceCount": 1,
  "cooldown": "PT5M"
}
```

## Cost Estimation

### Minimal Setup (Development)
- APIM Developer: $50/month
- App Service B1: $13/month
- Application Insights: ~$5/month
- **Total**: ~$68/month

### Production Setup
- APIM Standard: $750/month
- App Service S1 (x2): $140/month
- Application Insights: ~$20/month
- Key Vault: ~$5/month
- **Total**: ~$915/month

## Monitoring & Observability

### Key Metrics to Monitor

1. **APIM Metrics**:
   - Request count
   - Failed requests
   - Response time
   - Backend response time

2. **App Service Metrics**:
   - CPU percentage
   - Memory percentage
   - Response time
   - HTTP errors

3. **Application Insights**:
   - Request rate
   - Failed requests
   - Dependencies
   - Exceptions

### Alerts
- High error rate (>5%)
- Slow response time (>2s)
- High CPU usage (>80%)
- APIM throttling

## Best Practices

1. **Use Managed Identity**: Avoid storing credentials
2. **Enable HTTPS Only**: Enforce secure connections
3. **Implement Health Checks**: Monitor service availability
4. **Use Deployment Slots**: Zero-downtime deployments
5. **Enable Diagnostic Logs**: Comprehensive logging
6. **Implement Circuit Breaker**: Protect from cascading failures
7. **Version Your APIs**: Support multiple API versions
8. **Use Virtual Networks**: Isolate services
9. **Enable Backup**: Regular backups of configurations
10. **Tag Resources**: Organize and track costs

## Disaster Recovery

### Backup Strategy
- Export APIM configuration regularly
- Store in source control
- Automate deployments

### High Availability
- Deploy APIM in multiple regions (Premium SKU)
- Use Azure Traffic Manager
- Replicate data across regions

### Recovery Time Objective (RTO)
- Target: < 1 hour for critical services
- Use infrastructure as code for quick redeployment

## Next Steps

1. Deploy infrastructure using Terraform/Bicep
2. Configure APIM policies
3. Deploy MCP server application
4. Configure monitoring and alerts
5. Test end-to-end flow
6. Set up CI/CD pipeline
7. Document APIs in APIM portal
8. Perform load testing
9. Set up production monitoring
10. Create runbook for operations

## References

- [Azure API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
