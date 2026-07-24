provider "azurerm" {
  # Authentication via OIDC — no client secret
  # ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID injected by GitHub Actions
  # use_oidc = true
  subscription_id = "d3fc8b82-2bdb-4191-bc16-3314c2661e6b"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}