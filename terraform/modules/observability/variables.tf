variable "owner" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "app_service_id" {
  type = string
}

variable "function_app_id" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "function_app_url" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "service_plan_id" {
  type = string
}

variable "prometheus_location" {
  description = "Azure region used by the Prometheus VM and its network."
  type        = string
}

variable "admin_source_cidr" {
  description = "Public IPv4 CIDR permitted to connect to Prometheus through SSH."
  type        = string
}

variable "app_service_hostname" {
  description = "App Service hostname scraped by Prometheus."
  type        = string
}

variable "prometheus_admin_username" {
  description = "Administrator username for the Prometheus VM."
  type        = string
}

variable "prometheus_ssh_public_key" {
  description = "SSH public key for the Prometheus VM."
  type        = string
  sensitive   = true
}