#!/bin/bash

set -euo pipefail

# ==========================================
# GitHub OIDC Configuration
# ==========================================

source "$(dirname "$0")/config.sh"

echo ""
echo "Configuration"
echo "--------------------------------"

echo "Owner              : $OWNER"
echo "Location           : $LOCATION"
echo "Subscription Name  : $AZURE_SUBSCRIPTION"
echo "Resource Group     : $RESOURCE_GROUP"
echo "GitHub Repository  : $GITHUB_OWNER/$GITHUB_REPOSITORY"
echo ""
echo ""
echo "========================================="
echo " GitHub OIDC Configuration"
echo "========================================="

# ==========================================
# Validate configuration
# ==========================================

required_vars=(
    OWNER
    LOCATION
    RESOURCE_GROUP
    AZURE_SUBSCRIPTION
    GITHUB_OWNER
    GITHUB_REPOSITORY
    SP_NAME
    FEDERATED_CREDENTIAL_NAME
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: Variable '$var' is not defined in config.sh"
        exit 1
    fi
done

# ==========================================
# Check Azure login
# ==========================================

echo ""
echo "Checking Azure login..."

az account show >/dev/null

echo "Connected."

# ==========================================
# Select subscription
# ==========================================

echo ""
echo "Selecting subscription..."

az account set \
    --subscription "$AZURE_SUBSCRIPTION"

echo "Subscription selected."

# ==========================================
# Retrieve active subscription information
# ==========================================

SUBSCRIPTION_ID=$(az account show \
    --query id \
    -o tsv)

TENANT_ID=$(az account show \
    --query tenantId \
    -o tsv)

echo ""
echo "Active Azure Context"
echo "--------------------------------"
echo "Subscription ID : $SUBSCRIPTION_ID"
echo "Tenant ID       : $TENANT_ID"

# ==========================================
# Create or reuse App Registration
# ==========================================

echo ""
echo "Checking App Registration..."

APP_ID=$(az ad app list \
    --display-name "$SP_NAME" \
    --query "[0].appId" \
    -o tsv)

if [ -z "$APP_ID" ]; then

    echo "Creating App Registration..."

    APP_ID=$(az ad app create \
        --display-name "$SP_NAME" \
        --query appId \
        -o tsv)

    echo "Created."

else

    echo "Already exists."

fi

echo "APP_ID: $APP_ID"

# ==========================================
# Create or reuse Service Principal
# ==========================================

echo ""
echo "Checking Service Principal..."

SP_EXISTS=$(az ad sp list \
    --display-name "$SP_NAME" \
    --query "length(@)" \
    -o tsv)

if [ "$SP_EXISTS" -eq 0 ]; then

    echo "Creating Service Principal..."

    az ad sp create \
        --id "$APP_ID"

    echo "Created."

    echo "Waiting for Entra ID replication..."
    sleep 20

else

    echo "Already exists."

fi

# ==========================================
# Assign Contributor role
# ==========================================

echo ""
echo "Assigning Contributor role..."

ROLE_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

SP_OBJECT_ID=$(az ad sp show \
    --id "$APP_ID" \
    --query id \
    -o tsv)

az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role Contributor \
    --scope "$ROLE_SCOPE" \
    >/dev/null 2>&1 || true

echo "Contributor role configured."

# ==========================================
# Create Federated Credential
# ==========================================

echo ""
echo "Checking Federated Credential..."

APP_OBJECT_ID=$(az ad app show \
    --id "$APP_ID" \
    --query id \
    -o tsv)

FED_EXISTS=$(az ad app federated-credential list \
    --id "$APP_OBJECT_ID" \
    --query "[?name=='$FEDERATED_CREDENTIAL_NAME'] | length(@)" \
    -o tsv)

if [ "$FED_EXISTS" -eq 0 ]; then

cat > github-credential.json <<EOF
{
  "name": "$FEDERATED_CREDENTIAL_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_OWNER}/${GITHUB_REPOSITORY}:ref:refs/heads/main",
  "description": "GitHub Actions OIDC",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

    az ad app federated-credential create \
        --id "$APP_OBJECT_ID" \
        --parameters github-credential.json

    rm github-credential.json

    echo "Federated Credential created."

else

    echo "Federated Credential already exists."

fi

# ==========================================
# Summary
# ==========================================

echo ""
echo "========================================="
echo " GitHub OIDC successfully configured"
echo "========================================="

echo ""
echo "Repository Secrets"
echo "-------------------------------"

echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"

echo ""
echo "GitHub Repository"
echo "-------------------------------"

echo "$GITHUB_OWNER/$GITHUB_REPOSITORY"

echo ""
echo "Protected Branch"

echo "main"

echo ""
echo "Done."