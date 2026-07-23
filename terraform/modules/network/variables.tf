variable "owner" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "admin_source_cidr" {
  description = "Public IPv4 CIDR allowed to connect through SSH."
  type        = string
}