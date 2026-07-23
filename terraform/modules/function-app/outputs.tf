output "default_hostname" {
  value = azurerm_linux_function_app.fn.default_hostname
}

output "function_app_id" {
  description = "ID of the Function App."
  value       = azurerm_linux_function_app.fn.id
}