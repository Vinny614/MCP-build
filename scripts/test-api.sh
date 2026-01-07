#!/bin/bash

# Test script for deployed MCP Server
# Tests API endpoints through APIM

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Load deployment outputs
if [ ! -f deployment-outputs.json ]; then
    print_error "deployment-outputs.json not found. Please deploy infrastructure first."
    exit 1
fi

APIM_URL=$(jq -r '.apim_gateway_url.value' deployment-outputs.json)
WEB_APP_URL=$(jq -r '.web_app_url.value' deployment-outputs.json)

# Get subscription key
print_info "Getting APIM subscription key..."
RESOURCE_GROUP=$(jq -r '.resource_group_name.value' deployment-outputs.json)
APIM_NAME=$(echo "$APIM_URL" | cut -d'/' -f3 | cut -d'.' -f1)

SUBSCRIPTION_KEY=$(az apim subscription list \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --query "[0].primaryKey" -o tsv)

if [ -z "$SUBSCRIPTION_KEY" ]; then
    print_error "Could not retrieve subscription key"
    exit 1
fi

print_success "Retrieved subscription key"

echo ""
print_info "Running API tests..."
echo ""

# Test 1: Health check (direct to Web App)
print_info "Test 1: Web App health check"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_APP_URL/health")
if [ "$RESPONSE" -eq 200 ]; then
    print_success "Web App health check passed (HTTP $RESPONSE)"
else
    print_error "Web App health check failed (HTTP $RESPONSE)"
fi

# Test 2: List tools (through APIM)
print_info "Test 2: List tools via APIM"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/mcp/api/v1/tools")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_success "List tools passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    print_error "List tools failed (HTTP $HTTP_CODE)"
    echo "$BODY"
fi

echo ""

# Test 3: Call echo tool
print_info "Test 3: Call echo tool"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "tool_name": "echo",
        "arguments": {
            "message": "Hello from test script!"
        }
    }' \
    "$APIM_URL/mcp/api/v1/tools/call")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_success "Echo tool passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    print_error "Echo tool failed (HTTP $HTTP_CODE)"
    echo "$BODY"
fi

echo ""

# Test 4: Call health_check tool
print_info "Test 4: Call health_check tool"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "tool_name": "health_check",
        "arguments": {}
    }' \
    "$APIM_URL/mcp/api/v1/tools/call")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_success "Health check tool passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    print_error "Health check tool failed (HTTP $HTTP_CODE)"
    echo "$BODY"
fi

echo ""

# Test 5: Call calculate tool
print_info "Test 5: Call calculate tool"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "tool_name": "calculate",
        "arguments": {
            "operation": "add",
            "a": 15,
            "b": 27
        }
    }' \
    "$APIM_URL/mcp/api/v1/tools/call")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_success "Calculate tool passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    print_error "Calculate tool failed (HTTP $HTTP_CODE)"
    echo "$BODY"
fi

echo ""

# Test 6: Test rate limiting
print_info "Test 6: Rate limiting test (sending 105 requests)"
RATE_LIMIT_HIT=false

for i in {1..105}; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
        "$APIM_URL/mcp/api/v1/tools")
    
    if [ "$RESPONSE" -eq 429 ]; then
        RATE_LIMIT_HIT=true
        break
    fi
done

if [ "$RATE_LIMIT_HIT" = true ]; then
    print_success "Rate limiting is working (HTTP 429 received)"
else
    print_error "Rate limiting may not be configured correctly"
fi

echo ""

# Test 7: Test without subscription key
print_info "Test 7: Unauthorized access (no subscription key)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$APIM_URL/mcp/api/v1/tools")

if [ "$RESPONSE" -eq 401 ] || [ "$RESPONSE" -eq 403 ]; then
    print_success "Authorization check passed (HTTP $RESPONSE)"
else
    print_error "Authorization check failed - endpoint accessible without key (HTTP $RESPONSE)"
fi

echo ""
print_info "==================================================================="
print_info "                       TEST SUMMARY                                "
print_info "==================================================================="
print_info "APIM Gateway URL: $APIM_URL"
print_info "Web App URL: $WEB_APP_URL"
print_info "Subscription Key: ${SUBSCRIPTION_KEY:0:10}..."
print_info "==================================================================="
echo ""

print_success "All tests completed!"
