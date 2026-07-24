output "law_id" {
  value = azurerm_log_analytics_workspace.law.id
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.app.connection_string
  sensitive = true
}

output "func_insights_connection_string" {
  value     = azurerm_application_insights.func.connection_string
  sensitive = true
}

output "prometheus_vm_id" {
  description = "Resource ID of the Prometheus virtual machine."
  value       = azurerm_linux_virtual_machine.prometheus.id
}

output "prometheus_public_ip" {
  description = "Public IP address used to administer the Prometheus VM."
  value       = azurerm_public_ip.prometheus.ip_address
}