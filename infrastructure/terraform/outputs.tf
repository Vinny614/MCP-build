output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "apim_gateway_url" {
  description = "APIM Gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_management_url" {
  description = "APIM Management/Portal URL"
  value       = azurerm_api_management.main.management_api_url
}

output "apim_developer_portal_url" {
  description = "APIM Developer Portal URL"
  value       = azurerm_api_management.main.developer_portal_url
}

output "web_app_name" {
  description = "Web App name"
  value       = azurerm_linux_web_app.mcp_server.name
}

output "web_app_default_hostname" {
  description = "Web App default hostname"
  value       = azurerm_linux_web_app.mcp_server.default_hostname
}

output "web_app_url" {
  description = "Web App URL"
  value       = "https://${azurerm_linux_web_app.mcp_server.default_hostname}"
}

output "application_insights_instrumentation_key" {
  description = "Application Insights Instrumentation Key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights Connection String"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "deployment_instructions" {
  description = "Next steps for deployment"
  value = <<-EOT
    
    Deployment Complete! Next steps:
    
    1. Access APIM Developer Portal:
       ${azurerm_api_management.main.developer_portal_url}
    
    2. Deploy your MCP Server code:
       az webapp deployment source config-zip \
         --resource-group ${azurerm_resource_group.main.name} \
         --name ${azurerm_linux_web_app.mcp_server.name} \
         --src <path-to-your-zip-file>
    
    3. Test the API:
       curl ${azurerm_api_management.main.gateway_url}/mcp/v1/tools \
         -H "Ocp-Apim-Subscription-Key: <your-subscription-key>"
    
    4. Get APIM Subscription Key:
       az apim subscription list \
         --resource-group ${azurerm_resource_group.main.name} \
         --service-name ${azurerm_api_management.main.name}
    
    5. View Application Insights:
       https://portal.azure.com/#resource${azurerm_application_insights.main.id}
  EOT
}
