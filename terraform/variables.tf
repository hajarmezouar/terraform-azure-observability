variable "owner" {
  description = "Unique owner identifier used to generate Azure resource names (lowercase letters, numbers and hyphens only)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.owner))
    error_message = "The owner must contain only lowercase letters, numbers and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group where all resources will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region where the infrastructure will be deployed."
  type        = string
  default     = "francecentral"
}

variable "app_service_plan_name" {
  description = "Name of the existing Azure App Service Plan used by the Web App."
  type        = string
}

variable "tags" {
  description = "Map of custom tags to apply to all Azure resources."
  type        = map(string)
  default     = {}
}

variable "app_service_plan_sku" {
  description = "App Service Plan SKU"

  type = string

  default = "B1"
}