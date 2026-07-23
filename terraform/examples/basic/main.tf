terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "azure_infra" {

  source = "../../"

  owner = "demo"

  location = "francecentral"

  resource_group_name = "rg-demo"

  app_service_plan_name = "plan-demo"

  tags = {
    environment = "example"
    project     = "terraform-registry"
  }

}