# ERPNext Cloud Run Deployment with Managed Services

## Overview

This guide provides step-by-step instructions for deploying ERPNext on Google Cloud Run using Cloud SQL for MySQL and Memorystore for Redis. This serverless approach offers automatic scaling, pay-per-use pricing, and minimal operational overhead.

## 🏗️ Architecture Overview

### Cloud Run ERPNext Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Load Balancer │────│   Cloud Run      │────│   Cloud SQL     │
│   (Global)      │    │   (Frontend)     │    │   (MySQL)       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐    ┌─────────────────┐
                       │   Cloud Run      │────│   Memorystore   │
                       │   (Backend API)  │    │   (Redis)       │
                       └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐    ┌─────────────────┐
                       │   Cloud Tasks    │    │   Cloud Storage │
                       │   (Background)   │    │   (Files)       │
                       └──────────────────┘    └─────────────────┘
```

### Key Components
- **Frontend Service**: Nginx serving static assets
- **Backend API Service**: ERPNext application server
- **Background Tasks Service**: Queue processing via Cloud Tasks
- **Scheduled Tasks**: Cloud Scheduler for cron jobs
- **Database**: Cloud SQL (MySQL)
- **Cache**: Memorystore (Redis)
- **File Storage**: Cloud Storage

## 📋 Prerequisites

Ensure you have completed the setup in `00-prerequisites-managed.md`, including:
- VPC network with VPC Access Connector
- Cloud SQL instance
- Memorystore Redis instance
- Service accounts and IAM roles

## 🔧 Service Configuration

### 1. Prepare Environment Variables

```bash
# Set project variables
export PROJECT_ID="erpnext-production"
export REGION="us-central1"
export VPC_CONNECTOR="erpnext-connector"

# Get database connection details
export DB_CONNECTION_NAME=$(gcloud sql instances describe erpnext-db --format="value(connectionName)")
export REDIS_HOST=$(gcloud redis instances describe erpnext-redis --region=$REGION --format="value(host)")

# Domain configuration
export DOMAIN="erpnext.yourdomain.com"
export API_DOMAIN="api.yourdomain.com"
export FILES_DOMAIN="files.yourdomain.com"
```

### 2. Create Cloud Storage Bucket for Files

```bash
# Create bucket for ERPNext files
gsutil mb gs://erpnext-files-$PROJECT_ID

# Set lifecycle policy for file management
gsutil lifecycle set - gs://erpnext-files-$PROJECT_ID <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF

# Set CORS for web access
gsutil cors set - gs://erpnext-files-$PROJECT_ID <<EOF
[
  {
    "origin": ["https://$DOMAIN", "https://$API_DOMAIN"],
    "method": ["GET", "PUT", "POST"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
EOF
```

## 🐳 Custom ERPNext Images for Cloud Run

### 1. Create Dockerfile for Backend Service

```bash
# Create directory for Cloud Run builds
mkdir -p cloud-run-builds/backend
cd cloud-run-builds/backend

# Create Dockerfile
cat > Dockerfile <<EOF
FROM frappe/erpnext-worker:v14

# Install Cloud SQL Proxy
RUN apt-get update && apt-get install -y wget && \
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy && \
    chmod +x cloud_sql_proxy && \
    mv cloud_sql_proxy /usr/local/bin/

# Install Python packages for Cloud Storage
RUN pip install google-cloud-storage google-cloud-secret-manager

# Create startup script
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Copy custom configurations
COPY custom_configs/ /home/frappe/frappe-bench/

# Set Cloud Run specific configurations
ENV PORT=8080
ENV WORKERS=4
ENV TIMEOUT=120

EXPOSE 8080

CMD ["/startup.sh"]
EOF

# Create startup script
cat > startup.sh <<'EOF'
#!/bin/bash
set -e

# Start Cloud SQL Proxy in background
if [ -n "$DB_CONNECTION_NAME" ]; then
    echo "Starting Cloud SQL Proxy..."
    /usr/local/bin/cloud_sql_proxy -instances=$DB_CONNECTION_NAME=tcp:3306 &
    
    # Wait for proxy to be ready
    until nc -z localhost 3306; do
        echo "Waiting for database connection..."
        sleep 2
    done
    echo "Database connection established"
fi

# Set database connection
export DB_HOST="127.0.0.1"
export DB_PORT="3306"

# Initialize site if needed
if [ ! -d "/home/frappe/frappe-bench/sites/frontend" ]; then
    echo "Initializing ERPNext site..."
    cd /home/frappe/frappe-bench
    bench new-site frontend \
        --admin-password "$ADMIN_PASSWORD" \
        --mariadb-root-password "$DB_PASSWORD" \
        --install-app erpnext \
        --set-default
fi

# Start ERPNext
echo "Starting ERPNext backend..."
cd /home/frappe/frappe-bench
exec gunicorn -b 0.0.0.0:$PORT -w $WORKERS -t $TIMEOUT frappe.app:application
EOF

# Build and push image
gcloud builds submit --tag gcr.io/$PROJECT_ID/erpnext-backend:latest
```

### 2. Create Dockerfile for Frontend Service

```bash
# Create directory for frontend build
mkdir -p ../frontend
cd ../frontend

cat > Dockerfile <<EOF
FROM frappe/erpnext-nginx:v14

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Set Cloud Run port
ENV PORT=8080

# Create startup script for Cloud Run
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

EXPOSE 8080

CMD ["/startup.sh"]
EOF

# Create Cloud Run optimized nginx config
cat > nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50m;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Upstream backend API
    upstream backend {
        server api.yourdomain.com:443;
        keepalive 32;
    }

    server {
        listen 8080;
        server_name _;

        # Security headers
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        # Serve static assets from Cloud Storage
        location /assets {
            proxy_pass https://storage.googleapis.com/erpnext-files-PROJECT_ID/assets;
            proxy_set_header Host storage.googleapis.com;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Proxy API requests to backend service
        location /api {
            proxy_pass https://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Serve app from backend
        location / {
            proxy_pass https://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Create startup script
cat > startup.sh <<'EOF'
#!/bin/bash
# Replace PROJECT_ID placeholder in nginx config
sed -i "s/PROJECT_ID/$PROJECT_ID/g" /etc/nginx/nginx.conf

# Update backend upstream with actual API domain
sed -i "s/api.yourdomain.com/$API_DOMAIN/g" /etc/nginx/nginx.conf

# Start nginx
exec nginx -g 'daemon off;'
EOF

# Build and push frontend image
gcloud builds submit --tag gcr.io/$PROJECT_ID/erpnext-frontend:latest
```

### 3. Background Tasks Service

```bash
# Create directory for background tasks
mkdir -p ../background
cd ../background

cat > Dockerfile <<EOF
FROM frappe/erpnext-worker:v14

# Install Cloud SQL Proxy and Cloud Tasks
RUN apt-get update && apt-get install -y wget && \
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy && \
    chmod +x cloud_sql_proxy && \
    mv cloud_sql_proxy /usr/local/bin/

RUN pip install google-cloud-tasks google-cloud-storage

# Copy task processor script
COPY task_processor.py /task_processor.py
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

ENV PORT=8080

EXPOSE 8080

CMD ["/startup.sh"]
EOF

# Create task processor
cat > task_processor.py <<'EOF'
import os
import json
import logging
from flask import Flask, request, jsonify
import frappe
from frappe.utils.background_jobs import execute_job

app = Flask(__name__)

@app.route('/process-task', methods=['POST'])
def process_task():
    """Process background task from Cloud Tasks"""
    try:
        # Get task data
        task_data = request.get_json()
        
        # Set site context
        frappe.init(site='frontend')
        frappe.connect()
        
        # Execute the job
        job_name = task_data.get('job_name')
        kwargs = task_data.get('kwargs', {})
        
        result = execute_job(job_name, **kwargs)
        
        frappe.db.commit()
        frappe.destroy()
        
        return jsonify({'status': 'success', 'result': result})
        
    except Exception as e:
        logging.error(f"Task processing failed: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
EOF

# Create startup script
cat > startup.sh <<'EOF'
#!/bin/bash
set -e

# Start Cloud SQL Proxy
if [ -n "$DB_CONNECTION_NAME" ]; then
    /usr/local/bin/cloud_sql_proxy -instances=$DB_CONNECTION_NAME=tcp:3306 &
    
    until nc -z localhost 3306; do
        echo "Waiting for database connection..."
        sleep 2
    done
fi

export DB_HOST="127.0.0.1"
export DB_PORT="3306"

# Start task processor
cd /home/frappe/frappe-bench
exec python /task_processor.py
EOF

# Build and push background service image
gcloud builds submit --tag gcr.io/$PROJECT_ID/erpnext-background:latest
```

## 🚀 Deploy Cloud Run Services

### 1. Deploy Backend API Service

```bash
# Deploy backend service
gcloud run deploy erpnext-backend \
    --image gcr.io/$PROJECT_ID/erpnext-backend:latest \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --vpc-connector $VPC_CONNECTOR \
    --set-env-vars="DB_CONNECTION_NAME=$DB_CONNECTION_NAME" \
    --set-env-vars="REDIS_HOST=$REDIS_HOST" \
    --set-env-vars="REDIS_PORT=6379" \
    --set-env-vars="PROJECT_ID=$PROJECT_ID" \
    --set-secrets="ADMIN_PASSWORD=erpnext-admin-password:latest" \
    --set-secrets="DB_PASSWORD=erpnext-db-password:latest" \
    --set-secrets="API_KEY=erpnext-api-key:latest" \
    --set-secrets="API_SECRET=erpnext-api-secret:latest" \
    --service-account erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com \
    --memory 2Gi \
    --cpu 2 \
    --concurrency 80 \
    --timeout 300 \
    --min-instances 1 \
    --max-instances 100

# Get backend service URL
export BACKEND_URL=$(gcloud run services describe erpnext-backend --region=$REGION --format="value(status.url)")
echo "Backend URL: $BACKEND_URL"
```

### 2. Deploy Frontend Service

```bash
# Update API_DOMAIN environment variable
export API_DOMAIN=$(echo $BACKEND_URL | sed 's|https://||')

# Deploy frontend service
gcloud run deploy erpnext-frontend \
    --image gcr.io/$PROJECT_ID/erpnext-frontend:latest \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars="PROJECT_ID=$PROJECT_ID" \
    --set-env-vars="API_DOMAIN=$API_DOMAIN" \
    --memory 512Mi \
    --cpu 1 \
    --concurrency 1000 \
    --timeout 60 \
    --min-instances 0 \
    --max-instances 10

# Get frontend service URL
export FRONTEND_URL=$(gcloud run services describe erpnext-frontend --region=$REGION --format="value(status.url)")
echo "Frontend URL: $FRONTEND_URL"
```

### 3. Deploy Background Tasks Service

```bash
# Deploy background service
gcloud run deploy erpnext-background \
    --image gcr.io/$PROJECT_ID/erpnext-background:latest \
    --platform managed \
    --region $REGION \
    --no-allow-unauthenticated \
    --vpc-connector $VPC_CONNECTOR \
    --set-env-vars="DB_CONNECTION_NAME=$DB_CONNECTION_NAME" \
    --set-env-vars="REDIS_HOST=$REDIS_HOST" \
    --set-env-vars="PROJECT_ID=$PROJECT_ID" \
    --set-secrets="DB_PASSWORD=erpnext-db-password:latest" \
    --service-account erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com \
    --memory 1Gi \
    --cpu 1 \
    --concurrency 10 \
    --timeout 900 \
    --min-instances 0 \
    --max-instances 10

# Get background service URL
export BACKGROUND_URL=$(gcloud run services describe erpnext-background --region=$REGION --format="value(status.url)")
echo "Background URL: $BACKGROUND_URL"
```

## 📅 Setup Cloud Scheduler for Scheduled Tasks

### 1. Create Cloud Tasks Queue

```bash
# Create task queue for background jobs
gcloud tasks queues create erpnext-tasks \
    --location=$REGION \
    --max-dispatches-per-second=100 \
    --max-concurrent-dispatches=1000 \
    --max-attempts=3
```

### 2. Create Scheduled Jobs

```bash
# Daily backup job
gcloud scheduler jobs create http erpnext-daily-backup \
    --location=$REGION \
    --schedule="0 2 * * *" \
    --uri="$BACKGROUND_URL/process-task" \
    --http-method=POST \
    --headers="Content-Type=application/json" \
    --message-body='{"job_name": "frappe.utils.backup.daily_backup", "kwargs": {}}' \
    --oidc-service-account-email=erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com

# ERPNext scheduler (every 5 minutes)
gcloud scheduler jobs create http erpnext-scheduler \
    --location=$REGION \
    --schedule="*/5 * * * *" \
    --uri="$BACKGROUND_URL/process-task" \
    --http-method=POST \
    --headers="Content-Type=application/json" \
    --message-body='{"job_name": "frappe.utils.scheduler.execute_all", "kwargs": {}}' \
    --oidc-service-account-email=erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com

# Email queue processor (every minute)
gcloud scheduler jobs create http erpnext-email-queue \
    --location=$REGION \
    --schedule="* * * * *" \
    --uri="$BACKGROUND_URL/process-task" \
    --http-method=POST \
    --headers="Content-Type=application/json" \
    --message-body='{"job_name": "frappe.email.queue.flush", "kwargs": {}}' \
    --oidc-service-account-email=erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com
```

## 🌐 Custom Domain and Load Balancer Setup

### 1. Create Global Load Balancer

```bash
# Create HTTP health check
gcloud compute health-checks create http erpnext-health-check \
    --request-path="/health" \
    --port=8080

# Create backend service for frontend
gcloud compute backend-services create erpnext-frontend-backend \
    --protocol=HTTP \
    --health-checks=erpnext-health-check \
    --global

# Add Cloud Run NEG for frontend
gcloud compute network-endpoint-groups create erpnext-frontend-neg \
    --region=$REGION \
    --network-endpoint-type=serverless \
    --cloud-run-service=erpnext-frontend

gcloud compute backend-services add-backend erpnext-frontend-backend \
    --global \
    --network-endpoint-group=erpnext-frontend-neg \
    --network-endpoint-group-region=$REGION

# Create backend service for API
gcloud compute backend-services create erpnext-api-backend \
    --protocol=HTTP \
    --health-checks=erpnext-health-check \
    --global

# Add Cloud Run NEG for backend API
gcloud compute network-endpoint-groups create erpnext-backend-neg \
    --region=$REGION \
    --network-endpoint-type=serverless \
    --cloud-run-service=erpnext-backend

gcloud compute backend-services add-backend erpnext-api-backend \
    --global \
    --network-endpoint-group=erpnext-backend-neg \
    --network-endpoint-group-region=$REGION
```

### 2. Create URL Map and SSL Certificate

```bash
# Create URL map
gcloud compute url-maps create erpnext-url-map \
    --default-service=erpnext-frontend-backend

# Add path matcher for API routes
gcloud compute url-maps add-path-matcher erpnext-url-map \
    --path-matcher-name=api-matcher \
    --default-service=erpnext-frontend-backend \
    --path-rules="/api/*=erpnext-api-backend,/method/*=erpnext-api-backend"

# Create managed SSL certificate
gcloud compute ssl-certificates create erpnext-ssl-cert \
    --domains=$DOMAIN

# Create HTTPS proxy
gcloud compute target-https-proxies create erpnext-https-proxy \
    --ssl-certificates=erpnext-ssl-cert \
    --url-map=erpnext-url-map

# Create global forwarding rule
gcloud compute forwarding-rules create erpnext-https-rule \
    --global \
    --target-https-proxy=erpnext-https-proxy \
    --ports=443

# Get global IP address
export GLOBAL_IP=$(gcloud compute forwarding-rules describe erpnext-https-rule --global --format="value(IPAddress)")
echo "Global IP: $GLOBAL_IP"
echo "Point your domain $DOMAIN to this IP address"
```

## 🔍 Initialize ERPNext Site

### 1. Run Site Creation

```bash
# Trigger site creation via background service
curl -X POST "$BACKGROUND_URL/process-task" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
    -d '{
        "job_name": "frappe.installer.install_app",
        "kwargs": {
            "site": "frontend",
            "app": "erpnext"
        }
    }'
```

### 2. Alternative: Manual Site Creation

```bash
# Create a temporary Cloud Run job for site creation
gcloud run jobs create erpnext-init-site \
    --image gcr.io/$PROJECT_ID/erpnext-backend:latest \
    --region $REGION \
    --vpc-connector $VPC_CONNECTOR \
    --set-env-vars="DB_CONNECTION_NAME=$DB_CONNECTION_NAME" \
    --set-secrets="ADMIN_PASSWORD=erpnext-admin-password:latest" \
    --set-secrets="DB_PASSWORD=erpnext-db-password:latest" \
    --service-account erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com \
    --memory 2Gi \
    --cpu 2 \
    --max-retries 3 \
    --parallelism 1 \
    --task-count 1 \
    --args="bench,new-site,frontend,--admin-password,\$ADMIN_PASSWORD,--mariadb-root-password,\$DB_PASSWORD,--install-app,erpnext,--set-default"

# Execute the job
gcloud run jobs execute erpnext-init-site --region $REGION --wait
```

## 📊 Monitoring and Observability

### 1. Cloud Run Metrics

```bash
# Enable detailed monitoring
gcloud services enable cloudmonitoring.googleapis.com

# Create custom dashboard
cat > monitoring-dashboard.json <<EOF
{
  "displayName": "ERPNext Cloud Run Dashboard",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Request Count",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"erpnext-backend\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE"
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

gcloud monitoring dashboards create --config-from-file=monitoring-dashboard.json
```

### 2. Alerting Policies

```bash
# Create alerting policy for high error rate
cat > alert-policy.json <<EOF
{
  "displayName": "ERPNext High Error Rate",
  "conditions": [
    {
      "displayName": "Cloud Run Error Rate",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"erpnext-backend\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 0.1,
        "duration": "300s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ]
      }
    }
  ],
  "enabled": true
}
EOF

gcloud alpha monitoring policies create --policy-from-file=alert-policy.json
```

## 🔒 Security Configuration

### 1. Identity-Aware Proxy (Optional)

```bash
# Enable IAP for additional security
gcloud compute backend-services update erpnext-frontend-backend \
    --global \
    --iap=enabled

# Configure OAuth consent screen and IAP settings through Console
echo "Configure IAP through Cloud Console:"
echo "https://console.cloud.google.com/security/iap"
```

### 2. Cloud Armor Security Policies

```bash
# Create security policy
gcloud compute security-policies create erpnext-security-policy \
    --description="ERPNext Cloud Armor policy"

# Add rate limiting rule
gcloud compute security-policies rules create 1000 \
    --security-policy=erpnext-security-policy \
    --expression="true" \
    --action=rate-based-ban \
    --rate-limit-threshold-count=100 \
    --rate-limit-threshold-interval-sec=60 \
    --ban-duration-sec=600 \
    --conform-action=allow \
    --exceed-action=deny-429 \
    --enforce-on-key=IP

# Apply to backend service
gcloud compute backend-services update erpnext-frontend-backend \
    --global \
    --security-policy=erpnext-security-policy
```

## 🗄️ Backup and Disaster Recovery

### 1. Automated Backups

```bash
# Cloud SQL backups are automatic
# Verify backup configuration
gcloud sql instances describe erpnext-db --format="value(settings.backupConfiguration)"

# Create additional backup job for site files
gcloud scheduler jobs create http erpnext-files-backup \
    --location=$REGION \
    --schedule="0 4 * * *" \
    --uri="$BACKGROUND_URL/process-task" \
    --http-method=POST \
    --headers="Content-Type=application/json" \
    --message-body='{"job_name": "custom.backup.backup_files_to_storage", "kwargs": {}}' \
    --oidc-service-account-email=erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com
```

### 2. Disaster Recovery Procedures

```bash
# Create disaster recovery script
cat > disaster_recovery.md <<EOF
# ERPNext Cloud Run Disaster Recovery

## Database Recovery
1. Restore from Cloud SQL backup:
   \`gcloud sql backups restore BACKUP_ID --restore-instance=erpnext-db-new\`

2. Update connection string in Cloud Run services

## Service Recovery
1. Redeploy services:
   \`gcloud run deploy erpnext-backend --image gcr.io/$PROJECT_ID/erpnext-backend:latest\`

2. Verify health checks

## File Recovery
1. Restore from Cloud Storage:
   \`gsutil -m cp -r gs://erpnext-backups/files/ gs://erpnext-files-$PROJECT_ID/\`
EOF
```

## 💰 Cost Optimization

### 1. Service Configuration for Cost Optimization

```bash
# Optimize backend service for cost
gcloud run services update erpnext-backend \
    --region=$REGION \
    --min-instances=0 \
    --max-instances=10 \
    --concurrency=100

# Optimize frontend service
gcloud run services update erpnext-frontend \
    --region=$REGION \
    --min-instances=0 \
    --max-instances=5 \
    --concurrency=1000

# Set up budget alerts
gcloud billing budgets create \
    --billing-account=BILLING_ACCOUNT_ID \
    --display-name="ERPNext Cloud Run Budget" \
    --budget-amount=500USD \
    --threshold-rules-percent=50,90 \
    --threshold-rules-spend-basis=current-spend
```

### 2. Performance Optimization

```bash
# Enable request tracing
gcloud run services update erpnext-backend \
    --region=$REGION \
    --add-cloudsql-instances=$DB_CONNECTION_NAME

# Configure connection pooling
gcloud run services update erpnext-backend \
    --region=$REGION \
    --set-env-vars="DB_MAX_CONNECTIONS=20,DB_POOL_SIZE=10"
```

## 🧪 Testing and Verification

### 1. Service Health Checks

```bash
# Test backend service
curl -f "$BACKEND_URL/api/method/ping"

# Test frontend service
curl -f "$FRONTEND_URL/health"

# Test background service
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
     -f "$BACKGROUND_URL/health"
```

### 2. Load Testing

```bash
# Simple load test
for i in {1..100}; do
    curl -s "$FRONTEND_URL" > /dev/null &
done
wait

echo "Load test completed. Check Cloud Run metrics in console."
```

## 🚨 Troubleshooting

### 1. Common Issues

```bash
# Check service logs
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"erpnext-backend\"" --limit=50

# Check database connectivity
gcloud run services logs read erpnext-backend --region=$REGION --limit=20

# Test VPC connector
gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR --region=$REGION
```

### 2. Performance Issues

```bash
# Check instance allocation
gcloud run services describe erpnext-backend --region=$REGION --format="value(status.traffic[].allocation)"

# Monitor cold starts
gcloud logging read "resource.type=\"cloud_run_revision\" AND textPayload:\"Container called exit\"" --limit=10
```

## 📈 Performance Benefits

### 1. Scalability
- **Auto-scaling**: 0 to 1000+ instances automatically
- **Global distribution**: Multi-region deployment capability
- **Pay-per-use**: No idle costs

### 2. Reliability
- **Managed infrastructure**: Google handles all infrastructure
- **Automatic deployments**: Zero-downtime deployments
- **Health checks**: Automatic instance replacement

### 3. Cost Efficiency
- **No minimum costs**: Pay only for actual usage
- **Automatic optimization**: CPU and memory auto-scaling
- **Reduced operational overhead**: No server management

## 📚 Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Tasks Documentation](https://cloud.google.com/tasks/docs)
- [Cloud Scheduler Documentation](https://cloud.google.com/scheduler/docs)
- [Cloud Run Best Practices](https://cloud.google.com/run/docs/best-practices)

## ➡️ Next Steps

1. **Production Hardening**: Follow `03-production-managed-setup.md`
2. **Monitoring Setup**: Configure detailed monitoring and alerting
3. **Performance Tuning**: Optimize based on usage patterns
4. **Custom Development**: Add custom ERPNext apps and configurations

---

**⚠️ Important Notes**:
- Cloud Run bills per 100ms of CPU time and memory allocation
- Cold starts may affect initial response times
- Database connections should be managed carefully due to Cloud SQL limits
- Consider using Cloud CDN for better global performance