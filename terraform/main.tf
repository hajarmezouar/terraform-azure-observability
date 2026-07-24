# ──────────────────────────────────────────────────────────────────────────────
# main.tf — Azure infrastructure managed by Terraform
# ──────────────────────────────────────────────────────────────────────────────

# ── Common tags ───────────────────────────────────────────────────────────────

locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = "tp"
      owner       = var.owner
    },
    var.tags
  )
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = local.tags
}

# ── App Service Plan ──────────────────────────────────────────────────────────

resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type  = "Linux"
  sku_name = var.app_service_plan_sku

  tags = local.tags
}

# ── Storage ───────────────────────────────────────────────────────────────────

module "storage" {
  source = "./modules/storage"

  owner               = var.owner
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags
}

# ── App Service ───────────────────────────────────────────────────────────────

module "app_service" {
  source = "./modules/app-service"

  owner                                  = var.owner
  resource_group_name                    = azurerm_resource_group.rg.name
  location                               = azurerm_resource_group.rg.location
  service_plan_id                        = azurerm_service_plan.plan.id
  tags                                   = local.tags
  application_insights_connection_string = module.observability.app_insights_connection_string
}

# ── Function App ──────────────────────────────────────────────────────────────

module "function_app" {
  source = "./modules/function-app"

  owner                                  = var.owner
  resource_group_name                    = azurerm_resource_group.rg.name
  location                               = azurerm_resource_group.rg.location
  service_plan_id                        = azurerm_service_plan.plan.id
  tags                                   = local.tags
  application_insights_connection_string = module.observability.func_insights_connection_string
}

# ── Container Instance ────────────────────────────────────────────────────────

module "container" {
  source = "./modules/container"

  owner               = var.owner
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags
}

# ── Network ───────────────────────────────────────────────────────────────────

module "network" {
  source = "./modules/network"

  owner               = var.owner
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags
}

# ── Observability ───────────────────────────────────────────────────────────────────
module "observability" {
  source = "./modules/observability"

  owner               = var.owner
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags

  app_service_id     = module.app_service.app_service_id
  function_app_id    = module.function_app.function_app_id
  storage_account_id = module.storage.storage_account_id
  service_plan_id    = azurerm_service_plan.plan.id

  app_service_hostname = module.app_service.default_hostname
  function_app_url     = "https://${module.function_app.default_hostname}"

  prometheus_location       = var.prometheus_location
  admin_source_cidr         = var.admin_source_cidr
  prometheus_admin_username = var.prometheus_admin_username
  prometheus_ssh_public_key = var.prometheus_ssh_public_key

  alert_email = var.alert_email
}