variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "mcpserver"
}

variable "apim_sku" {
  description = "APIM SKU (Developer, Basic, Standard, Premium)"
  type        = string
  default     = "Developer"
}

variable "apim_capacity" {
  description = "APIM capacity units"
  type        = number
  default     = 1
}

variable "app_service_sku" {
  description = "App Service Plan SKU"
  type        = string
  default     = "B1"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MCP-Server"
    ManagedBy   = "Terraform"
  }
}

variable "allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "enable_vnet" {
  description = "Enable VNet integration"
  type        = bool
  default     = false
}
