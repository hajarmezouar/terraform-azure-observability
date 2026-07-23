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

#resource #"azurerm_application_insights_standard_availability#_test" "app_health" {
#  name                    = "avail-app-${var.owner}#"
#  resource_group_name     = var.resource_group_name
#  location                = var.location
#  application_insights_id = #azurerm_application_insights.app.id
#
#  geo_locations = [
#    "emea-fr-pra-edge",
#    "emea-nl-ams-azr",
#    "emea-gb-db3-azr"
#  ]
#
#  frequency = 300
#  timeout   = 30
#
#  tags = var.tags
#
#  request {
#    url = "${var.app_service_url}/health"
#  }
#
#  validation_rules {
#    expected_status_code = 200
#  }
#}

#resource #"azurerm_application_insights_standard_availability#_test" "function_health" {
#  name                    = "avail-func-${var.#owner}"
#  resource_group_name     = var.resource_group_name
#  location                = var.location
#  application_insights_id = #azurerm_application_insights.func.id
#
#  geo_locations = [
#    "emea-fr-pra-edge",
#    "emea-nl-ams-azr",
#    "emea-gb-db3-azr"
#  ]
#
#  frequency = 300
#  timeout   = 30
#
#  tags = var.tags
#
#  request {
#    url = "${var.function_app_url}/api/#http_trigger"
#  }
#
#  validation_rules {
#    expected_status_code = 200
#  }
#}

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

  scopes = [var.app_service_id]

  severity    = 1
  frequency   = "PT1M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
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
