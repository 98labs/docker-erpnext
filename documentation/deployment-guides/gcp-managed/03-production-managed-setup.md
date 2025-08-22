# ERPNext Production Setup with Managed Services

## Overview

This guide covers production-ready configurations, security hardening, monitoring, backup strategies, and operational best practices for ERPNext using Google Cloud managed services (Cloud SQL, Memorystore, Cloud Run, and GKE).

## 🔐 Enhanced Security Configuration

### 1. Private Service Connect for Managed Services

```bash
# Create Private Service Connect endpoint for Cloud SQL
gcloud compute addresses create cloudsql-psc-ip \
    --global \
    --purpose=PRIVATE_SERVICE_CONNECT \
    --network=erpnext-vpc

# Create Private Service Connect endpoint
gcloud compute forwarding-rules create cloudsql-psc-endpoint \
    --global \
    --network=erpnext-vpc \
    --address=cloudsql-psc-ip \
    --target-service-attachment=projects/PROJECT_ID/regions/us-central1/serviceAttachments/cloudsql-psc

# Update firewall rules for PSC
gcloud compute firewall-rules create allow-psc-cloudsql \
    --network=erpnext-vpc \
    --allow=tcp:3306 \
    --source-ranges=10.0.0.0/16 \
    --target-tags=cloudsql-psc
```

### 2. Advanced IAM and Service Account Security

```bash
# Create least-privilege service accounts for different components
gcloud iam service-accounts create erpnext-frontend \
    --display-name="ERPNext Frontend Service Account"

gcloud iam service-accounts create erpnext-backend \
    --display-name="ERPNext Backend Service Account"

gcloud iam service-accounts create erpnext-worker \
    --display-name="ERPNext Worker Service Account"

# Grant minimal required permissions
# Backend service permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:erpnext-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:erpnext-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/redis.editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:erpnext-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Worker service permissions (more restricted)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:erpnext-worker@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:erpnext-worker@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Frontend service permissions (most restricted)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:erpnext-frontend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"
```

### 3. Cloud SQL Security Hardening

```bash
# Enable SSL enforcement
gcloud sql instances patch erpnext-db \
    --require-ssl

# Create SSL certificates for secure connections
gcloud sql ssl-certs create erpnext-client-cert \
    --instance=erpnext-db

# Download client certificates
gcloud sql ssl-certs describe erpnext-client-cert \
    --instance=erpnext-db \
    --format="value(cert)" > client-cert.pem

gcloud sql ssl-certs describe erpnext-client-cert \
    --instance=erpnext-db \
    --format="value(private_key)" > client-key.pem

gcloud sql instances describe erpnext-db \
    --format="value(serverCaCert.cert)" > server-ca.pem

# Store SSL certificates in Secret Manager
gcloud secrets create cloudsql-client-cert --data-file=client-cert.pem
gcloud secrets create cloudsql-client-key --data-file=client-key.pem
gcloud secrets create cloudsql-server-ca --data-file=server-ca.pem

# Enable database flags for security
gcloud sql instances patch erpnext-db \
    --database-flags=slow_query_log=on,log_queries_not_using_indexes=on,general_log=off

# Enable audit logging
gcloud sql instances patch erpnext-db \
    --database-flags=log_output=FILE
```

### 4. Memorystore Security Configuration

```bash
# Enable AUTH for Redis
gcloud redis instances update erpnext-redis \
    --region=us-central1 \
    --auth-enabled

# Get AUTH string and store in Secret Manager
AUTH_STRING=$(gcloud redis instances describe erpnext-redis \
    --region=us-central1 \
    --format="value(authString)")

gcloud secrets create redis-auth-string \
    --data-file=<(echo -n "$AUTH_STRING")

# Enable transit encryption
gcloud redis instances update erpnext-redis \
    --region=us-central1 \
    --transit-encryption-mode=SERVER_AUTH
```

### 5. Binary Authorization for Container Security

```bash
# Enable Binary Authorization
gcloud container binauthz policy import policy.yaml

# Create policy.yaml
cat > policy.yaml <<EOF
defaultAdmissionRule:
  requireAttestationsBy:
  - projects/$PROJECT_ID/attestors/prod-attestor
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
clusterAdmissionRules:
  us-central1-a.erpnext-managed-cluster:
    requireAttestationsBy:
    - projects/$PROJECT_ID/attestors/prod-attestor
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
name: projects/$PROJECT_ID/policy
EOF

# Create attestor
gcloud container binauthz attestors create prod-attestor \
    --attestation-authority-note=prod-note \
    --attestation-authority-note-project=$PROJECT_ID
```

## 📊 Advanced Monitoring and Observability

### 1. Custom Metrics and SLOs

```bash
# Create custom metrics for ERPNext
cat > custom-metrics.yaml <<EOF
resources:
- name: erpnext-response-time
  type: logging.v2.LogMetric
  properties:
    name: erpnext_response_time
    description: ERPNext API response time
    filter: >
      resource.type="cloud_run_revision"
      resource.labels.service_name="erpnext-backend"
      httpRequest.latency
    labelExtractors:
      status: EXTRACT(httpRequest.status)
      method: EXTRACT(httpRequest.requestMethod)
    valueExtractor: EXTRACT(httpRequest.latency)
    metricDescriptor:
      metricKind: GAUGE
      valueType: DOUBLE
      displayName: ERPNext Response Time
      
- name: erpnext-error-rate
  type: logging.v2.LogMetric
  properties:
    name: erpnext_error_rate
    description: ERPNext error rate
    filter: >
      resource.type="cloud_run_revision"
      resource.labels.service_name="erpnext-backend"
      severity>=ERROR
    metricDescriptor:
      metricKind: GAUGE
      valueType: INT64
      displayName: ERPNext Error Rate
EOF

gcloud deployment-manager deployments create erpnext-metrics \
    --config custom-metrics.yaml
```

### 2. SLO Configuration

```bash
# Create SLO for ERPNext availability
cat > slo-config.json <<EOF
{
  "displayName": "ERPNext 99.9% Availability SLO",
  "serviceLevelIndicator": {
    "requestBased": {
      "goodTotalRatio": {
        "totalServiceFilter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"erpnext-backend\"",
        "goodServiceFilter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"erpnext-backend\" AND httpRequest.status<500"
      }
    }
  },
  "goal": {
    "performanceGoal": {
      "performanceThreshold": 0.999
    },
    "rollingPeriod": "2592000s"
  }
}
EOF

gcloud alpha monitoring services create \
    --service-id=erpnext-service \
    --display-name="ERPNext Service"

gcloud alpha monitoring slos create \
    --service=erpnext-service \
    --slo-id=erpnext-availability-slo \
    --config-from-file=slo-config.json
```

### 3. Enhanced Alerting

```bash
# Create multi-condition alerting policy
cat > alerting-policy.json <<EOF
{
  "displayName": "ERPNext Production Alerts",
  "documentation": {
    "content": "ERPNext production alerting policy with multiple conditions"
  },
  "conditions": [
    {
      "displayName": "High Error Rate",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"erpnext-backend\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 0.05,
        "duration": "300s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE",
            "crossSeriesReducer": "REDUCE_MEAN"
          }
        ]
      }
    },
    {
      "displayName": "High Response Time",
      "conditionThreshold": {
        "filter": "metric.type=\"custom.googleapis.com/erpnext_response_time\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 2.0,
        "duration": "300s"
      }
    },
    {
      "displayName": "Database Connection Issues",
      "conditionThreshold": {
        "filter": "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/network/connections\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 80,
        "duration": "300s"
      }
    }
  ],
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "projects/$PROJECT_ID/notificationChannels/NOTIFICATION_CHANNEL_ID"
  ]
}
EOF

gcloud alpha monitoring policies create --policy-from-file=alerting-policy.json
```

### 4. Error Reporting Integration

```bash
# Enable Error Reporting for Cloud Run
gcloud run services update erpnext-backend \
    --region=$REGION \
    --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID"

# For GKE, add error reporting agent
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: error-reporting-agent
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: error-reporting-agent
  template:
    metadata:
      labels:
        app: error-reporting-agent
    spec:
      serviceAccountName: error-reporting-agent
      containers:
      - name: error-reporting-agent
        image: gcr.io/google-containers/error-reporting-agent:latest
        env:
        - name: GOOGLE_APPLICATION_CREDENTIALS
          value: /etc/google/auth/application_default_credentials.json
        volumeMounts:
        - name: google-cloud-key
          mountPath: /etc/google/auth
          readOnly: true
      volumes:
      - name: google-cloud-key
        secret:
          secretName: google-cloud-key
EOF
```

## 🗄️ Advanced Backup and Disaster Recovery

### 1. Multi-Region Backup Strategy

```bash
# Create cross-region backup bucket
gsutil mb -l us-east1 gs://erpnext-backups-dr-$PROJECT_ID

# Set up cross-region replication
gsutil versioning set on gs://erpnext-backups-$PROJECT_ID
gsutil versioning set on gs://erpnext-backups-dr-$PROJECT_ID

# Create transfer job for cross-region replication
cat > transfer-job.json <<EOF
{
  "description": "ERPNext cross-region backup replication",
  "status": "ENABLED",
  "projectId": "$PROJECT_ID",
  "transferSpec": {
    "gcsDataSource": {
      "bucketName": "erpnext-backups-$PROJECT_ID"
    },
    "gcsDataSink": {
      "bucketName": "erpnext-backups-dr-$PROJECT_ID"
    },
    "transferOptions": {
      "deleteObjectsUniqueInSink": false
    }
  },
  "schedule": {
    "scheduleStartDate": {
      "year": 2024,
      "month": 1,
      "day": 1
    },
    "scheduleEndDate": {
      "year": 2025,
      "month": 12,
      "day": 31
    },
    "startTimeOfDay": {
      "hours": 6,
      "minutes": 0,
      "seconds": 0
    },
    "repeatInterval": "86400s"
  }
}
EOF

gcloud transfer jobs create --source=transfer-job.json
```

### 2. Automated Recovery Testing

```bash
# Create disaster recovery test script
cat > dr-test.sh <<'EOF'
#!/bin/bash
set -e

PROJECT_ID_DR="erpnext-dr-test"
REGION_DR="us-east1"

echo "Starting DR test..."

# Create test Cloud SQL instance from backup
LATEST_BACKUP=$(gcloud sql backups list --instance=erpnext-db --limit=1 --format="value(id)")
gcloud sql instances create erpnext-db-dr-test \
    --project=$PROJECT_ID_DR \
    --backup=$LATEST_BACKUP \
    --backup-project=$PROJECT_ID \
    --region=$REGION_DR

# Deploy test Cloud Run service
gcloud run deploy erpnext-backend-dr-test \
    --project=$PROJECT_ID_DR \
    --image gcr.io/$PROJECT_ID/erpnext-backend:latest \
    --region $REGION_DR \
    --set-env-vars="DB_CONNECTION_NAME=$PROJECT_ID_DR:$REGION_DR:erpnext-db-dr-test"

# Test application functionality
BACKEND_URL=$(gcloud run services describe erpnext-backend-dr-test \
    --project=$PROJECT_ID_DR \
    --region=$REGION_DR \
    --format="value(status.url)")

# Run health check
if curl -f "$BACKEND_URL/api/method/ping"; then
    echo "DR test successful"
else
    echo "DR test failed"
    exit 1
fi

# Cleanup
gcloud sql instances delete erpnext-db-dr-test --project=$PROJECT_ID_DR --quiet
gcloud run services delete erpnext-backend-dr-test --project=$PROJECT_ID_DR --region=$REGION_DR --quiet

echo "DR test completed and cleaned up"
EOF

chmod +x dr-test.sh

# Schedule monthly DR tests
gcloud scheduler jobs create http dr-test-monthly \
    --location=$REGION \
    --schedule="0 2 1 * *" \
    --uri="https://us-central1-$PROJECT_ID.cloudfunctions.net/dr-test-function" \
    --http-method=POST
```

### 3. Point-in-Time Recovery Procedures

```bash
# Create PITR script
cat > pitr-recovery.sh <<'EOF'
#!/bin/bash
# Point-in-Time Recovery Script

RECOVERY_TIME="$1"
NEW_INSTANCE_NAME="erpnext-db-pitr-$(date +%Y%m%d-%H%M%S)"

if [ -z "$RECOVERY_TIME" ]; then
    echo "Usage: $0 <RECOVERY_TIME>"
    echo "Example: $0 '2024-01-15T14:30:00Z'"
    exit 1
fi

echo "Creating PITR instance for time: $RECOVERY_TIME"

# Create instance from PITR
gcloud sql instances clone erpnext-db $NEW_INSTANCE_NAME \
    --point-in-time="$RECOVERY_TIME"

echo "PITR instance created: $NEW_INSTANCE_NAME"
echo "Connection name: $PROJECT_ID:$REGION:$NEW_INSTANCE_NAME"

# Update application configuration to use new instance
echo "Update your application configuration to use the new instance"
echo "Test the recovery, then promote if successful"
EOF

chmod +x pitr-recovery.sh
```

## 🚀 Performance Optimization

### 1. Database Performance Tuning

```bash
# Optimize Cloud SQL for ERPNext workload
gcloud sql instances patch erpnext-db \
    --database-flags=innodb_buffer_pool_size=75%,innodb_log_file_size=256M,max_connections=200,query_cache_size=64M

# Enable Query Insights for performance monitoring
gcloud sql instances patch erpnext-db \
    --insights-config-query-insights-enabled \
    --insights-config-record-application-tags \
    --insights-config-record-client-address

# Create read replica for read-heavy workloads
gcloud sql instances create erpnext-db-read-replica \
    --master-instance-name=erpnext-db \
    --region=us-central1 \
    --tier=db-n1-standard-1
```

### 2. Redis Performance Optimization

```bash
# Scale Redis instance based on memory usage
gcloud redis instances update erpnext-redis \
    --region=us-central1 \
    --size=5

# Configure maxmemory policies for different use cases
gcloud redis instances update erpnext-redis \
    --region=us-central1 \
    --redis-config maxmemory-policy=allkeys-lru,timeout=300
```

### 3. Application Performance Optimization

For Cloud Run:
```bash
# Optimize Cloud Run for performance
gcloud run services update erpnext-backend \
    --region=$REGION \
    --memory=4Gi \
    --cpu=2 \
    --concurrency=80 \
    --min-instances=2 \
    --max-instances=100 \
    --execution-environment=gen2

# Enable CPU boost
gcloud run services update erpnext-backend \
    --region=$REGION \
    --cpu-boost
```

For GKE:
```bash
# Update GKE deployments with performance optimizations
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend-optimized
  namespace: erpnext
spec:
  replicas: 5
  template:
    spec:
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        env:
        - name: WORKERS
          value: "4"
        - name: THREADS
          value: "2"
        - name: MAX_REQUESTS
          value: "1000"
        - name: MAX_REQUESTS_JITTER
          value: "100"
EOF
```

## 🔧 Advanced Operational Procedures

### 1. Blue-Green Deployment Strategy

```bash
# Create blue-green deployment script for Cloud Run
cat > blue-green-deploy.sh <<'EOF'
#!/bin/bash
set -e

SERVICE_NAME="erpnext-backend"
NEW_IMAGE="$1"
REGION="us-central1"

if [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <new-image>"
    exit 1
fi

echo "Starting blue-green deployment for $SERVICE_NAME"

# Deploy new version with 0% traffic
gcloud run deploy $SERVICE_NAME-green \
    --image=$NEW_IMAGE \
    --region=$REGION \
    --no-traffic

# Run health checks on green version
GREEN_URL=$(gcloud run services describe $SERVICE_NAME-green \
    --region=$REGION --format="value(status.url)")

if ! curl -f "$GREEN_URL/api/method/ping"; then
    echo "Health check failed on green version"
    exit 1
fi

# Gradually shift traffic
echo "Shifting 10% traffic to green version"
gcloud run services update-traffic $SERVICE_NAME \
    --region=$REGION \
    --to-revisions=$SERVICE_NAME-green=10

sleep 30

# Monitor metrics for 5 minutes
echo "Monitoring for 5 minutes..."
sleep 300

# Full cutover
echo "Completing traffic shift to green version"
gcloud run services update-traffic $SERVICE_NAME \
    --region=$REGION \
    --to-revisions=$SERVICE_NAME-green=100

# Cleanup old version after successful deployment
gcloud run revisions delete $(gcloud run revisions list \
    --service=$SERVICE_NAME \
    --region=$REGION \
    --filter="traffic.percent=0" \
    --format="value(metadata.name)" \
    --limit=1) \
    --region=$REGION --quiet

echo "Blue-green deployment completed successfully"
EOF

chmod +x blue-green-deploy.sh
```

### 2. Canary Deployment for GKE

```bash
# Create canary deployment using Argo Rollouts
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: erpnext-backend-rollout
  namespace: erpnext
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 10m}
      - setWeight: 40
      - pause: {duration: 10m}
      - setWeight: 60
      - pause: {duration: 10m}
      - setWeight: 80
      - pause: {duration: 10m}
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: erpnext-backend
      trafficRouting:
        nginx:
          stableIngress: erpnext-ingress
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
EOF
```

### 3. Automated Scaling Policies

```bash
# Create custom autoscaling for Cloud Run based on queue depth
cat > custom-autoscaler.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-autoscaler-config
data:
  config.yaml: |
    metrics:
      - name: redis_queue_depth
        query: |
          redis_queue_depth{instance="$REDIS_HOST:6379"}
        target: 10
        scaleUp:
          threshold: 20
          instances: 2
        scaleDown:
          threshold: 5
          instances: 1
    services:
      - name: erpnext-backend
        region: us-central1
        minInstances: 1
        maxInstances: 50
EOF

# Deploy custom autoscaler as Cloud Function
gcloud functions deploy erpnext-autoscaler \
    --runtime=python39 \
    --trigger-topic=autoscaler-trigger \
    --source=./autoscaler \
    --entry-point=autoscale
```

## 🔍 Compliance and Governance

### 1. Data Governance

```bash
# Enable data loss prevention (DLP)
cat > dlp-config.json <<EOF
{
  "inspectConfig": {
    "infoTypes": [
      {"name": "EMAIL_ADDRESS"},
      {"name": "PHONE_NUMBER"},
      {"name": "CREDIT_CARD_NUMBER"},
      {"name": "IBAN_CODE"}
    ],
    "minLikelihood": "LIKELY",
    "includeQuote": true
  },
  "deidentifyConfig": {
    "infoTypeTransformations": {
      "transformations": [
        {
          "infoTypes": [{"name": "EMAIL_ADDRESS"}],
          "primitiveTransformation": {
            "characterMaskConfig": {
              "maskingCharacter": "*",
              "numberToMask": 5
            }
          }
        }
      ]
    }
  }
}
EOF

gcloud dlp job-triggers create \
    --job-trigger-from-file=dlp-config.json \
    --location=global
```

### 2. Audit Logging Configuration

```bash
# Enable comprehensive audit logging
cat > audit-policy.yaml <<EOF
auditConfig:
- service: cloudsql.googleapis.com
  auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
- service: redis.googleapis.com
  auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
- service: run.googleapis.com
  auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
- service: container.googleapis.com
  auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
EOF

gcloud logging sinks create erpnext-audit-sink \
    bigquery.googleapis.com/projects/$PROJECT_ID/datasets/erpnext_audit_logs \
    --log-filter='protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"'
```

### 3. Security Scanning and Vulnerability Management

```bash
# Enable Container Analysis for vulnerability scanning
gcloud services enable containeranalysis.googleapis.com

# Create security scanning policy
cat > security-policy.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-policy
data:
  policy.rego: |
    package kubernetes.admission
    
    deny[msg] {
        input.request.kind.kind == "Pod"
        input.request.object.spec.containers[_].image
        not starts_with(input.request.object.spec.containers[_].image, "gcr.io/")
        msg := "Only images from gcr.io are allowed"
    }
    
    deny[msg] {
        input.request.kind.kind == "Pod"
        input.request.object.spec.containers[_].securityContext.privileged == true
        msg := "Privileged containers are not allowed"
    }
EOF

kubectl apply -f security-policy.yaml
```

## 📈 Advanced Performance Monitoring

### 1. Application Performance Monitoring (APM)

```bash
# Enable Cloud Trace for distributed tracing
gcloud run services update erpnext-backend \
    --region=$REGION \
    --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID,ENABLE_TRACING=true"

# For GKE, deploy Jaeger for tracing
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 16686
        - containerPort: 14268
        env:
        - name: COLLECTOR_ZIPKIN_HTTP_PORT
          value: "9411"
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger
  namespace: erpnext
spec:
  selector:
    app: jaeger
  ports:
  - name: ui
    port: 16686
    targetPort: 16686
  - name: collector
    port: 14268
    targetPort: 14268
EOF
```

### 2. Custom Business Metrics

```bash
# Create custom business metrics dashboard
cat > business-metrics-dashboard.json <<EOF
{
  "displayName": "ERPNext Business Metrics",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Active Users",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND metric.labels.endpoint=\"/api/method/frappe.auth.get_logged_user\"",
                    "aggregation": {
                      "alignmentPeriod": "3600s",
                      "perSeriesAligner": "ALIGN_COUNT"
                    }
                  }
                }
              }
            ]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Sales Orders Created",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND metric.labels.endpoint=\"/api/resource/Sales Order\"",
                    "aggregation": {
                      "alignmentPeriod": "3600s",
                      "perSeriesAligner": "ALIGN_COUNT"
                    }
                  }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
EOF

gcloud monitoring dashboards create --config-from-file=business-metrics-dashboard.json
```

## 🛡️ Advanced Security Monitoring

### 1. Security Event Detection

```bash
# Create security event detection rules
cat > security-events.yaml <<EOF
resources:
- name: suspicious-login-attempts
  type: logging.v2.LogMetric
  properties:
    name: suspicious_login_attempts
    description: Detect suspicious login attempts
    filter: >
      resource.type="cloud_run_revision"
      resource.labels.service_name="erpnext-backend"
      jsonPayload.event="login_failed"
      jsonPayload.ip_address!=NULL
    labelExtractors:
      ip_address: EXTRACT(jsonPayload.ip_address)
      user: EXTRACT(jsonPayload.user)
    metricDescriptor:
      metricKind: COUNTER
      valueType: INT64

- name: data-export-events
  type: logging.v2.LogMetric
  properties:
    name: data_export_events
    description: Track data export events
    filter: >
      resource.type="cloud_run_revision"
      jsonPayload.event="data_export"
    labelExtractors:
      user: EXTRACT(jsonPayload.user)
      data_type: EXTRACT(jsonPayload.data_type)
    metricDescriptor:
      metricKind: COUNTER
      valueType: INT64
EOF

gcloud deployment-manager deployments create security-metrics \
    --config security-events.yaml
```

### 2. Automated Incident Response

```bash
# Create Cloud Function for automated incident response
cat > incident-response.py <<'EOF'
import json
import logging
from google.cloud import run_v2
from google.cloud import sql_v1

def incident_response(request):
    """Automated incident response function"""
    try:
        alert_data = request.get_json()
        
        # Parse alert
        alert_type = alert_data.get('incident', {}).get('condition_name', '')
        
        if 'High Error Rate' in alert_type:
            # Scale up Cloud Run service
            client = run_v2.ServicesClient()
            service_path = client.service_path(
                project='PROJECT_ID',
                location='us-central1',
                service='erpnext-backend'
            )
            
            # Increase max instances
            service = client.get_service(name=service_path)
            service.spec.template.scaling.max_instance_count = 20
            
            operation = client.update_service(service=service)
            logging.info(f"Scaled up service: {operation.name}")
            
        elif 'Database Connection' in alert_type:
            # Restart Cloud SQL instance if needed
            sql_client = sql_v1.SqlInstancesServiceClient()
            project = 'PROJECT_ID'
            instance = 'erpnext-db'
            
            # Check instance status and restart if needed
            instance_info = sql_client.get(project=project, instance=instance)
            if instance_info.state != 'RUNNABLE':
                sql_client.restart(project=project, instance=instance)
                logging.info(f"Restarted Cloud SQL instance: {instance}")
        
        return {'status': 'success'}
        
    except Exception as e:
        logging.error(f"Incident response failed: {str(e)}")
        return {'status': 'error', 'message': str(e)}, 500
EOF

# Deploy incident response function
gcloud functions deploy incident-response \
    --runtime=python39 \
    --trigger-http \
    --source=. \
    --entry-point=incident_response \
    --service-account=erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com
```

## 🧹 Maintenance and Lifecycle Management

### 1. Automated Updates and Patching

```bash
# Create automated update pipeline
cat > update-pipeline.yaml <<EOF
trigger:
  schedule:
    - cron: "0 2 * * 0"  # Weekly on Sunday at 2 AM
      displayName: Weekly security updates
      branches:
        include:
        - main

stages:
- stage: SecurityScan
  jobs:
  - job: ContainerScan
    steps:
    - task: DockerCompose@0
      inputs:
        action: Run services
        dockerComposeFile: docker-compose.security-scan.yml

- stage: Deploy
  dependsOn: SecurityScan
  condition: succeeded()
  jobs:
  - deployment: UpdateProduction
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
          - script: |
              # Update Cloud SQL instance
              gcloud sql instances patch erpnext-db --maintenance-window-day=SUN --maintenance-window-hour=3
              
              # Update GKE cluster
              gcloud container clusters upgrade erpnext-managed-cluster --zone=us-central1-a
              
              # Update Cloud Run services
              ./blue-green-deploy.sh gcr.io/$PROJECT_ID/erpnext-backend:latest
EOF
```

### 2. Resource Cleanup and Optimization

```bash
# Create resource cleanup script
cat > cleanup-resources.sh <<'EOF'
#!/bin/bash
set -e

echo "Starting resource cleanup..."

# Clean up old Cloud Run revisions
gcloud run revisions list --service=erpnext-backend \
    --region=us-central1 \
    --filter="traffic.percent=0" \
    --format="value(metadata.name)" | \
    head -n -5 | \
    xargs -I {} gcloud run revisions delete {} --region=us-central1 --quiet

# Clean up old container images
gcloud container images list-tags gcr.io/$PROJECT_ID/erpnext-backend \
    --filter="NOT tags:latest" \
    --format="value(digest)" | \
    head -n -10 | \
    xargs -I {} gcloud container images delete gcr.io/$PROJECT_ID/erpnext-backend@{} --quiet

# Clean up old Cloud SQL backups (keep last 30)
gcloud sql backups list --instance=erpnext-db \
    --format="value(id)" | \
    tail -n +31 | \
    xargs -I {} gcloud sql backups delete {} --instance=erpnext-db --quiet

# Clean up old logs (keep last 30 days)
gcloud logging sinks create old-logs-cleanup \
    storage.googleapis.com/cleanup-logs-bucket \
    --log-filter="timestamp<\"$(date -d '30 days ago' -Iseconds)\""

echo "Resource cleanup completed"
EOF

chmod +x cleanup-resources.sh

# Schedule monthly cleanup
gcloud scheduler jobs create http monthly-cleanup \
    --location=us-central1 \
    --schedule="0 3 1 * *" \
    --uri="https://us-central1-$PROJECT_ID.cloudfunctions.net/cleanup-function" \
    --http-method=POST
```

## 📚 Documentation and Knowledge Management

### 1. Automated Documentation Generation

```bash
# Create automated documentation pipeline
cat > generate-docs.sh <<'EOF'
#!/bin/bash
set -e

# Generate infrastructure documentation
echo "# ERPNext Infrastructure Documentation" > infrastructure.md
echo "" >> infrastructure.md
echo "## Cloud SQL Instances" >> infrastructure.md
gcloud sql instances list --format="table(name,region,tier,status)" >> infrastructure.md

echo "" >> infrastructure.md
echo "## Cloud Run Services" >> infrastructure.md
gcloud run services list --format="table(metadata.name,status.url,status.conditions[0].status)" >> infrastructure.md

echo "" >> infrastructure.md
echo "## Memorystore Instances" >> infrastructure.md
gcloud redis instances list --format="table(name,region,tier,state)" >> infrastructure.md

# Generate monitoring documentation
echo "# Monitoring Configuration" > monitoring.md
gcloud alpha monitoring policies list --format="table(displayName,enabled,conditions[0].displayName)" >> monitoring.md

# Upload to Cloud Storage for team access
gsutil cp *.md gs://erpnext-docs-$PROJECT_ID/
EOF

chmod +x generate-docs.sh
```

## 📊 Cost Optimization and FinOps

### 1. Advanced Cost Monitoring

```bash
# Create cost anomaly detection
cat > cost-anomaly-detection.json <<EOF
{
  "displayName": "ERPNext Cost Anomaly Detection",
  "budgetAmount": {
    "specifiedAmount": {
      "currencyCode": "USD",
      "units": "1000"
    }
  },
  "budgetFilter": {
    "projects": ["projects/$PROJECT_ID"],
    "services": [
      "services/95FF-2EF5-5EA1",  # Cloud SQL
      "services/F25A-99A7-26BB",  # Cloud Run
      "services/6F81-5844-456A"   # Memorystore
    ]
  },
  "thresholdRules": [
    {
      "thresholdPercent": 0.8,
      "spendBasis": "FORECASTED_SPEND"
    },
    {
      "thresholdPercent": 1.0,
      "spendBasis": "CURRENT_SPEND"
    }
  ],
  "allUpdatesRule": {
    "pubsubTopic": "projects/$PROJECT_ID/topics/cost-alerts"
  }
}
EOF

gcloud billing budgets create --billing-account=BILLING_ACCOUNT_ID \
    --budget-from-file=cost-anomaly-detection.json
```

### 2. Resource Right-sizing Recommendations

```bash
# Create right-sizing analysis script
cat > rightsizing-analysis.sh <<'EOF'
#!/bin/bash
set -e

echo "ERPNext Resource Right-sizing Analysis"
echo "====================================="

# Analyze Cloud SQL utilization
echo "Cloud SQL CPU Utilization (Last 7 days):"
gcloud logging read "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\"" \
    --freshness=7d \
    --format="table(timestamp,jsonPayload.value)"

# Analyze Cloud Run utilization
echo "Cloud Run Memory Utilization (Last 7 days):"
gcloud logging read "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/memory/utilizations\"" \
    --freshness=7d \
    --format="table(timestamp,jsonPayload.value)"

# Analyze Redis utilization
echo "Redis Memory Utilization (Last 7 days):"
gcloud logging read "resource.type=\"redis_instance\" AND metric.type=\"redis.googleapis.com/stats/memory/usage_ratio\"" \
    --freshness=7d \
    --format="table(timestamp,jsonPayload.value)"

# Generate recommendations
echo ""
echo "Recommendations:"
echo "1. If Cloud SQL CPU < 50%, consider downsizing"
echo "2. If Cloud Run memory < 60%, reduce memory allocation"
echo "3. If Redis memory < 70%, consider smaller instance"
EOF

chmod +x rightsizing-analysis.sh
```

This production setup guide provides comprehensive coverage of security, monitoring, backup, performance optimization, and operational procedures for ERPNext running on Google Cloud managed services. The configuration supports both Cloud Run and GKE deployments with enterprise-grade reliability and security.

## ➡️ Next Steps

1. **Security Audit**: Conduct regular security assessments
2. **Performance Baseline**: Establish performance benchmarks
3. **Disaster Recovery Testing**: Regular DR drills
4. **Cost Optimization**: Monthly cost reviews and optimization
5. **Documentation Updates**: Keep documentation current with changes

---

**⚠️ Important**: Regular reviews and updates of these configurations are essential for maintaining security and performance in production environments.