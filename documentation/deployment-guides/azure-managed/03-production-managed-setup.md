# Production Setup for ERPNext on Azure with Managed Services

## Overview

This guide covers production hardening, security best practices, performance optimization, and operational excellence for ERPNext deployed on Azure using managed services.

## 🔒 Security Hardening

### 1. Azure AD Integration
```bash
# Source environment variables
source ~/erpnext-azure-env.sh

# Enable Azure AD authentication for PostgreSQL
az postgres flexible-server ad-admin create \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --display-name "ERPNext DB Admins" \
    --object-id $(az ad group show --group "ERPNext-DB-Admins" --query objectId -o tsv)

# Create Azure AD users for application
az ad user create \
    --display-name "ERPNext Service Account" \
    --user-principal-name erpnext-service@yourdomain.onmicrosoft.com \
    --password "ComplexPassword123!"

# Grant database access to Azure AD user
PGPASSWORD=$DB_ADMIN_PASSWORD psql \
    -h $DB_SERVER_NAME.postgres.database.azure.com \
    -U $DB_ADMIN_USER \
    -d erpnext \
    -c "CREATE USER \"erpnext-service@yourdomain.onmicrosoft.com\" WITH LOGIN IN ROLE azure_ad_user;"
```

### 2. Network Security Hardening
```bash
# Enable Azure Firewall
az network firewall create \
    --name erpnext-firewall \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION

# Create firewall policy
az network firewall policy create \
    --name erpnext-fw-policy \
    --resource-group $RESOURCE_GROUP

# Add application rules
az network firewall policy rule-collection-group create \
    --name erpnext-rules \
    --policy-name erpnext-fw-policy \
    --resource-group $RESOURCE_GROUP \
    --priority 100

# Configure DDoS protection
az network ddos-protection create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-ddos \
    --location $LOCATION

az network vnet update \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-vnet \
    --ddos-protection erpnext-ddos
```

### 3. Web Application Firewall (WAF)
```bash
# Create WAF policy
az network application-gateway waf-policy create \
    --name erpnext-waf-policy \
    --resource-group $RESOURCE_GROUP

# Configure WAF rules
az network application-gateway waf-policy managed-rule managed-rule-set add \
    --policy-name erpnext-waf-policy \
    --resource-group $RESOURCE_GROUP \
    --type OWASP \
    --version 3.2

# Enable custom rules for ERPNext
az network application-gateway waf-policy custom-rule create \
    --name BlockSQLInjection \
    --policy-name erpnext-waf-policy \
    --resource-group $RESOURCE_GROUP \
    --priority 10 \
    --rule-type MatchRule \
    --action Block \
    --match-condition "RequestBody Contains 'SELECT * FROM'" \
    --match-condition "RequestBody Contains 'DROP TABLE'"

# Apply WAF policy to Application Gateway
az network application-gateway update \
    --name erpnext-ag \
    --resource-group $RESOURCE_GROUP \
    --waf-policy erpnext-waf-policy
```

### 4. Encryption and Key Management
```bash
# Enable encryption at host for AKS nodes
az aks nodepool update \
    --cluster-name erpnext-aks \
    --name nodepool1 \
    --resource-group $RESOURCE_GROUP \
    --enable-encryption-at-host

# Configure customer-managed keys for database
az keyvault key create \
    --vault-name $KEYVAULT_NAME \
    --name postgres-cmk \
    --kty RSA \
    --size 2048

az postgres flexible-server update \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --key-vault-key-uri https://$KEYVAULT_NAME.vault.azure.net/keys/postgres-cmk

# Enable TDE for database
az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name azure.enable_tde \
    --value on
```

## 📊 Monitoring and Observability

### 1. Comprehensive Monitoring Setup
```bash
# Create Action Group for alerts
az monitor action-group create \
    --name erpnext-alerts \
    --resource-group $RESOURCE_GROUP \
    --short-name ERPAlert \
    --email-receiver admin-email --email-address admin@yourdomain.com \
    --sms-receiver admin-sms --country-code 1 --phone-number 5551234567

# Database monitoring alerts
az monitor metrics alert create \
    --name db-high-cpu \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/flexibleServers/$DB_SERVER_NAME \
    --condition "avg cpu_percent > 80" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action-group erpnext-alerts

az monitor metrics alert create \
    --name db-storage-full \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/flexibleServers/$DB_SERVER_NAME \
    --condition "avg storage_percent > 90" \
    --window-size 5m \
    --evaluation-frequency 5m \
    --action-group erpnext-alerts

# Redis monitoring alerts
az monitor metrics alert create \
    --name redis-high-memory \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Cache/Redis/$REDIS_NAME \
    --condition "avg used_memory_percentage > 90" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action-group erpnext-alerts

# Application monitoring (AKS)
az monitor metrics alert create \
    --name aks-node-not-ready \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/erpnext-aks \
    --condition "avg node_status_condition{condition='Ready',status='false'} > 0" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action-group erpnext-alerts
```

### 2. Log Analytics Queries
```bash
# Create saved queries for common investigations
cat > log-queries.json <<EOF
[
  {
    "name": "ERPNext Error Analysis",
    "query": "ContainerInstanceLog_CL | where Message contains 'ERROR' | summarize ErrorCount=count() by bin(TimeGenerated, 5m), ContainerGroup_s | render timechart"
  },
  {
    "name": "Database Slow Queries",
    "query": "AzureDiagnostics | where ResourceType == 'SERVERS/DATABASES' | where duration_ms > 1000 | project TimeGenerated, query_text_s, duration_ms | order by duration_ms desc"
  },
  {
    "name": "Failed Login Attempts",
    "query": "ContainerInstanceLog_CL | where Message contains 'Failed login' | summarize FailedAttempts=count() by bin(TimeGenerated, 1h), UserName=extract('user: ([^,]+)', 1, Message)"
  },
  {
    "name": "API Response Times",
    "query": "ContainerInstanceLog_CL | where Message contains 'api' | extend ResponseTime=todouble(extract('response_time: ([0-9.]+)', 1, Message)) | summarize avg(ResponseTime), percentile(ResponseTime, 95) by bin(TimeGenerated, 5m)"
  }
]
EOF

# Save queries to Log Analytics
for query in $(cat log-queries.json | jq -c '.[]'); do
    name=$(echo $query | jq -r '.name')
    q=$(echo $query | jq -r '.query')
    az monitor log-analytics workspace saved-search create \
        --workspace-name erpnext-logs \
        --resource-group $RESOURCE_GROUP \
        --name "$name" \
        --category "ERPNext" \
        --display-name "$name" \
        --query "$q" \
        --fa "erpnext"
done
```

### 3. Application Performance Monitoring
```bash
# Configure Application Insights for ERPNext
cat > appinsights-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: appinsights-config
  namespace: erpnext
data:
  applicationinsights.json: |
    {
      "connectionString": "InstrumentationKey=$INSTRUMENTATION_KEY",
      "role": {
        "name": "erpnext-production"
      },
      "sampling": {
        "percentage": 100
      },
      "instrumentation": {
        "logging": {
          "level": "INFO"
        },
        "micrometer": {
          "enabled": true
        }
      }
    }
EOF

kubectl apply -f appinsights-config.yaml

# Add APM agent to deployments
kubectl set env deployment/erpnext-backend \
    -n erpnext \
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$INSTRUMENTATION_KEY" \
    APPLICATIONINSIGHTS_ROLE_NAME="erpnext-backend" \
    APPLICATIONINSIGHTS_PROFILER_ENABLED="true"
```

## 🚀 Performance Optimization

### 1. Database Performance Tuning
```bash
# Optimize PostgreSQL configuration
az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name shared_buffers \
    --value 131072  # 512MB for Standard_D4s_v3

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name effective_cache_size \
    --value 393216  # 1.5GB

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name maintenance_work_mem \
    --value 65536  # 256MB

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name checkpoint_completion_target \
    --value 0.9

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name wal_buffers \
    --value 4096  # 16MB

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name default_statistics_target \
    --value 100

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name random_page_cost \
    --value 1.1  # For SSD storage

# Enable query performance insights
az postgres flexible-server update \
    --name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --performance-tier-enabled true
```

### 2. Redis Cache Optimization
```bash
# Configure Redis for optimal performance
az redis update \
    --name $REDIS_NAME \
    --resource-group $RESOURCE_GROUP \
    --redis-configuration @- <<EOF
{
  "maxmemory-policy": "allkeys-lru",
  "maxmemory-reserved": "50",
  "maxfragmentationmemory-reserved": "50",
  "notify-keyspace-events": "Ex",
  "tcp-keepalive": "60",
  "timeout": "300"
}
EOF

# Enable Redis clustering for Premium tier
az redis create \
    --name erpnext-redis-premium \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Premium \
    --vm-size P1 \
    --shard-count 2 \
    --enable-non-ssl-port false \
    --minimum-tls-version 1.2
```

### 3. CDN Configuration
```bash
# Create CDN profile
az cdn profile create \
    --name erpnext-cdn \
    --resource-group $RESOURCE_GROUP \
    --sku Standard_Microsoft

# Create CDN endpoint
az cdn endpoint create \
    --name erpnext-endpoint \
    --profile-name erpnext-cdn \
    --resource-group $RESOURCE_GROUP \
    --origin $FRONTEND_FQDN \
    --origin-host-header $FRONTEND_FQDN

# Configure caching rules
az cdn endpoint rule add \
    --name CacheStaticAssets \
    --endpoint-name erpnext-endpoint \
    --profile-name erpnext-cdn \
    --resource-group $RESOURCE_GROUP \
    --rule-name CacheStaticAssets \
    --order 1 \
    --match-variable UrlFileExtension \
    --operator Equal \
    --match-values js css png jpg jpeg gif ico woff woff2 \
    --action-name CacheExpiration \
    --cache-behavior Override \
    --cache-duration 7.00:00:00

# Enable compression
az cdn endpoint update \
    --name erpnext-endpoint \
    --profile-name erpnext-cdn \
    --resource-group $RESOURCE_GROUP \
    --compression-enabled true \
    --content-types-to-compress text/plain text/css application/javascript text/javascript application/json
```

## 🔄 Backup and Disaster Recovery

### 1. Automated Backup Strategy
```bash
# Create backup vault
az backup vault create \
    --name erpnext-backup-vault \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION

# Configure database backup policy
az postgres flexible-server backup-policy create \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --backup-retention-days 35 \
    --geo-redundant-backup Enabled

# Create automated backup Logic App
az logic workflow create \
    --resource-group $RESOURCE_GROUP \
    --name erpnext-backup-automation \
    --definition @- <<'EOF'
{
  "definition": {
    "$schema": "https://schema.management.azure.com/schemas/2016-06-01/Microsoft.Logic.json",
    "triggers": {
      "Recurrence": {
        "type": "Recurrence",
        "recurrence": {
          "frequency": "Day",
          "interval": 1,
          "schedule": {
            "hours": ["2"]
          }
        }
      }
    },
    "actions": {
      "BackupDatabase": {
        "type": "Http",
        "inputs": {
          "method": "POST",
          "uri": "[concat('https://management.azure.com/subscriptions/', subscription().subscriptionId, '/resourceGroups/', resourceGroup().name, '/providers/Microsoft.DBforPostgreSQL/flexibleServers/', parameters('dbServerName'), '/backup?api-version=2021-06-01')]",
          "authentication": {
            "type": "ManagedServiceIdentity"
          }
        }
      },
      "BackupFiles": {
        "type": "Http",
        "inputs": {
          "method": "POST",
          "uri": "[concat('https://', parameters('storageAccount'), '.blob.core.windows.net/backups/', utcNow('yyyyMMdd'), '?comp=snapshot')]",
          "authentication": {
            "type": "ManagedServiceIdentity"
          }
        }
      }
    }
  }
}
EOF
```

### 2. Disaster Recovery Setup
```bash
# Create secondary region resources
export DR_LOCATION="westus"
export DR_RESOURCE_GROUP="erpnext-dr-rg"

az group create \
    --name $DR_RESOURCE_GROUP \
    --location $DR_LOCATION

# Create DR database with read replica
az postgres flexible-server replica create \
    --name $DB_SERVER_NAME-dr \
    --resource-group $DR_RESOURCE_GROUP \
    --source-server /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/flexibleServers/$DB_SERVER_NAME \
    --location $DR_LOCATION

# Configure geo-replication for storage
az storage account update \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --sku Standard_RAGRS

# Create Traffic Manager for failover
az network traffic-manager profile create \
    --name erpnext-tm \
    --resource-group $RESOURCE_GROUP \
    --routing-method Priority \
    --unique-dns-name erpnext-global

az network traffic-manager endpoint create \
    --name primary-endpoint \
    --profile-name erpnext-tm \
    --resource-group $RESOURCE_GROUP \
    --type azureEndpoints \
    --target-resource-id /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/publicIPAddresses/erpnext-ag-pip \
    --priority 1

az network traffic-manager endpoint create \
    --name dr-endpoint \
    --profile-name erpnext-tm \
    --resource-group $RESOURCE_GROUP \
    --type azureEndpoints \
    --target-resource-id /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$DR_RESOURCE_GROUP/providers/Microsoft.Network/publicIPAddresses/erpnext-dr-ag-pip \
    --priority 2
```

### 3. Backup Testing Automation
```bash
# Create backup validation runbook
cat > test-backup.ps1 <<'EOF'
param(
    [string]$ResourceGroup,
    [string]$ServerName,
    [string]$BackupName
)

# Restore database to test server
$testServer = "$ServerName-test"
Restore-AzPostgreSqlFlexibleServerDatabase `
    -ResourceGroupName $ResourceGroup `
    -ServerName $testServer `
    -DatabaseName "erpnext-test" `
    -BackupName $BackupName

# Run validation queries
$connection = "Host=$testServer.postgres.database.azure.com;Database=erpnext-test;Username=testuser;Password=$env:DB_PASSWORD"
$result = Invoke-Sqlcmd -Query "SELECT COUNT(*) FROM tabUser" -ConnectionString $connection

if ($result.Count -gt 0) {
    Write-Output "Backup validation successful"
    # Delete test server
    Remove-AzPostgreSqlFlexibleServer `
        -ResourceGroupName $ResourceGroup `
        -ServerName $testServer `
        -Force
} else {
    throw "Backup validation failed"
}
EOF

# Create Azure Automation account
az automation account create \
    --name erpnext-automation \
    --resource-group $RESOURCE_GROUP

# Upload runbook
az automation runbook create \
    --automation-account-name erpnext-automation \
    --resource-group $RESOURCE_GROUP \
    --name TestBackup \
    --type PowerShell \
    --content @test-backup.ps1
```

## 🔐 Compliance and Governance

### 1. Azure Policy Implementation
```bash
# Create custom policies for ERPNext
cat > erpnext-policies.json <<EOF
[
  {
    "name": "Require-TLS-PostgreSQL",
    "description": "Enforce TLS 1.2+ for PostgreSQL connections",
    "rule": {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.DBforPostgreSQL/flexibleServers"
          },
          {
            "field": "Microsoft.DBforPostgreSQL/flexibleServers/minimalTlsVersion",
            "less": "1.2"
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
  },
  {
    "name": "Require-Private-Endpoints",
    "description": "Enforce private endpoints for data services",
    "rule": {
      "if": {
        "anyOf": [
          {
            "field": "type",
            "equals": "Microsoft.DBforPostgreSQL/flexibleServers"
          },
          {
            "field": "type",
            "equals": "Microsoft.Cache/Redis"
          }
        ]
      },
      "then": {
        "effect": "auditIfNotExists",
        "details": {
          "type": "Microsoft.Network/privateEndpoints"
        }
      }
    }
  }
]
EOF

# Apply policies
for policy in $(cat erpnext-policies.json | jq -c '.[]'); do
    name=$(echo $policy | jq -r '.name')
    az policy definition create \
        --name $name \
        --rules "$(echo $policy | jq -r '.rule')" \
        --description "$(echo $policy | jq -r '.description')"
    
    az policy assignment create \
        --name $name-assignment \
        --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP \
        --policy $name
done
```

### 2. Audit Logging
```bash
# Enable audit logging for PostgreSQL
az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name log_statement \
    --value all

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name log_connections \
    --value on

az postgres flexible-server parameter set \
    --server-name $DB_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name log_disconnections \
    --value on

# Configure audit log retention
az monitor diagnostic-settings create \
    --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/flexibleServers/$DB_SERVER_NAME \
    --name audit-logs \
    --workspace /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/erpnext-logs \
    --logs '[{"category": "PostgreSQLLogs", "enabled": true, "retentionPolicy": {"days": 90, "enabled": true}}]'
```

## 📈 Capacity Planning

### 1. Growth Monitoring
```bash
# Create workbook for capacity planning
cat > capacity-workbook.json <<EOF
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": "query",
      "query": "Perf | where ObjectName == 'Processor' | summarize AvgCPU=avg(CounterValue) by bin(TimeGenerated, 1h) | render timechart"
    },
    {
      "type": "query",
      "query": "Perf | where ObjectName == 'Memory' | summarize AvgMemory=avg(CounterValue) by bin(TimeGenerated, 1h) | render timechart"
    },
    {
      "type": "query",
      "query": "AzureMetrics | where MetricName == 'storage_percent' | summarize StorageUsage=avg(Average) by bin(TimeGenerated, 1d) | render timechart"
    }
  ]
}
EOF

az monitor app-insights workbook create \
    --resource-group $RESOURCE_GROUP \
    --name "ERPNext Capacity Planning" \
    --location $LOCATION \
    --display-name "ERPNext Capacity Planning" \
    --category "performance" \
    --serialized-data @capacity-workbook.json
```

### 2. Auto-scaling Configuration
```bash
# Configure predictive autoscaling for AKS
az aks update \
    --name erpnext-aks \
    --resource-group $RESOURCE_GROUP \
    --cluster-autoscaler-profile \
        scale-down-delay-after-add=10m \
        scale-down-unneeded-time=10m \
        scale-down-utilization-threshold=0.5 \
        max-graceful-termination-sec=600 \
        expander=least-waste \
        balance-similar-node-groups=true \
        skip-nodes-with-system-pods=false

# Create scaling rules based on business metrics
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: erpnext-business-hpa
  namespace: erpnext
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erpnext-backend
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: active_users
      target:
        type: AverageValue
        averageValue: "50"
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 25
        periodSeconds: 60
EOF
```

## 🎯 Operational Excellence

### 1. CI/CD Pipeline
```bash
# Create Azure DevOps pipeline
cat > azure-pipelines.yml <<EOF
trigger:
  branches:
    include:
    - main
    - release/*

pool:
  vmImage: 'ubuntu-latest'

variables:
  ACR_NAME: $ACR_NAME
  RESOURCE_GROUP: $RESOURCE_GROUP
  AKS_NAME: erpnext-aks

stages:
- stage: Build
  jobs:
  - job: BuildAndPush
    steps:
    - task: Docker@2
      inputs:
        containerRegistry: 'ACR'
        repository: 'erpnext'
        command: 'buildAndPush'
        Dockerfile: '**/Dockerfile'
        tags: |
          \$(Build.BuildId)
          latest

- stage: Test
  jobs:
  - job: IntegrationTests
    steps:
    - script: |
        docker run --rm \
          -e DB_HOST=test-db \
          -e REDIS_HOST=test-redis \
          \$(ACR_NAME).azurecr.io/erpnext:\$(Build.BuildId) \
          bench run-tests

- stage: Deploy
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: Production
    environment: 'production'
    strategy:
      canary:
        increments: [10, 25, 50]
        preDeploy:
          steps:
          - script: kubectl create namespace canary-\$(Build.BuildId)
        deploy:
          steps:
          - task: KubernetesManifest@0
            inputs:
              action: 'deploy'
              manifests: 'k8s/*.yaml'
              containers: '\$(ACR_NAME).azurecr.io/erpnext:\$(Build.BuildId)'
              imagePullSecrets: 'acr-secret'
              namespace: 'erpnext'
              strategy: 'canary'
              percentage: \$(strategy.increment)
        postRouteTraffic:
          steps:
          - script: |
              # Run smoke tests
              curl -f https://erpnext.yourdomain.com/health || exit 1
        on:
          failure:
            steps:
            - script: kubectl rollout undo deployment/erpnext-backend -n erpnext
EOF
```

### 2. Chaos Engineering
```bash
# Install Chaos Mesh for resilience testing
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh \
    --namespace chaos-testing \
    --create-namespace

# Create chaos experiments
kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay
  namespace: erpnext
spec:
  action: delay
  mode: all
  selector:
    namespaces:
    - erpnext
  delay:
    latency: "100ms"
    correlation: "25"
    jitter: "10ms"
  duration: "5m"
  scheduler:
    cron: "@weekly"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure
  namespace: erpnext
spec:
  action: pod-failure
  mode: random-max-percent
  value: "25"
  selector:
    namespaces:
    - erpnext
    labelSelectors:
      app: erpnext-backend
  duration: "2m"
  scheduler:
    cron: "0 10 * * 5"
EOF
```

## 📋 Health Checks and SLOs

### 1. Service Level Objectives
```bash
# Define SLOs
cat > slos.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-slos
  namespace: erpnext
data:
  slos.json: |
    {
      "objectives": [
        {
          "name": "API Availability",
          "target": 99.9,
          "window": "30d",
          "query": "sum(rate(http_requests_total{status!~'5..'}[5m])) / sum(rate(http_requests_total[5m]))"
        },
        {
          "name": "P95 Latency",
          "target": 500,
          "unit": "ms",
          "window": "1h",
          "query": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
        },
        {
          "name": "Error Rate",
          "target": 0.1,
          "unit": "%",
          "window": "1h",
          "query": "sum(rate(http_requests_total{status=~'5..'}[5m])) / sum(rate(http_requests_total[5m])) * 100"
        }
      ]
    }
EOF

# Create SLO dashboard
az portal dashboard create \
    --name "ERPNext SLO Dashboard" \
    --resource-group $RESOURCE_GROUP \
    --input-path slo-dashboard.json
```

## 🔒 Security Scanning

### 1. Container Security
```bash
# Enable Azure Defender for containers
az security pricing create \
    --name "Containers" \
    --tier "Standard"

# Configure vulnerability scanning
az acr config content-trust update \
    --name $ACR_NAME \
    --status enabled

# Create security scanning policy
az policy assignment create \
    --name "container-security-baseline" \
    --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP \
    --policy-set-definition "13ce6597-3d64-49bf-bfa8-2cdf0aee0f14"
```

## 📋 Maintenance Procedures

### 1. Rolling Updates
```bash
# Create maintenance window configuration
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: maintenance-window
  namespace: erpnext
data:
  schedule: "0 2 * * SUN"
  duration: "4h"
  notification_lead_time: "48h"
EOF

# Update script for zero-downtime deployment
cat > rolling-update.sh <<'EOF'
#!/bin/bash
set -e

echo "Starting rolling update..."

# Scale up before update
kubectl scale deployment/erpnext-backend --replicas=6 -n erpnext
kubectl scale deployment/erpnext-frontend --replicas=4 -n erpnext

# Wait for scale up
kubectl wait --for=condition=available --timeout=300s deployment/erpnext-backend -n erpnext

# Perform rolling update
kubectl set image deployment/erpnext-backend backend=$ACR_LOGIN_SERVER/erpnext:$NEW_VERSION -n erpnext
kubectl set image deployment/erpnext-frontend frontend=$ACR_LOGIN_SERVER/erpnext-nginx:$NEW_VERSION -n erpnext

# Monitor rollout
kubectl rollout status deployment/erpnext-backend -n erpnext
kubectl rollout status deployment/erpnext-frontend -n erpnext

# Scale back down
kubectl scale deployment/erpnext-backend --replicas=3 -n erpnext
kubectl scale deployment/erpnext-frontend --replicas=2 -n erpnext

echo "Rolling update completed successfully"
EOF

chmod +x rolling-update.sh
```

## ✅ Production Readiness Checklist

- [ ] **Security**
  - [ ] Azure AD authentication enabled
  - [ ] Network security groups configured
  - [ ] WAF enabled and configured
  - [ ] Encryption at rest and in transit
  - [ ] Key Vault integration
  - [ ] Regular security scanning

- [ ] **Monitoring**
  - [ ] All critical metrics monitored
  - [ ] Alert rules configured
  - [ ] Dashboards created
  - [ ] Log aggregation setup
  - [ ] APM configured

- [ ] **Backup & DR**
  - [ ] Automated backups configured
  - [ ] Backup testing automated
  - [ ] DR site configured
  - [ ] RTO/RPO documented
  - [ ] Failover procedures tested

- [ ] **Performance**
  - [ ] Database optimized
  - [ ] Caching configured
  - [ ] CDN enabled
  - [ ] Auto-scaling configured
  - [ ] Load testing completed

- [ ] **Operational**
  - [ ] CI/CD pipeline setup
  - [ ] Documentation complete
  - [ ] Runbooks created
  - [ ] On-call rotation established
  - [ ] Incident response plan

---

**📝 Next Steps**:
1. Review and customize configurations for your specific requirements
2. Conduct security assessment and penetration testing
3. Perform load testing and capacity planning
4. Train operations team on procedures
5. Schedule regular disaster recovery drills