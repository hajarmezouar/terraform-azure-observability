output "app_service_url" {
  description = "Public URL of the Azure App Service."
  value       = "https://${module.app_service.default_hostname}"
}

output "function_app_url" {
  description = "Public URL of the Azure Function App."
  value       = "https://${module.function_app.default_hostname}"
}

output "container_fqdn" {
  description = "Public FQDN of the Azure Container Instance."
  value       = "http://${module.container.fqdn}"
}

output "storage_account_name" {
  description = "Name of the Azure Storage Account."
  value       = module.storage.storage_account_name
}

output "vnet_id" {
  description = "ID of the Azure Virtual Network."
  value       = module.network.vnet_id
}

output "frontend_subnet_id" {
  description = "ID of the frontend subnet."
  value       = module.network.subnet_frontend_id
}

output "backend_subnet_id" {
  description = "ID of the backend subnet."
  value       = module.network.subnet_backend_id
}