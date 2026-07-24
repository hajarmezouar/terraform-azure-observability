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
  description = "Name of the Azure App Service Plan to create."
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

variable "alert_email" {
  description = "Email address receiving Azure Monitor alerts."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must contain a valid email address."
  }
}

variable "prometheus_admin_username" {
  description = "Administrator username for the Prometheus virtual machine."
  type        = string
  default     = "azureadmin"

  validation {
    condition     = length(var.prometheus_admin_username) >= 3
    error_message = "prometheus_admin_username must contain at least three characters."
  }
}

variable "prometheus_ssh_public_key" {
  description = "SSH public key used to access the Prometheus virtual machine."
  type        = string
  sensitive   = true

  validation {
    condition = (
      startswith(var.prometheus_ssh_public_key, "ssh-ed25519 ") ||
      startswith(var.prometheus_ssh_public_key, "ssh-rsa ")
    )
    error_message = "prometheus_ssh_public_key must be an OpenSSH public key."
  }
}

variable "admin_source_cidr" {
  description = "Public IPv4 CIDR allowed to connect to the Prometheus VM through SSH."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_source_cidr, 0))
    error_message = "admin_source_cidr must be a valid CIDR, for example 203.0.113.10/32."
  }
}

variable "prometheus_location" {
  description = "Azure region used by the Prometheus VM and its network."
  type        = string
  default     = "polandcentral"
}
