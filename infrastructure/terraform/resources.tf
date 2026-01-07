# Generate random suffix for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local variables
locals {
  resource_suffix = "${var.environment}-${random_string.suffix.result}"
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Location    = var.location
    }
  )
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${local.resource_suffix}"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace for Application Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags
}

# Current Azure client configuration
data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project_name}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Purge"
    ]
  }

  tags = local.common_tags
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.project_name}-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.common_tags
}

# Web App for MCP Server
resource "azurerm_linux_web_app" "mcp_server" {
  name                = "app-${var.project_name}-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on = var.app_service_sku != "F1" # Free tier doesn't support always_on
    
    application_stack {
      python_version = "3.11"
    }

    health_check_path = "/health"
    
    cors {
      allowed_origins = var.allowed_origins
    }
  }

  app_settings = {
    "ENVIRONMENT"                      = var.environment
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "APPINSIGHTS_INSTRUMENTATIONKEY"   = azurerm_application_insights.main.instrumentation_key
    "SCM_DO_BUILD_DURING_DEPLOYMENT"   = "true"
    "ENABLE_ORYX_BUILD"                = "true"
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = local.common_tags
}

# Grant Web App access to Key Vault
resource "azurerm_key_vault_access_policy" "web_app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.mcp_server.identity[0].principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

# API Management
resource "azurerm_api_management" "main" {
  name                = "apim-${var.project_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "MCP Server"
  publisher_email     = "admin@example.com" # Change this to your email

  sku_name = "${var.apim_sku}_${var.apim_capacity}"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# APIM Logger (Application Insights)
resource "azurerm_api_management_logger" "main" {
  name                = "apim-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  application_insights {
    instrumentation_key = azurerm_application_insights.main.instrumentation_key
  }
}

# APIM API for MCP Server
resource "azurerm_api_management_api" "mcp" {
  name                = "mcp-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "MCP Server API"
  path                = "mcp"
  protocols           = ["https"]
  service_url         = "https://${azurerm_linux_web_app.mcp_server.default_hostname}"

  subscription_required = true

  import {
    content_format = "openapi+json"
    content_value  = jsonencode({
      openapi = "3.0.0"
      info = {
        title       = "MCP Server API"
        description = "Model Context Protocol Server API"
        version     = "1.0.0"
      }
      paths = {
        "/api/v1/tools" = {
          get = {
            summary     = "List available tools"
            description = "Returns a list of all available MCP tools"
            responses = {
              "200" = {
                description = "Successful response"
              }
            }
          }
        }
        "/api/v1/tools/call" = {
          post = {
            summary     = "Call a tool"
            description = "Execute a specific MCP tool"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      tool_name = {
                        type = "string"
                      }
                      arguments = {
                        type = "object"
                      }
                    }
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Successful response"
              }
            }
          }
        }
        "/health" = {
          get = {
            summary     = "Health check"
            description = "Check if the service is healthy"
            responses = {
              "200" = {
                description = "Service is healthy"
              }
            }
          }
        }
      }
    })
  }
}

# APIM Backend
resource "azurerm_api_management_backend" "mcp_server" {
  name                = "mcp-server-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_web_app.mcp_server.default_hostname}"
  
  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# APIM Product
resource "azurerm_api_management_product" "mcp" {
  product_id            = "mcp-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = "MCP Server"
  description           = "Access to MCP Server APIs"
  subscription_required = true
  approval_required     = false
  published             = true
}

# Associate API with Product
resource "azurerm_api_management_product_api" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  product_id          = azurerm_api_management_product.mcp.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
}

# APIM Policy - API Level
resource "azurerm_api_management_api_policy" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <rate-limit calls="100" renewal-period="60" />
        <quota calls="10000" renewal-period="86400" />
        <set-backend-service backend-id="mcp-server-backend" />
        <cors allow-credentials="false">
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
        </cors>
    </inbound>
    <backend>
        <forward-request timeout="30" />
    </backend>
    <outbound>
        <base />
        <set-header name="X-Powered-By" exists-action="delete" />
        <set-header name="X-AspNet-Version" exists-action="delete" />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

# APIM Diagnostic Settings
resource "azurerm_api_management_api_diagnostic" "mcp" {
  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.main.name
  api_management_name      = azurerm_api_management.main.name
  api_name                 = azurerm_api_management_api.mcp.name
  api_management_logger_id = azurerm_api_management_logger.main.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "accept",
      "origin"
    ]
  }

  frontend_response {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "content-length"
    ]
  }

  backend_request {
    body_bytes = 1024
    headers_to_log = [
      "content-type"
    ]
  }

  backend_response {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "content-length"
    ]
  }
}
