terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = var.service_plan_id

  https_only = true
  identity {
    type = "SystemAssigned"
  }
  site_config {
    always_on = true

    minimum_tls_version = "1.2"

    http2_enabled = true
    ftps_state    = "Disabled"
    application_stack {
      python_version = "3.11"
    }

    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 10
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
    APPLICATIONINSIGHTS_ROLE_NAME         = "log-analyser"
    SCM_DO_BUILD_DURING_DEPLOYMENT        = "true"
    OWNER                                 = var.owner
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
  tags = var.tags
}
