# Azure Prerequisites for ERPNext with Managed Services

## Overview

This guide covers the prerequisites and initial setup required for deploying ERPNext on Microsoft Azure using managed database services: Azure Database for PostgreSQL and Azure Cache for Redis.

## 🔧 Required Tools

### 1. Azure CLI
```bash
# Install Azure CLI on macOS
brew update && brew install azure-cli

# Install on Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install on Windows (PowerShell as Administrator)
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'

# Login to Azure
az login
az account set --subscription "Your Subscription Name"
```

### 2. kubectl (Kubernetes CLI) - For AKS Option
```bash
# Install kubectl via Azure CLI
az aks install-cli

# Verify installation
kubectl version --client
```

### 3. Docker (for local testing and Container Instances)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Enable Docker BuildKit
export DOCKER_BUILDKIT=1
```

### 4. Helm (for AKS Kubernetes package management)
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## 🏗️ Azure Subscription Setup

### 1. Create Resource Group
```bash
# Set variables
export RESOURCE_GROUP="erpnext-rg"
export LOCATION="eastus"

# Create resource group
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Verify creation
az group show --name $RESOURCE_GROUP
```

### 2. Register Required Providers
```bash
# Register necessary Azure providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerInstance
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.Cache
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ManagedIdentity

# Check registration status
az provider list --query "[?namespace=='Microsoft.ContainerService'].registrationState" -o tsv
```

### 3. Set Default Resource Group and Location
```bash
# Set defaults for Azure CLI
az configure --defaults group=$RESOURCE_GROUP location=$LOCATION

# Verify configuration
az configure --list-defaults
```

## 🔐 Security Setup

### 1. Managed Identity Creation
```bash
# Create User Assigned Managed Identity
az identity create \
    --name erpnext-identity \
    --resource-group $RESOURCE_GROUP

# Get identity details
export IDENTITY_ID=$(az identity show --name erpnext-identity --resource-group $RESOURCE_GROUP --query id -o tsv)
export CLIENT_ID=$(az identity show --name erpnext-identity --resource-group $RESOURCE_GROUP --query clientId -o tsv)
export PRINCIPAL_ID=$(az identity show --name erpnext-identity --resource-group $RESOURCE_GROUP --query principalId -o tsv)
```

### 2. Key Vault Setup
```bash
# Create Key Vault
export KEYVAULT_NAME="erpnext-kv-$(openssl rand -hex 4)"
az keyvault create \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --enable-rbac-authorization

# Grant access to managed identity
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee $PRINCIPAL_ID \
    --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME

# Create secrets
az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name erpnext-admin-password \
    --value "YourSecurePassword123!"

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name erpnext-db-password \
    --value "YourDBPassword123!"

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name erpnext-redis-key \
    --value "$(openssl rand -base64 32)"

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name erpnext-api-key \
    --value "your-api-key-here"

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name erpnext-api-secret \
    --value "your-api-secret-here"
```

### 3. Service Principal Creation (Alternative to Managed Identity)
```bash
# Create service principal for automation
az ad sp create-for-rbac \
    --name erpnext-sp \
    --role Contributor \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP \
    --sdk-auth > ~/erpnext-sp-credentials.json

# Store service principal credentials securely
chmod 600 ~/erpnext-sp-credentials.json
```

## 🌐 Networking Setup

### 1. Virtual Network Creation
```bash
# Create virtual network
az network vnet create \
    --name erpnext-vnet \
    --resource-group $RESOURCE_GROUP \
    --address-prefix 10.0.0.0/16

# Create subnets for different services
# Subnet for AKS nodes
az network vnet subnet create \
    --name aks-subnet \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --address-prefix 10.0.1.0/24

# Subnet for Container Instances
az network vnet subnet create \
    --name aci-subnet \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --address-prefix 10.0.2.0/24 \
    --delegation Microsoft.ContainerInstance/containerGroups

# Subnet for database services
az network vnet subnet create \
    --name db-subnet \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --address-prefix 10.0.3.0/24

# Subnet for Redis cache
az network vnet subnet create \
    --name redis-subnet \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --address-prefix 10.0.4.0/24
```

### 2. Network Security Groups
```bash
# Create NSG for AKS
az network nsg create \
    --name aks-nsg \
    --resource-group $RESOURCE_GROUP

# Allow HTTP/HTTPS traffic
az network nsg rule create \
    --name AllowHTTP \
    --nsg-name aks-nsg \
    --resource-group $RESOURCE_GROUP \
    --priority 100 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes Internet \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 80 443 8080

# Create NSG for databases
az network nsg create \
    --name db-nsg \
    --resource-group $RESOURCE_GROUP

# Allow PostgreSQL traffic from app subnets
az network nsg rule create \
    --name AllowPostgreSQL \
    --nsg-name db-nsg \
    --resource-group $RESOURCE_GROUP \
    --priority 100 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes 10.0.1.0/24 10.0.2.0/24 \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 5432

# Associate NSGs with subnets
az network vnet subnet update \
    --name aks-subnet \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --network-security-group aks-nsg

az network vnet subnet update \
    --name db-subnet \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --network-security-group db-nsg
```

### 3. Private DNS Zone (for Private Endpoints)
```bash
# Create private DNS zones for managed services
az network private-dns zone create \
    --name privatelink.postgres.database.azure.com \
    --resource-group $RESOURCE_GROUP

az network private-dns zone create \
    --name privatelink.redis.cache.windows.net \
    --resource-group $RESOURCE_GROUP

# Link DNS zones to VNet
az network private-dns link vnet create \
    --name erpnext-postgres-link \
    --resource-group $RESOURCE_GROUP \
    --zone-name privatelink.postgres.database.azure.com \
    --virtual-network erpnext-vnet \
    --registration-enabled false

az network private-dns link vnet create \
    --name erpnext-redis-link \
    --resource-group $RESOURCE_GROUP \
    --zone-name privatelink.redis.cache.windows.net \
    --virtual-network erpnext-vnet \
    --registration-enabled false
```

## 💾 Managed Database Services Setup

### 1. Azure Database for PostgreSQL
```bash
# Create PostgreSQL server
export DB_SERVER_NAME="erpnext-db-$(openssl rand -hex 4)"
export DB_ADMIN_USER="erpnext"
export DB_ADMIN_PASSWORD="YourDBPassword123!"

az postgres flexible-server create \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --admin-user $DB_ADMIN_USER \
    --admin-password $DB_ADMIN_PASSWORD \
    --sku-name Standard_D2s_v3 \
    --storage-size 128 \
    --version 13 \
    --vnet erpnext-vnet \
    --subnet db-subnet \
    --backup-retention 7 \
    --geo-redundant-backup Enabled \
    --high-availability Enabled \
    --zone 1 \
    --standby-zone 2

# Create database
az postgres flexible-server db create \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --database-name erpnext

# Configure PostgreSQL parameters for ERPNext
az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name max_connections \
    --value 200

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name shared_buffers \
    --value 65536  # 256MB for Standard_D2s_v3

# Enable extensions required by ERPNext
az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name azure.extensions \
    --value "uuid-ossp,pg_trgm,btree_gin"

# Get connection string
export DB_CONNECTION_STRING=$(az postgres flexible-server show-connection-string \
    --server-name $DB_SERVER_NAME \
    --database-name erpnext \
    --admin-user $DB_ADMIN_USER \
    --admin-password $DB_ADMIN_PASSWORD \
    --query connectionStrings.psql -o tsv)
```

### 2. Azure Cache for Redis
```bash
# Create Redis cache
export REDIS_NAME="erpnext-redis-$(openssl rand -hex 4)"

az redis create \
    --name $REDIS_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard \
    --vm-size c1 \
    --enable-non-ssl-port false \
    --minimum-tls-version 1.2 \
    --redis-configuration maxmemory-policy="allkeys-lru"

# Get Redis access key
export REDIS_KEY=$(az redis list-keys \
    --name $REDIS_NAME \
    --resource-group $RESOURCE_GROUP \
    --query primaryKey -o tsv)

# Get Redis hostname
export REDIS_HOST=$(az redis show \
    --name $REDIS_NAME \
    --resource-group $RESOURCE_GROUP \
    --query hostName -o tsv)

# Create private endpoint for Redis
az network private-endpoint create \
    --name redis-private-endpoint \
    --resource-group $RESOURCE_GROUP \
    --vnet-name erpnext-vnet \
    --subnet redis-subnet \
    --private-connection-resource-id $(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query id -o tsv) \
    --group-id redisCache \
    --connection-name redis-connection

# Configure DNS for private endpoint
az network private-endpoint dns-zone-group create \
    --name redis-dns-group \
    --resource-group $RESOURCE_GROUP \
    --endpoint-name redis-private-endpoint \
    --private-dns-zone privatelink.redis.cache.windows.net \
    --zone-name redis
```

### 3. Database Initialization
```bash
# Create initialization script
cat > /tmp/init_erpnext_db.sql <<EOF
-- Create ERPNext database with proper encoding
CREATE DATABASE IF NOT EXISTS erpnext WITH ENCODING 'UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8';

-- Connect to erpnext database
\c erpnext;

-- Create required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Set database parameters
ALTER DATABASE erpnext SET statement_timeout = 0;
ALTER DATABASE erpnext SET lock_timeout = 0;
ALTER DATABASE erpnext SET idle_in_transaction_session_timeout = 0;
ALTER DATABASE erpnext SET client_encoding = 'UTF8';
ALTER DATABASE erpnext SET standard_conforming_strings = on;
ALTER DATABASE erpnext SET check_function_bodies = false;
ALTER DATABASE erpnext SET xmloption = content;
ALTER DATABASE erpnext SET client_min_messages = warning;
ALTER DATABASE erpnext SET row_security = off;
EOF

# Connect to PostgreSQL and run initialization
PGPASSWORD=$DB_ADMIN_PASSWORD psql \
    -h $DB_SERVER_NAME.postgres.database.azure.com \
    -U $DB_ADMIN_USER@$DB_SERVER_NAME \
    -d postgres \
    -f /tmp/init_erpnext_db.sql
```

## 📦 Storage Setup

### 1. Azure Storage Account
```bash
# Create storage account for file uploads
export STORAGE_ACCOUNT="erpnext$(openssl rand -hex 4)"

az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false

# Create blob containers
az storage container create \
    --name erpnext-files \
    --account-name $STORAGE_ACCOUNT \
    --auth-mode login

az storage container create \
    --name erpnext-backups \
    --account-name $STORAGE_ACCOUNT \
    --auth-mode login

# Get storage connection string
export STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query connectionString -o tsv)
```

### 2. Configure Managed Identity Access
```bash
# Grant storage access to managed identity
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee $PRINCIPAL_ID \
    --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT
```

## 📊 Monitoring and Logging

### 1. Log Analytics Workspace
```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
    --workspace-name erpnext-logs \
    --resource-group $RESOURCE_GROUP

# Get workspace ID and key
export WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --workspace-name erpnext-logs \
    --resource-group $RESOURCE_GROUP \
    --query customerId -o tsv)

export WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --workspace-name erpnext-logs \
    --resource-group $RESOURCE_GROUP \
    --query primarySharedKey -o tsv)
```

### 2. Application Insights
```bash
# Create Application Insights
az monitor app-insights component create \
    --app erpnext-insights \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --workspace erpnext-logs

# Get instrumentation key
export INSTRUMENTATION_KEY=$(az monitor app-insights component show \
    --app erpnext-insights \
    --resource-group $RESOURCE_GROUP \
    --query instrumentationKey -o tsv)
```

### 3. Enable Database Monitoring
```bash
# Enable monitoring for PostgreSQL
az postgres flexible-server update \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --maintenance-window "Sun:02:00"

# Enable Redis monitoring (enabled by default)
# Metrics are automatically collected for Azure Cache for Redis
```

## 🔍 Verification Checklist

Before proceeding to deployment, verify:

```bash
# Check resource group exists
az group show --name $RESOURCE_GROUP

# Verify managed identity
az identity show --name erpnext-identity --resource-group $RESOURCE_GROUP

# Check Key Vault
az keyvault show --name $KEYVAULT_NAME

# List secrets
az keyvault secret list --vault-name $KEYVAULT_NAME

# Verify VNet and subnets
az network vnet show --name erpnext-vnet --resource-group $RESOURCE_GROUP
az network vnet subnet list --vnet-name erpnext-vnet --resource-group $RESOURCE_GROUP

# Check PostgreSQL server
az postgres flexible-server show \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP

# Verify Redis cache
az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP

# Check storage account
az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP

# Verify Log Analytics workspace
az monitor log-analytics workspace show \
    --workspace-name erpnext-logs \
    --resource-group $RESOURCE_GROUP
```

## 💡 Cost Optimization for Managed Services

### 1. PostgreSQL Optimization
```bash
# Use appropriate SKUs
# Development: Burstable B1ms or B2s
# Production: General Purpose D2s_v3 or higher

# Enable automatic storage growth
az postgres flexible-server update \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --storage-auto-grow Enabled

# Use zone-redundant HA only for production
# Save ~50% by using single zone for dev/test
```

### 2. Redis Cache Optimization
```bash
# Right-size Redis instance
# Basic tier for dev/test (no SLA)
# Standard tier for production (99.9% SLA)
# Premium tier only if clustering/geo-replication needed

# Monitor memory usage and scale accordingly
az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP \
    --query "redisConfiguration.maxmemory-policy"
```

### 3. Reserved Capacity
```bash
# Purchase reserved capacity for predictable workloads
# Up to 65% savings for 3-year commitments
# Available for PostgreSQL, Redis, and VMs
```

## 🚨 Security Best Practices

### 1. Network Security
- **Private endpoints**: All managed services use private endpoints
- **VNet integration**: Secure communication within VNet
- **No public access**: Database and Redis not accessible from internet

### 2. Access Control
```bash
# Use Azure AD authentication for PostgreSQL
az postgres flexible-server ad-admin create \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --display-name "ERPNext Admins" \
    --object-id $(az ad group show --group "ERPNext Admins" --query objectId -o tsv)

# Enable Azure AD auth only mode
az postgres flexible-server update \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --password-auth Disabled
```

### 3. Encryption
- **Encryption at rest**: Enabled by default with Microsoft-managed keys
- **Encryption in transit**: TLS 1.2+ enforced
- **Customer-managed keys**: Optional for additional control

```bash
# Enable customer-managed keys (optional)
az postgres flexible-server update \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --key-vault-key-uri https://$KEYVAULT_NAME.vault.azure.net/keys/cmk/version
```

## 📚 Export Environment Variables

Save these for deployment scripts:

```bash
# Create environment file
cat > ~/erpnext-azure-env.sh <<EOF
export RESOURCE_GROUP="$RESOURCE_GROUP"
export LOCATION="$LOCATION"
export KEYVAULT_NAME="$KEYVAULT_NAME"
export IDENTITY_ID="$IDENTITY_ID"
export CLIENT_ID="$CLIENT_ID"
export PRINCIPAL_ID="$PRINCIPAL_ID"
export DB_SERVER_NAME="$DB_SERVER_NAME"
export DB_ADMIN_USER="$DB_ADMIN_USER"
export DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD"
export REDIS_NAME="$REDIS_NAME"
export REDIS_HOST="$REDIS_HOST"
export REDIS_KEY="$REDIS_KEY"
export STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
export STORAGE_CONNECTION_STRING="$STORAGE_CONNECTION_STRING"
export WORKSPACE_ID="$WORKSPACE_ID"
export WORKSPACE_KEY="$WORKSPACE_KEY"
export INSTRUMENTATION_KEY="$INSTRUMENTATION_KEY"
EOF

# Source for future use
source ~/erpnext-azure-env.sh
```

## ➡️ Next Steps

After completing prerequisites:
1. **AKS with Managed Services**: Follow `01-aks-managed-deployment.md`
2. **Container Instances**: Follow `02-container-instances-deployment.md`
3. **Production Hardening**: See `03-production-managed-setup.md`

---

**⚠️ Important Notes**:
- Managed services incur continuous costs even when not in use
- Plan your backup and disaster recovery strategy
- Monitor costs regularly using Azure Cost Management
- Keep track of all resources created for billing purposes
- Use tags for resource organization and cost tracking