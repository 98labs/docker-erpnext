# Azure Container Instances Deployment with Managed Services

## Overview

This guide covers deploying ERPNext on Azure Container Instances (ACI) using Azure Database for PostgreSQL and Azure Cache for Redis. ACI provides a serverless container platform ideal for simpler deployments without Kubernetes complexity.

## Prerequisites

- Completed all steps in `00-prerequisites-managed.md`
- Azure CLI installed and configured
- Docker installed locally for image building
- Environment variables from prerequisites exported

## 🚀 Container Registry Setup

### 1. Create Azure Container Registry
```bash
# Source environment variables
source ~/erpnext-azure-env.sh

# Create container registry
export ACR_NAME="erpnextacr$(openssl rand -hex 4)"
az acr create \
    --name $ACR_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard \
    --admin-enabled true

# Get registry credentials
export ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
export ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
export ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

# Login to registry
az acr login --name $ACR_NAME
```

### 2. Build and Push Custom Images
```bash
# Create Dockerfile for ERPNext with Azure integrations
cat > Dockerfile.azure <<EOF
FROM frappe/erpnext-worker:v14

# Install Azure Storage SDK for Python
RUN pip install azure-storage-blob azure-identity

# Add custom entrypoint for Azure configurations
COPY entrypoint.azure.sh /entrypoint.azure.sh
RUN chmod +x /entrypoint.azure.sh

ENTRYPOINT ["/entrypoint.azure.sh"]
EOF

# Create entrypoint script
cat > entrypoint.azure.sh <<EOF
#!/bin/bash
set -e

# Configure database connection for PostgreSQL
export DB_TYPE="postgres"
export DB_HOST="\${DB_HOST}"
export DB_PORT="5432"
export DB_NAME="erpnext"

# Configure Redis with authentication
export REDIS_CACHE="redis://:\${REDIS_PASSWORD}@\${REDIS_HOST}:6380/0?ssl_cert_reqs=required"
export REDIS_QUEUE="redis://:\${REDIS_PASSWORD}@\${REDIS_HOST}:6380/1?ssl_cert_reqs=required"
export REDIS_SOCKETIO="redis://:\${REDIS_PASSWORD}@\${REDIS_HOST}:6380/2?ssl_cert_reqs=required"

# Execute original command
exec "\$@"
EOF

# Build and push image
docker build -f Dockerfile.azure -t $ACR_LOGIN_SERVER/erpnext-azure:v14 .
docker push $ACR_LOGIN_SERVER/erpnext-azure:v14
```

## 📦 Deploy Container Instances

### 1. Create File Share for Persistent Storage
```bash
# Create file share in storage account
az storage share create \
    --name erpnext-sites \
    --account-name $STORAGE_ACCOUNT \
    --quota 100

az storage share create \
    --name erpnext-assets \
    --account-name $STORAGE_ACCOUNT \
    --quota 50

# Get storage account key
export STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query "[0].value" -o tsv)
```

### 2. Deploy Backend Container Group
```bash
# Create backend container group with multiple containers
cat > aci-backend-deployment.yaml <<EOF
apiVersion: 2021-10-01
location: $LOCATION
name: erpnext-backend
properties:
  containers:
  - name: backend
    properties:
      image: $ACR_LOGIN_SERVER/erpnext-azure:v14
      resources:
        requests:
          cpu: 2
          memoryInGb: 4
      ports:
      - port: 8000
        protocol: TCP
      environmentVariables:
      - name: DB_HOST
        value: $DB_SERVER_NAME.postgres.database.azure.com
      - name: DB_USER
        value: $DB_ADMIN_USER
      - name: DB_PASSWORD
        secureValue: $DB_ADMIN_PASSWORD
      - name: REDIS_HOST
        value: $REDIS_HOST
      - name: REDIS_PASSWORD
        secureValue: $REDIS_KEY
      - name: ADMIN_PASSWORD
        secureValue: YourSecurePassword123!
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
      - name: assets
        mountPath: /home/frappe/frappe-bench/sites/assets
  - name: scheduler
    properties:
      image: $ACR_LOGIN_SERVER/erpnext-azure:v14
      command: ["bench", "schedule"]
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 1
      environmentVariables:
      - name: DB_HOST
        value: $DB_SERVER_NAME.postgres.database.azure.com
      - name: DB_USER
        value: $DB_ADMIN_USER
      - name: DB_PASSWORD
        secureValue: $DB_ADMIN_PASSWORD
      - name: REDIS_HOST
        value: $REDIS_HOST
      - name: REDIS_PASSWORD
        secureValue: $REDIS_KEY
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
  - name: worker-default
    properties:
      image: $ACR_LOGIN_SERVER/erpnext-azure:v14
      command: ["bench", "worker", "--queue", "default"]
      resources:
        requests:
          cpu: 1
          memoryInGb: 2
      environmentVariables:
      - name: DB_HOST
        value: $DB_SERVER_NAME.postgres.database.azure.com
      - name: DB_USER
        value: $DB_ADMIN_USER
      - name: DB_PASSWORD
        secureValue: $DB_ADMIN_PASSWORD
      - name: REDIS_HOST
        value: $REDIS_HOST
      - name: REDIS_PASSWORD
        secureValue: $REDIS_KEY
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
  - name: worker-long
    properties:
      image: $ACR_LOGIN_SERVER/erpnext-azure:v14
      command: ["bench", "worker", "--queue", "long"]
      resources:
        requests:
          cpu: 1
          memoryInGb: 2
      environmentVariables:
      - name: DB_HOST
        value: $DB_SERVER_NAME.postgres.database.azure.com
      - name: DB_USER
        value: $DB_ADMIN_USER
      - name: DB_PASSWORD
        secureValue: $DB_ADMIN_PASSWORD
      - name: REDIS_HOST
        value: $REDIS_HOST
      - name: REDIS_PASSWORD
        secureValue: $REDIS_KEY
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
  imageRegistryCredentials:
  - server: $ACR_LOGIN_SERVER
    username: $ACR_USERNAME
    password: $ACR_PASSWORD
  volumes:
  - name: sites
    azureFile:
      shareName: erpnext-sites
      storageAccountName: $STORAGE_ACCOUNT
      storageAccountKey: $STORAGE_KEY
  - name: assets
    azureFile:
      shareName: erpnext-assets
      storageAccountName: $STORAGE_ACCOUNT
      storageAccountKey: $STORAGE_KEY
  osType: Linux
  restartPolicy: Always
  ipAddress:
    type: Private
    ports:
    - port: 8000
      protocol: TCP
  subnetIds:
  - id: /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/erpnext-vnet/subnets/aci-subnet
type: Microsoft.ContainerInstance/containerGroups
EOF

# Deploy backend container group
az container create \
    --resource-group $RESOURCE_GROUP \
    --file aci-backend-deployment.yaml
```

### 3. Deploy Frontend Container Group
```bash
# Create frontend container group
cat > aci-frontend-deployment.yaml <<EOF
apiVersion: 2021-10-01
location: $LOCATION
name: erpnext-frontend
properties:
  containers:
  - name: frontend
    properties:
      image: frappe/erpnext-nginx:v14
      resources:
        requests:
          cpu: 1
          memoryInGb: 1
      ports:
      - port: 8080
        protocol: TCP
      environmentVariables:
      - name: BACKEND
        value: erpnext-backend.internal:8000
      - name: FRAPPE_SITE_NAME_HEADER
        value: frontend
      - name: SOCKETIO
        value: erpnext-websocket.internal:9000
      - name: UPSTREAM_REAL_IP_ADDRESS
        value: 127.0.0.1
      - name: UPSTREAM_REAL_IP_HEADER
        value: X-Forwarded-For
      - name: PROXY_READ_TIMEOUT
        value: "120"
      - name: CLIENT_MAX_BODY_SIZE
        value: 50m
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
      - name: assets
        mountPath: /usr/share/nginx/html/assets
  - name: websocket
    properties:
      image: frappe/frappe-socketio:v14
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 0.5
      ports:
      - port: 9000
        protocol: TCP
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
  imageRegistryCredentials:
  - server: $ACR_LOGIN_SERVER
    username: $ACR_USERNAME
    password: $ACR_PASSWORD
  volumes:
  - name: sites
    azureFile:
      shareName: erpnext-sites
      storageAccountName: $STORAGE_ACCOUNT
      storageAccountKey: $STORAGE_KEY
  - name: assets
    azureFile:
      shareName: erpnext-assets
      storageAccountName: $STORAGE_ACCOUNT
      storageAccountKey: $STORAGE_KEY
  osType: Linux
  restartPolicy: Always
  ipAddress:
    type: Public
    ports:
    - port: 8080
      protocol: TCP
    dnsNameLabel: erpnext-$RESOURCE_GROUP
type: Microsoft.ContainerInstance/containerGroups
EOF

# Deploy frontend container group
az container create \
    --resource-group $RESOURCE_GROUP \
    --file aci-frontend-deployment.yaml

# Get public IP/FQDN
export FRONTEND_FQDN=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-frontend \
    --query ipAddress.fqdn -o tsv)

echo "Frontend accessible at: http://$FRONTEND_FQDN:8080"
```

## 🔄 Initialize ERPNext Site

```bash
# Run site initialization as a one-time container
az container create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-init \
    --image $ACR_LOGIN_SERVER/erpnext-azure:v14 \
    --cpu 2 \
    --memory 4 \
    --restart-policy Never \
    --environment-variables \
        DB_HOST=$DB_SERVER_NAME.postgres.database.azure.com \
        DB_USER=$DB_ADMIN_USER \
        REDIS_HOST=$REDIS_HOST \
    --secure-environment-variables \
        DB_PASSWORD=$DB_ADMIN_PASSWORD \
        REDIS_PASSWORD=$REDIS_KEY \
        ADMIN_PASSWORD="YourSecurePassword123!" \
    --azure-file-volume-account-name $STORAGE_ACCOUNT \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name erpnext-sites \
    --azure-file-volume-mount-path /home/frappe/frappe-bench/sites \
    --command-line "/bin/bash -c 'bench new-site frontend --db-host \$DB_HOST --db-port 5432 --db-name erpnext --db-password \$DB_PASSWORD --admin-password \$ADMIN_PASSWORD --install-app erpnext && bench --site frontend migrate'" \
    --subnet /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/erpnext-vnet/subnets/aci-subnet \
    --registry-login-server $ACR_LOGIN_SERVER \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD

# Wait for initialization to complete
az container show \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-init \
    --query containers[0].instanceView.currentState.state

# View initialization logs
az container logs \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-init

# Delete init container after completion
az container delete \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-init \
    --yes
```

## 🌐 Configure Application Gateway

```bash
# Create public IP for Application Gateway
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-ag-pip \
    --allocation-method Static \
    --sku Standard

# Create Application Gateway
az network application-gateway create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-ag \
    --location $LOCATION \
    --vnet-name erpnext-vnet \
    --subnet aks-subnet \
    --public-ip-address erpnext-ag-pip \
    --sku Standard_v2 \
    --capacity 2 \
    --http-settings-port 8080 \
    --http-settings-protocol Http \
    --frontend-port 80 \
    --routing-rule-type Basic

# Configure backend pool with container instances
az network application-gateway address-pool create \
    --resource-group $RESOURCE_GROUP \
    --gateway-name erpnext-ag \
    --name erpnext-backend-pool \
    --servers $FRONTEND_FQDN

# Create health probe
az network application-gateway probe create \
    --resource-group $RESOURCE_GROUP \
    --gateway-name erpnext-ag \
    --name erpnext-health \
    --protocol Http \
    --path / \
    --interval 30 \
    --timeout 30 \
    --threshold 3

# Configure SSL (optional)
# Upload SSL certificate
az network application-gateway ssl-cert create \
    --resource-group $RESOURCE_GROUP \
    --gateway-name erpnext-ag \
    --name erpnext-ssl \
    --cert-file /path/to/certificate.pfx \
    --cert-password YourCertPassword

# Create HTTPS listener
az network application-gateway frontend-port create \
    --resource-group $RESOURCE_GROUP \
    --gateway-name erpnext-ag \
    --name https-port \
    --port 443

az network application-gateway http-listener create \
    --resource-group $RESOURCE_GROUP \
    --gateway-name erpnext-ag \
    --name erpnext-https-listener \
    --frontend-port https-port \
    --ssl-cert erpnext-ssl
```

## 📊 Monitoring and Logging

### 1. Enable Container Insights
```bash
# Enable diagnostics for container groups
az monitor diagnostic-settings create \
    --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerInstance/containerGroups/erpnext-backend \
    --name erpnext-backend-diagnostics \
    --workspace /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/erpnext-logs \
    --logs '[{"category": "ContainerInstanceLog", "enabled": true}]' \
    --metrics '[{"category": "AllMetrics", "enabled": true}]'

az monitor diagnostic-settings create \
    --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerInstance/containerGroups/erpnext-frontend \
    --name erpnext-frontend-diagnostics \
    --workspace /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/erpnext-logs \
    --logs '[{"category": "ContainerInstanceLog", "enabled": true}]' \
    --metrics '[{"category": "AllMetrics", "enabled": true}]'
```

### 2. View Container Logs
```bash
# View backend logs
az container logs \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --container-name backend

# View worker logs
az container logs \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --container-name worker-default

# Stream logs
az container attach \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --container-name backend
```

### 3. Create Alerts
```bash
# Alert for container restart
az monitor metrics alert create \
    --name erpnext-container-restart \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerInstance/containerGroups/erpnext-backend \
    --condition "sum RestartCount > 5" \
    --window-size 15m \
    --evaluation-frequency 5m

# Alert for high CPU usage
az monitor metrics alert create \
    --name erpnext-high-cpu \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerInstance/containerGroups/erpnext-backend \
    --condition "avg CpuUsage > 80" \
    --window-size 5m \
    --evaluation-frequency 1m
```

## 🔧 Scaling Container Instances

### Manual Scaling
```bash
# Scale by creating additional container groups
for i in {2..3}; do
    sed "s/erpnext-backend/erpnext-backend-$i/g" aci-backend-deployment.yaml > aci-backend-deployment-$i.yaml
    az container create \
        --resource-group $RESOURCE_GROUP \
        --file aci-backend-deployment-$i.yaml
done

# Update Application Gateway backend pool
az network application-gateway address-pool update \
    --resource-group $RESOURCE_GROUP \
    --gateway-name erpnext-ag \
    --name erpnext-backend-pool \
    --servers erpnext-backend-1.internal erpnext-backend-2.internal erpnext-backend-3.internal
```

### Auto-scaling with Logic Apps
```bash
# Create Logic App for auto-scaling
az logic workflow create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-autoscale \
    --definition '{
        "triggers": {
            "Recurrence": {
                "recurrence": {
                    "frequency": "Minute",
                    "interval": 5
                },
                "type": "Recurrence"
            }
        },
        "actions": {
            "CheckMetrics": {
                "type": "Http",
                "inputs": {
                    "method": "GET",
                    "uri": "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/'$RESOURCE_GROUP'/providers/Microsoft.ContainerInstance/containerGroups/erpnext-backend/providers/Microsoft.Insights/metrics?api-version=2018-01-01&metricnames=CpuUsage"
                }
            },
            "ScaleDecision": {
                "type": "If",
                "expression": "@greater(body('"'"'CheckMetrics'"'"').value[0].timeseries[0].data[0].average, 70)",
                "actions": {
                    "ScaleUp": {
                        "type": "Http",
                        "inputs": {
                            "method": "PUT",
                            "uri": "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/'$RESOURCE_GROUP'/providers/Microsoft.ContainerInstance/containerGroups/erpnext-backend-new?api-version=2021-10-01"
                        }
                    }
                }
            }
        }
    }'
```

## 🔄 Backup and Recovery

### 1. Database Backup
```bash
# Manual backup
az postgres flexible-server backup create \
    --resource-group $RESOURCE_GROUP \
    --server-name $DB_SERVER_NAME \
    --backup-name erpnext-manual-backup-$(date +%Y%m%d)

# List backups
az postgres flexible-server backup list \
    --resource-group $RESOURCE_GROUP \
    --server-name $DB_SERVER_NAME
```

### 2. File Storage Backup
```bash
# Create backup container
az storage container create \
    --name erpnext-backups \
    --account-name $STORAGE_ACCOUNT

# Backup file shares using AzCopy
azcopy copy \
    "https://$STORAGE_ACCOUNT.file.core.windows.net/erpnext-sites?$STORAGE_KEY" \
    "https://$STORAGE_ACCOUNT.blob.core.windows.net/erpnext-backups/$(date +%Y%m%d)/" \
    --recursive
```

### 3. Application Backup Job
```bash
# Create backup container instance
az container create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backup \
    --image $ACR_LOGIN_SERVER/erpnext-azure:v14 \
    --cpu 1 \
    --memory 2 \
    --restart-policy OnFailure \
    --environment-variables \
        DB_HOST=$DB_SERVER_NAME.postgres.database.azure.com \
        DB_USER=$DB_ADMIN_USER \
        STORAGE_ACCOUNT=$STORAGE_ACCOUNT \
    --secure-environment-variables \
        DB_PASSWORD=$DB_ADMIN_PASSWORD \
        STORAGE_KEY=$STORAGE_KEY \
    --azure-file-volume-account-name $STORAGE_ACCOUNT \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name erpnext-sites \
    --azure-file-volume-mount-path /home/frappe/frappe-bench/sites \
    --command-line "/bin/bash -c 'bench --site frontend backup && az storage blob upload --account-name \$STORAGE_ACCOUNT --account-key \$STORAGE_KEY --container-name erpnext-backups --file /home/frappe/frappe-bench/sites/frontend/private/backups/*.sql.gz --name backup-$(date +%Y%m%d).sql.gz'" \
    --subnet /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/erpnext-vnet/subnets/aci-subnet
```

## 🔍 Troubleshooting

### Container Health Issues
```bash
# Check container status
az container show \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --query containers[].instanceView.currentState

# Restart container group
az container restart \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend

# Execute commands in container
az container exec \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --container-name backend \
    --exec-command "/bin/bash"
```

### Network Connectivity Issues
```bash
# Test database connectivity from container
az container exec \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --container-name backend \
    --exec-command "pg_isready -h $DB_SERVER_NAME.postgres.database.azure.com -U $DB_ADMIN_USER"

# Test Redis connectivity
az container exec \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backend \
    --container-name backend \
    --exec-command "redis-cli -h $REDIS_HOST -a $REDIS_KEY ping"
```

### Storage Issues
```bash
# Check file share usage
az storage share show \
    --name erpnext-sites \
    --account-name $STORAGE_ACCOUNT \
    --query "properties.quota"

# List files in share
az storage file list \
    --share-name erpnext-sites \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY
```

## 💰 Cost Optimization

### 1. Use Spot Instances (Preview)
```bash
# Deploy with spot instances for non-critical workloads
az container create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-worker-spot \
    --image $ACR_LOGIN_SERVER/erpnext-azure:v14 \
    --cpu 1 \
    --memory 2 \
    --priority Spot \
    --eviction-policy Delete
```

### 2. Optimize Container Sizes
```bash
# Monitor actual resource usage
az monitor metrics list \
    --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerInstance/containerGroups/erpnext-backend \
    --metric-names CpuUsage MemoryUsage \
    --aggregation Average \
    --interval PT1H

# Adjust container sizes based on usage
```

### 3. Schedule Scaling
```bash
# Use Azure Functions to scale down during off-hours
# Create timer-triggered function to stop/start containers
```

## 🎯 Production Considerations

1. **High Availability**: Deploy multiple container groups across availability zones
2. **Disaster Recovery**: Set up geo-replication for database and storage
3. **Security**: Use managed identities instead of keys where possible
4. **Monitoring**: Set up comprehensive dashboards in Azure Monitor
5. **Compliance**: Enable Azure Policy for compliance enforcement

## 📋 Verification Checklist

```bash
# Check all container groups are running
az container list --resource-group $RESOURCE_GROUP --output table

# Verify application is accessible
curl -I http://$FRONTEND_FQDN:8080

# Check database connectivity
az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP \
    --name $DB_SERVER_NAME \
    --query state

# Verify Redis is accessible
az redis show \
    --resource-group $RESOURCE_GROUP \
    --name $REDIS_NAME \
    --query provisioningState

# Check storage account
az storage account show \
    --resource-group $RESOURCE_GROUP \
    --name $STORAGE_ACCOUNT \
    --query provisioningState
```

## ➡️ Next Steps

1. Configure custom domain and SSL certificate
2. Set up continuous deployment from Azure DevOps/GitHub
3. Implement comprehensive monitoring and alerting
4. Configure backup and disaster recovery procedures
5. Review and implement production hardening (see `03-production-managed-setup.md`)

---

**⚠️ Important Notes**:
- Container Instances have a maximum of 4 vCPUs and 16GB RAM per container
- For larger deployments, consider using AKS instead
- Monitor costs as Container Instances are billed per second
- Implement proper secret management using Key Vault
- Regular security updates for container images are essential