# API Examples

Complete examples for interacting with your deployed MCP server.

## Prerequisites

```bash
# Set these variables from your deployment
export APIM_URL="https://<your-apim>.azure-api.net"
export SUBSCRIPTION_KEY="<your-subscription-key>"
export WEB_APP_URL="https://<your-app>.azurewebsites.net"
```

## Getting Your Credentials

### Get APIM Gateway URL
```bash
# From deployment outputs
cat deployment-outputs.json | jq -r '.apim_gateway_url.value'

# Or from Azure CLI
az apim list --query "[].{name:name, url:gatewayUrl}" -o table
```

### Get Subscription Key
```bash
# From deployment outputs and Azure CLI
RESOURCE_GROUP=$(cat deployment-outputs.json | jq -r '.resource_group_name.value')
APIM_NAME=$(cat deployment-outputs.json | jq -r '.apim_gateway_url.value' | cut -d'/' -f3 | cut -d'.' -f1)

az apim subscription list \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --query "[0].{Name:name, PrimaryKey:primaryKey}" -o table
```

## Direct Web App Access (No APIM)

### Health Check
```bash
curl -X GET "$WEB_APP_URL/health" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "status": "healthy",
  "service": "mcp-server"
}
```

### List Tools
```bash
curl -X GET "$WEB_APP_URL/api/v1/tools" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "echo",
        "description": "Echoes back the input message",
        "inputSchema": { ... }
      },
      ...
    ]
  },
  "id": 1
}
```

## APIM Gateway Access (Production)

### Health Check via APIM
```bash
curl -X GET "$APIM_URL/mcp/health" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json"
```

### List Available Tools
```bash
curl -X GET "$APIM_URL/mcp/api/v1/tools" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  | jq '.'
```

**Pretty Print with jq:**
```bash
curl -s "$APIM_URL/mcp/api/v1/tools" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  | jq '.result.tools[] | {name: .name, description: .description}'
```

## Tool Examples

### 1. Echo Tool

**Request:**
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "echo",
    "arguments": {
      "message": "Hello from MCP Server!"
    }
  }' | jq '.'
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Echo: Hello from MCP Server!"
      }
    ]
  },
  "id": 1
}
```

### 2. Health Check Tool

**Request:**
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "health_check",
    "arguments": {}
  }' | jq '.'
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\n  \"status\": \"healthy\",\n  \"server\": \"azure-mcp-server\",\n  \"version\": \"1.0.0\",\n  \"environment\": \"production\"\n}"
      }
    ]
  },
  "id": 1
}
```

### 3. Calculate Tool - Addition

**Request:**
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "add",
      "a": 42,
      "b": 58
    }
  }' | jq '.'
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Result: 100"
      }
    ]
  },
  "id": 1
}
```

### 4. Calculate Tool - Multiplication

**Request:**
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "multiply",
      "a": 7,
      "b": 8
    }
  }' | jq '.'
```

### 5. Calculate Tool - Division

**Request:**
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "divide",
      "a": 100,
      "b": 4
    }
  }' | jq '.'
```

### 6. Get Environment Variables

**Request:**
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "get_environment",
    "arguments": {
      "prefix": "APPSETTING_"
    }
  }' | jq '.'
```

## Testing Error Handling

### Invalid Tool Name
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "nonexistent_tool",
    "arguments": {}
  }' | jq '.'
```

### Missing Required Arguments
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "add"
    }
  }' | jq '.'
```

### Division by Zero
```bash
curl -X POST "$APIM_URL/mcp/api/v1/tools/call" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "calculate",
    "arguments": {
      "operation": "divide",
      "a": 10,
      "b": 0
    }
  }' | jq '.'
```

## Testing APIM Features

### Test Rate Limiting
```bash
# Send 110 requests rapidly (rate limit is 100/min)
for i in {1..110}; do
  echo "Request $i"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" \
    "$APIM_URL/mcp/api/v1/tools" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY"
  sleep 0.1
done
```

**Expected**: First 100 succeed (200), then 429 (Too Many Requests)

### Test Authentication
```bash
# Without subscription key (should fail)
curl -X GET "$APIM_URL/mcp/api/v1/tools" \
  -H "Content-Type: application/json"
```

**Expected Response:** HTTP 401 or 403

### Test CORS
```bash
curl -X OPTIONS "$APIM_URL/mcp/api/v1/tools" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -v
```

**Expected**: CORS headers in response

## Performance Testing

### Simple Load Test
```bash
# Install Apache Bench
# sudo apt-get install apache2-utils

# 1000 requests, 10 concurrent
ab -n 1000 -c 10 \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/mcp/api/v1/tools"
```

### Using wrk
```bash
# Install wrk
# git clone https://github.com/wg/wrk.git
# cd wrk && make

wrk -t4 -c100 -d30s \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/mcp/api/v1/tools"
```

## Python Examples

### Using requests library
```python
import requests
import json

APIM_URL = "https://<your-apim>.azure-api.net"
SUBSCRIPTION_KEY = "<your-key>"

headers = {
    "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY,
    "Content-Type": "application/json"
}

# List tools
response = requests.get(
    f"{APIM_URL}/mcp/api/v1/tools",
    headers=headers
)
print(json.dumps(response.json(), indent=2))

# Call echo tool
payload = {
    "tool_name": "echo",
    "arguments": {
        "message": "Hello from Python!"
    }
}

response = requests.post(
    f"{APIM_URL}/mcp/api/v1/tools/call",
    headers=headers,
    json=payload
)
print(json.dumps(response.json(), indent=2))
```

## JavaScript Examples

### Using fetch (Node.js or Browser)
```javascript
const APIM_URL = "https://<your-apim>.azure-api.net";
const SUBSCRIPTION_KEY = "<your-key>";

// List tools
async function listTools() {
  const response = await fetch(`${APIM_URL}/mcp/api/v1/tools`, {
    headers: {
      "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY,
      "Content-Type": "application/json"
    }
  });
  
  const data = await response.json();
  console.log(JSON.stringify(data, null, 2));
}

// Call tool
async function callTool(toolName, args) {
  const response = await fetch(`${APIM_URL}/mcp/api/v1/tools/call`, {
    method: "POST",
    headers: {
      "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      tool_name: toolName,
      arguments: args
    })
  });
  
  const data = await response.json();
  console.log(JSON.stringify(data, null, 2));
}

// Example usage
listTools();
callTool("calculate", { operation: "add", a: 5, b: 3 });
```

## PowerShell Examples

```powershell
$APIM_URL = "https://<your-apim>.azure-api.net"
$SUBSCRIPTION_KEY = "<your-key>"

$headers = @{
    "Ocp-Apim-Subscription-Key" = $SUBSCRIPTION_KEY
    "Content-Type" = "application/json"
}

# List tools
$response = Invoke-RestMethod `
    -Uri "$APIM_URL/mcp/api/v1/tools" `
    -Headers $headers `
    -Method Get

$response | ConvertTo-Json -Depth 10

# Call tool
$body = @{
    tool_name = "echo"
    arguments = @{
        message = "Hello from PowerShell!"
    }
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri "$APIM_URL/mcp/api/v1/tools/call" `
    -Headers $headers `
    -Method Post `
    -Body $body

$response | ConvertTo-Json -Depth 10
```

## Monitoring Examples

### Query Application Insights

```bash
# Get Application Insights App ID
APP_ID=$(az monitor app-insights component show \
  --resource-group $RESOURCE_GROUP \
  --app <app-insights-name> \
  --query appId -o tsv)

# Query requests
az monitor app-insights query \
  --app $APP_ID \
  --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode" \
  --output table
```

### View Logs
```bash
# Stream Web App logs
az webapp log tail \
  --resource-group $RESOURCE_GROUP \
  --name <webapp-name>

# Download logs
az webapp log download \
  --resource-group $RESOURCE_GROUP \
  --name <webapp-name> \
  --log-file webapp-logs.zip
```

## Troubleshooting Commands

### Check Web App Status
```bash
az webapp show \
  --resource-group $RESOURCE_GROUP \
  --name <webapp-name> \
  --query "{status: state, url: defaultHostName}" -o table
```

### Restart Web App
```bash
az webapp restart \
  --resource-group $RESOURCE_GROUP \
  --name <webapp-name>
```

### Check APIM Status
```bash
az apim show \
  --resource-group $RESOURCE_GROUP \
  --name <apim-name> \
  --query "{status: provisioningState, gateway: gatewayUrl}" -o table
```

## Best Practices

1. **Always use environment variables** for credentials
2. **Check response status codes** before parsing JSON
3. **Implement retry logic** for production applications
4. **Use correlation IDs** for request tracking
5. **Monitor rate limits** in response headers
6. **Cache responses** when appropriate
7. **Handle errors gracefully**
8. **Log all API calls** in production

## Additional Resources

- [APIM REST API Reference](https://learn.microsoft.com/rest/api/apimanagement/)
- [MCP Specification](https://modelcontextprotocol.io/)
- [curl Documentation](https://curl.se/docs/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
