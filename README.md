# Azure Observability Stack with Terraform

## Overview

This project deploys an Azure application platform and its observability stack with Terraform. It monitors a Flask App Service, an Azure Function, Storage, and a standalone Prometheus VM using Azure Monitor, Application Insights, Log Analytics, managed Prometheus, alerts, Workbooks, and Grafana dashboards.

The project was created for the Simplon DevOps and Cloud Engineering observability lab.

## Architecture

```text
Flask App Service ──┬── Application Insights ──┐
                    ├── Diagnostic settings ────┤
                    └── /metrics                │
                           │                    ▼
                           ▼             Log Analytics Workspace
                    Prometheus VM               │
                           │                    ├── Azure Monitor Workbook
                           └── remote_write ─────┼── Metric alerts
                                                └── Action Group → email

Azure Function ─────┬── Application Insights
                    ├── Availability test
                    └── Diagnostic settings

Storage Account ─────── Diagnostic settings

Azure Monitor managed Prometheus ── Grafana dashboard
```

## Deployed Components

- Existing Azure resource group: `rg-hajar-terraform`
- Linux App Service and Python Flask application
- Linux Function App and HTTP-triggered Python function
- Storage accounts and blob containers
- Azure Container Instance
- Virtual network, subnets, NSG, public IP, and network interface
- Log Analytics workspace
- Application Insights for the App Service and Function App
- Diagnostic settings for App Service, Function App, Storage, and App Service plan
- Multi-region availability tests
- Action group and Azure Monitor metric alerts
- Azure Monitor workspace, data collection endpoint, and data collection rule
- Ubuntu Prometheus VM with managed-identity authenticated `remote_write`
- Prometheus alert rule for application errors
- Azure Monitor Workbook
- Azure Monitor Dashboard with Grafana

## Repository Structure

```text
.
├── .github/workflows/
│   ├── terraform-ci.yml
│   └── terraform-deploy.yml
├── app/                         # Flask app: /health, /metrics, /error
├── docs/
│   └── post-mortem.md
├── function/                    # Python HTTP-triggered Azure Function
├── scripts/
└── terraform/
    ├── modules/
    │   ├── app-service/
    │   ├── container/
    │   ├── function-app/
    │   ├── network/
    │   ├── observability/
    │   └── storage/
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── variables.tf
    └── versions.tf
```

## Prerequisites

- Terraform 1.9 or later
- Azure CLI
- Azure Functions Core Tools
- An Azure subscription
- An existing resource group and Terraform remote backend
- An SSH public key for the Prometheus VM

Authenticate and select the subscription:

```bash
az login
az account set --subscription "<subscription-id>"
```

Register the providers used by the stack:

```bash
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.AlertsManagement
az provider register --namespace Microsoft.Dashboard
```

## Terraform Configuration

Create `terraform/terraform.tfvars` locally. Do not commit private values.

```hcl
owner                         = "hajar-mezouar"
resource_group_name            = "rg-hajar-terraform"
app_service_plan_name          = "plan-hajar-terraform"
location                       = "francecentral"
prometheus_location            = "polandcentral"
alert_email                    = "your-email@example.com"
admin_source_cidr              = "203.0.113.10/32"
prometheus_ssh_public_key      = "ssh-ed25519 AAAA..."
tags = {
  environment = "tp"
  owner       = "hajar-mezouar"
}
```

## Deployment

```bash
cd terraform
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Deploy the Flask application:

```bash
cd ../app
az webapp up \
  --name app-hajar-mezouar-tf \
  --resource-group rg-hajar-terraform \
  --plan plan-hajar-terraform \
  --runtime "PYTHON:3.11"
```

Deploy the Function code:

```bash
cd ../function
func azure functionapp publish fn-hajar-mezouar-tf --python
```

## Verification

App Service:

```bash
curl https://app-hajar-mezouar-tf.azurewebsites.net/health
curl -s https://app-hajar-mezouar-tf.azurewebsites.net/metrics | head
```

Function App:

```bash
curl "https://fn-hajar-mezouar-tf.azurewebsites.net/api/http_trigger?name=Simplon"
```

Prometheus, from the VM:

```bash
sudo systemctl status prometheus --no-pager
curl http://127.0.0.1:9090/-/ready
curl -sG \
  --data-urlencode 'query=increase(log_erreurs_total[5m])' \
  http://127.0.0.1:9090/api/v1/query | python3 -m json.tool
```

## Dashboards

### Azure Monitor Workbook

The saved Workbook contains:

1. App Service CPU percentage
2. HTTP 5xx errors
3. Function execution count
4. Application availability

### Grafana Dashboard

Azure Monitor **Dashboards with Grafana** contains the saved dashboard `application-observability-hajar-mezouar`.

| Panel | PromQL | Visualization |
|---|---|---|
| Total Application Errors | `log_erreurs_total` | Stat |
| Application Errors — Last 5 Minutes | `increase(log_erreurs_total[5m])` | Time series |
| Application Scrape Status | `up{job="log-analyser"}` | Stat (`1=UP`, `0=DOWN`) |
| Prometheus Scrape Duration | `scrape_duration_seconds{job="log-analyser"}` | Time series |

## Alerts and Thresholds

| Alert | Severity | Threshold and rationale |
|---|---:|---|
| App availability | 0 — Critical | Fires when at least two test locations fail, reducing false positives from one probe location |
| Function availability | 0 — Critical | Fires when at least two test locations fail |
| App Service HTTP 5xx | 1 — Error | More than five errors during the evaluation window indicates a sustained application failure |
| App Service CPU | 1 — Error | CPU above 80% indicates saturation risk |
| High application error rate | 1 — Error | `increase(log_erreurs_total[5m]) > 5` detects application-level ERROR and CRITICAL logs |

Alerts notify the configured email receiver through the Terraform-managed action group.

## War Room Result

A controlled test sent 100 requests to `/error`.

- Prometheus measured `increase(log_erreurs_total[5m]) = 105.263`.
- `HighApplicationErrorRate` fired at 15:26 CEST on 24 July 2026.
- The Grafana dashboard displayed the error spike while scrape status remained `UP`.
- The App Service `/health` endpoint continued returning HTTP 200.

See [the incident post-mortem](docs/post-mortem.md).

## CI/CD

The Terraform CI workflow runs:

- `terraform fmt -check`
- `terraform validate`
- TFLint
- Checkov
- Authenticated Terraform plan
- Infracost estimation

The manual deployment workflow supports plan, saved-plan apply, and confirmation-protected destroy operations using GitHub OIDC authentication.

Required GitHub Actions secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_ADMIN_SOURCE_CIDR`
- `TF_VAR_PROMETHEUS_SSH_PUBLIC_KEY`
- `INFRACOST_API_KEY`

## Security Notes

- Password authentication is disabled on the Prometheus VM.
- SSH access is restricted to `admin_source_cidr`.
- Managed identity authenticates Prometheus remote write.
- Storage blobs cannot be made anonymously public.
- Function runtime storage uses a public network endpoint because this lab does not deploy a private endpoint or Function VNet integration.
- Secrets and private SSH keys are not committed.

## Known Lab Constraints

- VM region and SKU availability depend on Azure for Students capacity and quota.
- The Prometheus VM is deployed in Poland Central because the subscription allowed the selected VM SKU there.
- Azure Monitor data can take several minutes to appear in dashboards and alerts.

## License

This repository is intended for educational use as part of DevOps and Cloud Engineering training.
