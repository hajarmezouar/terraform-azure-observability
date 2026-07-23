resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = var.tags
}

resource "azurerm_application_insights" "app" {
  name                = "appi-${var.owner}-app"
  location            = var.location
  resource_group_name = var.resource_group_name

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.law.id

  tags = var.tags
}

resource "azurerm_application_insights" "func" {
  name                = "appi-${var.owner}-func"
  location            = var.location
  resource_group_name = var.resource_group_name

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.law.id

  tags = var.tags
}

# Azure Monitor Workspace stores the Prometheus-compatible metrics.
resource "azurerm_monitor_workspace" "prometheus" {
  name                = "amw-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = var.location

  public_network_access_enabled = true

  tags = var.tags
}

# Public ingestion endpoint used by Prometheus remote_write.
resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                = "dce-${var.owner}-prometheus"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"

  public_network_access_enabled = true

  tags = var.tags
}

# Routes Microsoft-PrometheusMetrics to the Azure Monitor Workspace.
resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "dcr-${var.owner}-prometheus"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
  kind                        = "Linux"

  data_sources {
    prometheus_forwarder {
      name    = "prometheus-forwarder"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus.id
      name               = "managed-prometheus"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["managed-prometheus"]
  }

  tags = var.tags
}

# Public IP used for administrative SSH access to the Prometheus VM.
resource "azurerm_public_ip" "prometheus" {
  name                = "pip-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network interface attached to the existing backend subnet.
resource "azurerm_network_interface" "prometheus" {
  name                = "nic-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.prometheus_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.prometheus.id
  }

  tags = var.tags
}

locals {
  prometheus_remote_write_url = format(
    "%s/dataCollectionRules/%s/streams/Microsoft-PrometheusMetrics/api/v1/write?api-version=2023-04-24",
    azurerm_monitor_data_collection_endpoint.prometheus.metrics_ingestion_endpoint,
    azurerm_monitor_data_collection_rule.prometheus.immutable_id
  )
}

resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-app-${var.owner}"
  target_resource_id         = var.app_service_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "diag-func-${var.owner}"
  target_resource_id         = var.function_app_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-storage-${var.owner}"
  target_resource_id         = "${var.storage_account_id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}


resource "azurerm_monitor_action_group" "team" {
  name                = "ag-${var.owner}"
  resource_group_name = var.resource_group_name
  short_name          = "team"

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "http5xx" {
  name                = "alert-http5xx-${var.owner}"
  resource_group_name = var.resource_group_name

  scopes = [var.app_service_id]

  severity    = 1
  frequency   = "PT1M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "cpu" {
  name                = "alert-cpu-${var.owner}"
  resource_group_name = var.resource_group_name

  scopes = [var.service_plan_id]

  severity    = 1
  frequency   = "PT1M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }

  tags = var.tags
}

