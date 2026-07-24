terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_storage_account" "fn_storage" {
  #checkov:skip=CKV_AZURE_59:The lab Function has no private endpoint or VNet integration and requires network access to its runtime storage.
  name                = "stfn${replace(var.owner, "-", "")}"
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false

  tags = merge(
    var.tags,
    {
      purpose = "function-storage"
    }
  )
}

resource "azurerm_linux_function_app" "fn" {
  name                = "fn-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id = var.service_plan_id

  storage_account_name       = azurerm_storage_account.fn_storage.name
  storage_account_access_key = azurerm_storage_account.fn_storage.primary_access_key

  https_only = true
  identity {
    type = "SystemAssigned"
  }
  site_config {

    http2_enabled = true
    ftps_state    = "Disabled"
    application_stack {
      python_version = "3.11"

    }
    health_check_path                 = "/api/http_trigger"
    health_check_eviction_time_in_min = 10
  }
  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
  }
  tags = var.tags
}
