# APIM Policies Documentation

This directory contains various Azure API Management (APIM) policy configurations for securing and managing your MCP server API.

## Policy Files

### 1. `rate-limiting-policy.xml`
**Purpose**: Protect backend from overload by limiting request rates

**Features**:
- 100 calls per minute per subscription
- 10,000 calls per day quota
- Custom rate limit headers

**Use Case**: Apply to all APIs to prevent abuse

### 2. `jwt-validation-policy.xml`
**Purpose**: Authenticate requests using Azure AD JWT tokens

**Features**:
- Azure AD token validation
- Audience and issuer validation
- Role-based access control (RBAC)
- User identity extraction

**Configuration Required**:
```xml
<!-- Replace these placeholders: -->
{tenant-id}   - Your Azure AD tenant ID
{client-id}   - Your application (client) ID
```

**Use Case**: Enterprise applications with Azure AD integration

### 3. `ip-whitelist-policy.xml`
**Purpose**: Restrict API access to specific IP addresses

**Features**:
- Allow specific IPs or ranges
- Custom error responses for denied requests

**Configuration Required**:
```xml
<!-- Add your IP addresses: -->
<address>YOUR.IP.ADDRESS</address>
<address-range from="START.IP" to="END.IP" />
```

**Use Case**: Internal APIs or partner integrations

### 4. `caching-policy.xml`
**Purpose**: Improve performance through response caching

**Features**:
- 5-minute cache duration
- Query parameter variation
- Cache control headers

**Use Case**: Read-heavy APIs with static/semi-static data

### 5. `transformation-policy.xml`
**Purpose**: Transform requests and responses

**Features**:
- Add correlation IDs
- Request/response metadata
- Header manipulation
- Custom error formatting

**Use Case**: Standardize API behavior across multiple backends

### 6. `production-policy.xml`
**Purpose**: Complete production-ready policy combining all best practices

**Features**:
- Multiple authentication methods (JWT or API Key)
- Rate limiting and quotas
- CORS configuration
- Request/response caching
- Security headers
- Comprehensive logging
- Error handling

**Configuration Required**:
```xml
<!-- Update these sections: -->
1. JWT validation URLs (if using Azure AD)
2. CORS allowed origins
3. IP filtering (if needed)
4. Backend service ID
```

**Use Case**: Production deployments

## How to Apply Policies

### Method 1: Via Azure Portal

1. Navigate to your API Management instance
2. Select **APIs** → Select your API
3. Go to **Design** tab → Select operation or "All operations"
4. In the **Inbound processing** or **Outbound processing** section, click `</>` (code editor)
5. Paste the policy XML
6. Click **Save**

### Method 2: Via Azure CLI

```bash
# Apply policy to API
az apim api policy create \
  --resource-group <resource-group> \
  --service-name <apim-name> \
  --api-id <api-id> \
  --xml-policy @production-policy.xml

# Apply policy to specific operation
az apim api operation policy create \
  --resource-group <resource-group> \
  --service-name <apim-name> \
  --api-id <api-id> \
  --operation-id <operation-id> \
  --xml-policy @rate-limiting-policy.xml
```

### Method 3: Via Terraform

Already included in `../terraform/resources.tf`:

```hcl
resource "azurerm_api_management_api_policy" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  xml_content         = file("${path.module}/../apim-policies/production-policy.xml")
}
```

## Policy Scope Levels

APIM policies can be applied at different levels:

1. **Global (All APIs)**: Affects all APIs in the APIM instance
2. **Product**: Affects all APIs in a product
3. **API**: Affects all operations in an API
4. **Operation**: Affects a specific operation

**Evaluation Order**: Global → Product → API → Operation

## Common Policy Patterns

### Combining Policies

Policies from different scopes are combined. Use `<base />` to include parent policies:

```xml
<policies>
    <inbound>
        <base />  <!-- Includes parent policies -->
        <!-- Your custom policies here -->
    </inbound>
</policies>
```

### Conditional Logic

```xml
<choose>
    <when condition="@(context.Request.Method == "GET")">
        <!-- GET-specific policies -->
    </when>
    <when condition="@(context.Request.Method == "POST")">
        <!-- POST-specific policies -->
    </when>
    <otherwise>
        <!-- Other methods -->
    </otherwise>
</choose>
```

### Variables

```xml
<!-- Set variable -->
<set-variable name="myVar" value="@(DateTime.UtcNow.ToString())" />

<!-- Use variable -->
<set-header name="X-Timestamp" exists-action="override">
    <value>@((string)context.Variables["myVar"])</value>
</set-header>
```

## Testing Policies

### Test with curl

```bash
# Test with subscription key
curl "https://<apim-name>.azure-api.net/mcp/api/v1/tools" \
  -H "Ocp-Apim-Subscription-Key: <your-key>" \
  -v

# Test with JWT token
curl "https://<apim-name>.azure-api.net/mcp/api/v1/tools" \
  -H "Authorization: Bearer <jwt-token>" \
  -v

# Test rate limiting (send multiple requests)
for i in {1..150}; do
  curl "https://<apim-name>.azure-api.net/mcp/api/v1/tools" \
    -H "Ocp-Apim-Subscription-Key: <your-key>"
done
```

### Test in APIM Portal

1. Go to APIM Developer Portal
2. Navigate to your API
3. Click "Try it"
4. Provide subscription key or token
5. Send request and view response

## Monitoring Policies

### View Policy Execution in Application Insights

```kql
// Query for policy errors
traces
| where message contains "Policy"
| where severityLevel >= 3
| order by timestamp desc

// Query for rate limit hits
traces
| where message contains "rate-limit"
| summarize count() by bin(timestamp, 1m)
```

### Enable Policy Tracing

```bash
# Enable tracing (for debugging only)
az apim api diagnostic update \
  --resource-group <rg> \
  --service-name <apim> \
  --api-id <api-id> \
  --diagnostic-id applicationinsights \
  --verbosity verbose
```

## Best Practices

1. **Start Simple**: Begin with basic policies and add complexity as needed
2. **Use Base Tag**: Always include `<base />` to maintain parent policies
3. **Error Handling**: Always implement `<on-error>` section
4. **Logging**: Use correlation IDs for request tracking
5. **Performance**: Cache when appropriate, but avoid caching sensitive data
6. **Security**: 
   - Always use HTTPS
   - Validate all inputs
   - Remove sensitive headers
   - Implement authentication
7. **Testing**: Test policies in development before production
8. **Documentation**: Document custom policies and their purpose

## Common Issues and Solutions

### Issue: Policy not being applied
**Solution**: 
- Check policy scope (Global → Product → API → Operation)
- Verify `<base />` tag placement
- Clear APIM cache

### Issue: Rate limit not working
**Solution**:
- Ensure correct subscription key is used
- Check counter-key expression
- Verify renewal period

### Issue: JWT validation failing
**Solution**:
- Verify OpenID config URL
- Check audience and issuer values
- Ensure token is not expired
- Validate token format (Bearer token)

### Issue: CORS errors
**Solution**:
- Add proper allowed-origins
- Include OPTIONS method
- Check expose-headers configuration

## Policy Expression Reference

### Common Context Properties

```csharp
context.Request.Method          // GET, POST, etc.
context.Request.Url             // Full URL
context.Request.IpAddress       // Client IP
context.Request.Headers         // Request headers
context.Response.StatusCode     // HTTP status code
context.User.Id                 // User identifier
context.Subscription.Id         // Subscription ID
context.Api.Name                // API name
context.Operation.Name          // Operation name
```

### Common Functions

```csharp
DateTime.UtcNow                 // Current UTC time
Guid.NewGuid()                  // Generate new GUID
context.Variables["name"]       // Get variable
body.As<JObject>()             // Parse JSON body
```

## Additional Resources

- [APIM Policy Reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [Policy Expressions](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions)
- [APIM Best Practices](https://learn.microsoft.com/azure/api-management/api-management-best-practices)
- [Error Handling](https://learn.microsoft.com/azure/api-management/api-management-error-handling-policies)
