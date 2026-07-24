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

# Checks the App Service /health endpoint from three Azure regions.
resource "azurerm_application_insights_standard_web_test" "app_health" {
  name                    = "avail-app-${var.owner}"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.app.id

  enabled   = true
  frequency = 300
  timeout   = 30
  geo_locations = [
    "emea-fr-pra-edge",
    "emea-nl-ams-azr",
    "emea-gb-db3-azr"
  ]

  request {
    url = "https://${var.app_service_hostname}/health"
  }

  validation_rules {
    expected_status_code = 200
  }

  tags = var.tags
}

# Checks the Function App HTTP trigger from three Azure regions.
resource "azurerm_application_insights_standard_web_test" "function_health" {
  name                    = "avail-func-${var.owner}"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.func.id

  enabled   = true
  frequency = 300
  timeout   = 30
  geo_locations = [
    "emea-fr-pra-edge",
    "emea-nl-ams-azr",
    "emea-gb-db3-azr"
  ]

  request {
    url = "${var.function_app_url}/api/http_trigger?name=HealthCheck"
  }

  validation_rules {
    expected_status_code = 200
  }

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

# Dedicated network for the Prometheus VM in its selected region.
resource "azurerm_virtual_network" "prometheus" {
  name                = "vnet-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.prometheus_location
  address_space       = ["10.50.0.0/16"]

  tags = var.tags
}

resource "azurerm_subnet" "prometheus" {
  name                 = "subnet-prometheus"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.prometheus.name
  address_prefixes     = ["10.50.1.0/24"]

  lifecycle {
    replace_triggered_by = [
      azurerm_virtual_network.prometheus.id
    ]
  }
}

resource "azurerm_network_security_group" "prometheus" {
  name                = "nsg-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.prometheus_location

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "prometheus" {
  subnet_id                 = azurerm_subnet.prometheus.id
  network_security_group_id = azurerm_network_security_group.prometheus.id
}

# Public IP used for administrative SSH access to the Prometheus VM.
resource "azurerm_public_ip" "prometheus" {
  name                = "pip-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.prometheus_location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network interface attached to the existing backend subnet.
resource "azurerm_network_interface" "prometheus" {
  #checkov:skip=CKV_AZURE_119:The standalone Prometheus endpoint requires a public IP; inbound access is restricted by the NSG.
  name                = "nic-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.prometheus_location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prometheus.id
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

# Sends App Service Plan CPU metrics to Log Analytics for the workbook.
resource "azurerm_monitor_diagnostic_setting" "service_plan" {
  name                       = "diag-plan-${var.owner}"
  target_resource_id         = var.service_plan_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
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

# Alerts when the application produces more than five error logs in five minutes.
resource "azurerm_monitor_alert_prometheus_rule_group" "application_errors" {
  name                = "prom-rule-errors-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.location

  scopes = [
    azurerm_monitor_workspace.prometheus.id
  ]

  description        = "Prometheus alerts for application error metrics."
  rule_group_enabled = true
  interval           = "PT1M"

  rule {
    alert      = "HighApplicationErrorRate"
    expression = "increase(log_erreurs_total[5m]) > 5"
    severity   = 1
    enabled    = true

    annotations = {
      summary     = "High number of application errors"
      description = "The application produced more than five ERROR or CRITICAL logs during the last five minutes."
    }

    labels = {
      service = "log-analyser"
      team    = "observability"
    }

    action {
      action_group_id = azurerm_monitor_action_group.team.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT5M"
    }
  }

  tags = var.tags
}

# Critical alert when the App Service fails from at least two regions.
resource "azurerm_monitor_metric_alert" "app_availability" {
  name                = "alert-avail-app-${var.owner}"
  resource_group_name = var.resource_group_name

  scopes = [
    azurerm_application_insights_standard_web_test.app_health.id,
    azurerm_application_insights.app.id
  ]

  severity    = 0
  frequency   = "PT1M"
  window_size = "PT5M"

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.app_health.id
    component_id          = azurerm_application_insights.app.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }

  tags = var.tags
}

# Critical alert when the Function App fails from at least two regions.
resource "azurerm_monitor_metric_alert" "function_availability" {
  name                = "alert-avail-func-${var.owner}"
  resource_group_name = var.resource_group_name

  scopes = [
    azurerm_application_insights_standard_web_test.function_health.id,
    azurerm_application_insights.func.id
  ]

  severity    = 0
  frequency   = "PT1M"
  window_size = "PT5M"

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.function_health.id
    component_id          = azurerm_application_insights.func.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
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

# Runs Prometheus and scrapes the App Service /metrics endpoint.
resource "azurerm_linux_virtual_machine" "prometheus" {
  #checkov:skip=CKV_AZURE_50:The VM uses cloud-init for Prometheus bootstrap and does not install Azure VM extension resources.
  name                = "vm-prometheus-${var.owner}"
  resource_group_name = var.resource_group_name
  location            = var.prometheus_location
  size                = "Standard_B2ts_v2"

  admin_username                  = var.prometheus_admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.prometheus.id
  ]

  # System-assigned identity is used to authenticate Prometheus remote_write
  # against the Azure Monitor Data Collection Rule.
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.prometheus_admin_username
    public_key = var.prometheus_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-prometheus-${var.owner}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile(
    "${path.module}/cloud-init.yaml",
    {
      app_service_hostname = var.app_service_hostname
      remote_write_url     = local.prometheus_remote_write_url
    }
  ))

  tags = var.tags
}

# Allows the Prometheus VM identity to publish metrics through the DCR.
resource "azurerm_role_assignment" "prometheus_metrics_publisher" {
  scope                = azurerm_monitor_data_collection_rule.prometheus.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.prometheus.identity[0].principal_id
}
