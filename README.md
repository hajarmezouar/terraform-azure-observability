# Azure Infrastructure with Terraform & Observability

## Overview

This project provisions and manages Azure infrastructure using **Terraform** following Infrastructure as Code (IaC) best practices.

It serves as the foundation for implementing an observability stack using Azure Monitor services, including centralized logging, application monitoring, metric alerts, and dashboards.

The infrastructure is modular, reusable, and designed to demonstrate production-oriented Azure deployment practices.

---

## Features

Current infrastructure:

- Azure Resource Group (existing)
- Azure Storage Account
- Azure App Service (Linux)
- Azure Function App (Linux)
- Azure Container Instance
- Virtual Network
- Reusable Terraform modules
- Remote Terraform backend
- Azure authentication using Azure CLI

Upcoming observability features:

- Log Analytics Workspace
- Application Insights
- Azure Monitor Diagnostic Settings
- Availability Tests
- Metric Alerts
- Action Groups
- Azure Monitor Workbooks

---

## Repository Structure

```text
.
├── .github/
├── scripts/
├── terraform/
│   ├── modules/
│   │   ├── app-service/
│   │   ├── container/
│   │   ├── function-app/
│   │   ├── network/
│   │   ├── storage/
│   │   └── observability/      # Coming soon
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── versions.tf
├── app/                        # Flask monitoring application
├── function/                   # Azure Function
└── README.md
```

---

## Technologies

- Terraform
- Microsoft Azure
- Azure CLI
- Bash
- GitHub Actions
- Azure App Service
- Azure Functions
- Azure Storage
- Azure Monitor
- Application Insights
- Log Analytics

---

## Prerequisites

- Terraform
- Azure CLI
- Azure Subscription
- Existing Resource Group
- Existing Remote Backend (optional)

Authenticate before deploying:

```bash
az login
```

---

## Deployment

Initialize Terraform

```bash
terraform init
```

Review the execution plan

```bash
terraform plan
```

Deploy the infrastructure

```bash
terraform apply
```

---

## Observability

The observability module will provide:

- Centralized logging with Log Analytics
- Application performance monitoring
- Infrastructure metrics
- Health monitoring
- Availability testing
- Alerting
- Azure Monitor dashboards

---

## Security

This project follows Infrastructure as Code best practices.

- Modular Terraform architecture
- Remote Terraform state
- Reusable modules
- Versioned infrastructure
- Principle of least privilege
- No secrets committed to the repository

---

## Future Improvements

- CI/CD pipeline
- Automated infrastructure validation
- Policy as Code
- Cost monitoring
- Dashboard automation
- Automated testing
- Production and staging environments

---

## License

This repository is intended for educational purposes as part of a DevOps and Cloud Engineering training.