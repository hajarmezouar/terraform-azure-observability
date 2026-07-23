variable "owner" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "service_plan_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string."
  type        = string
}