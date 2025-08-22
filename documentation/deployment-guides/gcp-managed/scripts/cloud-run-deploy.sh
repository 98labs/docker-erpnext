#!/bin/bash

# ERPNext Cloud Run Deployment Script with Managed Services
# This script automates the deployment of ERPNext on Cloud Run using Cloud SQL and Memorystore

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${PROJECT_ID:-""}
REGION=${REGION:-"us-central1"}
DOMAIN=${DOMAIN:-"erpnext.yourdomain.com"}
API_DOMAIN=${API_DOMAIN:-"api.yourdomain.com"}

# Managed services configuration
DB_INSTANCE_NAME=${DB_INSTANCE_NAME:-"erpnext-db"}
REDIS_INSTANCE_NAME=${REDIS_INSTANCE_NAME:-"erpnext-redis"}
VPC_NAME=${VPC_NAME:-"erpnext-vpc"}
VPC_CONNECTOR=${VPC_CONNECTOR:-"erpnext-connector"}

# Cloud Run service names
BACKEND_SERVICE=${BACKEND_SERVICE:-"erpnext-backend"}
FRONTEND_SERVICE=${FRONTEND_SERVICE:-"erpnext-frontend"}
BACKGROUND_SERVICE=${BACKGROUND_SERVICE:-"erpnext-background"}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites for Cloud Run deployment..."
    
    # Check if required tools are installed
    local required_tools=("gcloud" "docker")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "$tool is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1 &> /dev/null; then
        print_error "Not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    # Check if project ID is set
    if [[ -z "$PROJECT_ID" ]]; then
        PROJECT_ID=$(gcloud config get-value project)
        if [[ -z "$PROJECT_ID" ]]; then
            print_error "PROJECT_ID not set. Please set it or configure gcloud project."
            exit 1
        fi
    fi
    
    # Check if Docker is configured for gcloud
    if ! gcloud auth configure-docker --quiet; then
        print_error "Failed to configure Docker for gcloud"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to check managed services
check_managed_services() {
    print_status "Checking managed services status..."
    
    # Check Cloud SQL instance
    if ! gcloud sql instances describe "$DB_INSTANCE_NAME" &> /dev/null; then
        print_error "Cloud SQL instance '$DB_INSTANCE_NAME' not found. Please create it first."
        exit 1
    fi
    
    # Check Memorystore Redis instance
    if ! gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" &> /dev/null; then
        print_error "Memorystore Redis instance '$REDIS_INSTANCE_NAME' not found. Please create it first."
        exit 1
    fi
    
    # Check VPC connector
    if ! gcloud compute networks vpc-access connectors describe "$VPC_CONNECTOR" --region="$REGION" &> /dev/null; then
        print_error "VPC connector '$VPC_CONNECTOR' not found. Please create it first."
        exit 1
    fi
    
    print_success "All managed services are available"
}

# Function to get managed services information
get_managed_services_info() {
    print_status "Gathering managed services information..."
    
    # Get Cloud SQL connection name
    DB_CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE_NAME" --format="value(connectionName)")
    print_status "Cloud SQL connection name: $DB_CONNECTION_NAME"
    
    # Get Redis host IP
    REDIS_HOST=$(gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="value(host)")
    print_status "Redis host IP: $REDIS_HOST"
    
    # Get Redis AUTH if enabled
    REDIS_AUTH=""
    if gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="value(authEnabled)" | grep -q "True"; then
        REDIS_AUTH=$(gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="value(authString)")
        print_status "Redis AUTH enabled"
    fi
    
    print_success "Managed services information gathered"
}

# Function to setup Cloud Storage for files
setup_cloud_storage() {
    print_status "Setting up Cloud Storage for ERPNext files..."
    
    local bucket_name="erpnext-files-$PROJECT_ID"
    
    # Create bucket if it doesn't exist
    if ! gsutil ls -b gs://"$bucket_name" &> /dev/null; then
        gsutil mb gs://"$bucket_name"
        print_success "Created Cloud Storage bucket: $bucket_name"
    else
        print_warning "Bucket $bucket_name already exists"
    fi
    
    # Set lifecycle policy
    gsutil lifecycle set - gs://"$bucket_name" <<EOF
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
    gsutil cors set - gs://"$bucket_name" <<EOF
[
  {
    "origin": ["https://$DOMAIN", "https://$API_DOMAIN"],
    "method": ["GET", "PUT", "POST", "DELETE"],
    "responseHeader": ["Content-Type", "Content-Range", "Content-Disposition"],
    "maxAgeSeconds": 3600
  }
]
EOF
    
    print_success "Cloud Storage setup completed"
}

# Function to create and store secrets
setup_secrets() {
    print_status "Setting up secrets in Secret Manager..."
    
    # Create secrets if they don't exist
    if ! gcloud secrets describe erpnext-admin-password &> /dev/null; then
        local admin_password=${ADMIN_PASSWORD:-$(openssl rand -base64 32)}
        gcloud secrets create erpnext-admin-password --data-file=<(echo -n "$admin_password")
        print_warning "Admin password: $admin_password"
        print_warning "Please save this password securely!"
    fi
    
    if ! gcloud secrets describe erpnext-db-password &> /dev/null; then
        local db_password=${DB_PASSWORD:-$(openssl rand -base64 32)}
        gcloud secrets create erpnext-db-password --data-file=<(echo -n "$db_password")
        print_warning "Database password: $db_password"
        print_warning "Please save this password securely!"
    fi
    
    if ! gcloud secrets describe erpnext-api-key &> /dev/null; then
        local api_key=${API_KEY:-$(openssl rand -hex 32)}
        gcloud secrets create erpnext-api-key --data-file=<(echo -n "$api_key")
    fi
    
    if ! gcloud secrets describe erpnext-api-secret &> /dev/null; then
        local api_secret=${API_SECRET:-$(openssl rand -hex 32)}
        gcloud secrets create erpnext-api-secret --data-file=<(echo -n "$api_secret")
    fi
    
    # Store connection information
    gcloud secrets create erpnext-db-connection-name --data-file=<(echo -n "$DB_CONNECTION_NAME") --quiet || \
    gcloud secrets versions add erpnext-db-connection-name --data-file=<(echo -n "$DB_CONNECTION_NAME")
    
    if [[ -n "$REDIS_AUTH" ]]; then
        gcloud secrets create redis-auth-string --data-file=<(echo -n "$REDIS_AUTH") --quiet || \
        gcloud secrets versions add redis-auth-string --data-file=<(echo -n "$REDIS_AUTH")
    fi
    
    print_success "Secrets created in Secret Manager"
}

# Function to build and push container images
build_and_push_images() {
    print_status "Building and pushing container images..."
    
    # Create temporary directory for builds
    local build_dir="/tmp/erpnext-cloudrun-builds"
    mkdir -p "$build_dir"
    
    # Build backend image
    print_status "Building ERPNext backend image..."
    cat > "$build_dir/Dockerfile.backend" <<'EOF'
FROM frappe/erpnext-worker:v14

# Install Cloud SQL Proxy
RUN apt-get update && apt-get install -y wget netcat-openbsd && \
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy && \
    chmod +x cloud_sql_proxy && \
    mv cloud_sql_proxy /usr/local/bin/ && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install additional Python packages
RUN pip install --no-cache-dir google-cloud-storage google-cloud-secret-manager

# Create startup script
COPY startup-backend.sh /startup.sh
RUN chmod +x /startup.sh

# Set environment for Cloud Run
ENV PORT=8080
ENV WORKERS=4
ENV TIMEOUT=300
ENV MAX_REQUESTS=1000

EXPOSE 8080

CMD ["/startup.sh"]
EOF
    
    # Create backend startup script
    cat > "$build_dir/startup-backend.sh" <<'EOF'
#!/bin/bash
set -e

echo "Starting ERPNext backend for Cloud Run..."

# Start Cloud SQL Proxy in background
if [ -n "$DB_CONNECTION_NAME" ]; then
    echo "Starting Cloud SQL Proxy..."
    /usr/local/bin/cloud_sql_proxy -instances=$DB_CONNECTION_NAME=tcp:3306 &
    
    # Wait for proxy to be ready
    echo "Waiting for database connection..."
    until nc -z localhost 3306; do
        sleep 2
    done
    echo "Database connection established"
fi

# Set database connection environment
export DB_HOST="127.0.0.1"
export DB_PORT="3306"

# Set Redis connection
export REDIS_CACHE_URL="redis://$REDIS_HOST:6379/0"
export REDIS_QUEUE_URL="redis://$REDIS_HOST:6379/1"
export REDIS_SOCKETIO_URL="redis://$REDIS_HOST:6379/2"

# Add Redis AUTH if available
if [ -n "$REDIS_AUTH" ]; then
    export REDIS_CACHE_URL="redis://:$REDIS_AUTH@$REDIS_HOST:6379/0"
    export REDIS_QUEUE_URL="redis://:$REDIS_AUTH@$REDIS_HOST:6379/1"
    export REDIS_SOCKETIO_URL="redis://:$REDIS_AUTH@$REDIS_HOST:6379/2"
fi

# Initialize site if it doesn't exist (for first run)
cd /home/frappe/frappe-bench
if [ ! -d "sites/frontend" ] && [ "$INIT_SITE" = "true" ]; then
    echo "Initializing ERPNext site..."
    bench new-site frontend \
        --admin-password "$ADMIN_PASSWORD" \
        --mariadb-root-password "$DB_PASSWORD" \
        --install-app erpnext \
        --set-default
fi

# Start ERPNext with Gunicorn optimized for Cloud Run
echo "Starting ERPNext backend..."
exec gunicorn -b 0.0.0.0:$PORT \
    -w $WORKERS \
    -t $TIMEOUT \
    --max-requests $MAX_REQUESTS \
    --preload \
    --access-logfile - \
    --error-logfile - \
    frappe.app:application
EOF
    
    # Build and push backend image
    cd "$build_dir"
    gcloud builds submit --tag gcr.io/$PROJECT_ID/erpnext-backend-cloudrun:latest \
        --dockerfile=Dockerfile.backend .
    
    # Build frontend image
    print_status "Building ERPNext frontend image..."
    cat > "$build_dir/Dockerfile.frontend" <<'EOF'
FROM nginx:alpine

# Install envsubst for template processing
RUN apk add --no-cache gettext

# Copy nginx configuration template
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY startup-frontend.sh /startup.sh
RUN chmod +x /startup.sh

# Set Cloud Run port
ENV PORT=8080

EXPOSE 8080

CMD ["/startup.sh"]
EOF
    
    # Create nginx configuration template
    cat > "$build_dir/nginx.conf.template" <<'EOF'
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

    upstream backend {
        server ${BACKEND_URL};
        keepalive 32;
    }

    server {
        listen ${PORT};
        server_name _;

        # Security headers
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Referrer-Policy "strict-origin-when-cross-origin";

        # Serve static assets from Cloud Storage
        location /assets/ {
            proxy_pass https://storage.googleapis.com/${STORAGE_BUCKET}/assets/;
            proxy_set_header Host storage.googleapis.com;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Proxy API requests to backend service
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 300s;
        }

        # WebSocket support
        location /socket.io/ {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Main application
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 300s;
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
    
    # Create frontend startup script
    cat > "$build_dir/startup-frontend.sh" <<'EOF'
#!/bin/sh
set -e

echo "Starting ERPNext frontend for Cloud Run..."

# Process nginx configuration template
envsubst '${PORT} ${BACKEND_URL} ${STORAGE_BUCKET}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "Nginx configuration processed"
cat /etc/nginx/nginx.conf

# Start nginx
exec nginx -g 'daemon off;'
EOF
    
    # Build and push frontend image
    gcloud builds submit --tag gcr.io/$PROJECT_ID/erpnext-frontend-cloudrun:latest \
        --dockerfile=Dockerfile.frontend .
    
    # Build background worker image
    print_status "Building ERPNext background worker image..."
    cat > "$build_dir/Dockerfile.background" <<'EOF'
FROM frappe/erpnext-worker:v14

# Install Cloud SQL Proxy and additional tools
RUN apt-get update && apt-get install -y wget netcat-openbsd && \
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy && \
    chmod +x cloud_sql_proxy && \
    mv cloud_sql_proxy /usr/local/bin/ && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install additional Python packages
RUN pip install --no-cache-dir google-cloud-tasks google-cloud-storage flask

# Copy task processor
COPY background_processor.py /background_processor.py
COPY startup-background.sh /startup.sh
RUN chmod +x /startup.sh

ENV PORT=8080

EXPOSE 8080

CMD ["/startup.sh"]
EOF
    
    # Create background processor
    cat > "$build_dir/background_processor.py" <<'EOF'
import os
import json
import logging
from flask import Flask, request, jsonify
import frappe
from frappe.utils.background_jobs import execute_job

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

@app.route('/process-task', methods=['POST'])
def process_task():
    """Process background task from Cloud Tasks or Cloud Scheduler"""
    try:
        # Get task data
        task_data = request.get_json()
        if not task_data:
            return jsonify({'status': 'error', 'message': 'No task data provided'}), 400
        
        # Set site context
        frappe.init(site='frontend')
        frappe.connect()
        
        # Execute the job
        job_name = task_data.get('job_name')
        kwargs = task_data.get('kwargs', {})
        
        if not job_name:
            return jsonify({'status': 'error', 'message': 'No job_name provided'}), 400
        
        logging.info(f"Executing job: {job_name}")
        result = execute_job(job_name, **kwargs)
        
        frappe.db.commit()
        frappe.destroy()
        
        return jsonify({'status': 'success', 'result': str(result)})
        
    except Exception as e:
        logging.error(f"Task processing failed: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

@app.route('/', methods=['GET'])
def root():
    return jsonify({'service': 'erpnext-background', 'status': 'running'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
EOF
    
    # Create background startup script
    cat > "$build_dir/startup-background.sh" <<'EOF'
#!/bin/bash
set -e

echo "Starting ERPNext background processor for Cloud Run..."

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

export DB_HOST="127.0.0.1"
export DB_PORT="3306"

# Start background processor
cd /home/frappe/frappe-bench
exec python /background_processor.py
EOF
    
    # Build and push background image
    gcloud builds submit --tag gcr.io/$PROJECT_ID/erpnext-background-cloudrun:latest \
        --dockerfile=Dockerfile.background .
    
    # Cleanup
    rm -rf "$build_dir"
    
    print_success "Container images built and pushed"
}

# Function to deploy Cloud Run services
deploy_cloud_run_services() {
    print_status "Deploying Cloud Run services..."
    
    # Deploy backend service
    print_status "Deploying backend service..."
    gcloud run deploy "$BACKEND_SERVICE" \
        --image gcr.io/$PROJECT_ID/erpnext-backend-cloudrun:latest \
        --platform managed \
        --region "$REGION" \
        --allow-unauthenticated \
        --vpc-connector "$VPC_CONNECTOR" \
        --set-env-vars="DB_CONNECTION_NAME=$DB_CONNECTION_NAME,REDIS_HOST=$REDIS_HOST,PROJECT_ID=$PROJECT_ID" \
        --set-secrets="ADMIN_PASSWORD=erpnext-admin-password:latest,DB_PASSWORD=erpnext-db-password:latest,API_KEY=erpnext-api-key:latest,API_SECRET=erpnext-api-secret:latest" \
        --service-account "erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --memory 2Gi \
        --cpu 2 \
        --concurrency 80 \
        --timeout 300 \
        --min-instances 1 \
        --max-instances 100
    
    if [[ -n "$REDIS_AUTH" ]]; then
        gcloud run services update "$BACKEND_SERVICE" \
            --region "$REGION" \
            --update-secrets="REDIS_AUTH=redis-auth-string:latest"
    fi
    
    # Get backend service URL
    BACKEND_URL=$(gcloud run services describe "$BACKEND_SERVICE" --region="$REGION" --format="value(status.url)")
    BACKEND_HOSTNAME=$(echo "$BACKEND_URL" | sed 's|https://||')
    
    print_success "Backend service deployed: $BACKEND_URL"
    
    # Deploy frontend service
    print_status "Deploying frontend service..."
    gcloud run deploy "$FRONTEND_SERVICE" \
        --image gcr.io/$PROJECT_ID/erpnext-frontend-cloudrun:latest \
        --platform managed \
        --region "$REGION" \
        --allow-unauthenticated \
        --set-env-vars="BACKEND_URL=$BACKEND_HOSTNAME,STORAGE_BUCKET=erpnext-files-$PROJECT_ID" \
        --memory 512Mi \
        --cpu 1 \
        --concurrency 1000 \
        --timeout 60 \
        --min-instances 0 \
        --max-instances 10
    
    # Get frontend service URL
    FRONTEND_URL=$(gcloud run services describe "$FRONTEND_SERVICE" --region="$REGION" --format="value(status.url)")
    
    print_success "Frontend service deployed: $FRONTEND_URL"
    
    # Deploy background service
    print_status "Deploying background service..."
    gcloud run deploy "$BACKGROUND_SERVICE" \
        --image gcr.io/$PROJECT_ID/erpnext-background-cloudrun:latest \
        --platform managed \
        --region "$REGION" \
        --no-allow-unauthenticated \
        --vpc-connector "$VPC_CONNECTOR" \
        --set-env-vars="DB_CONNECTION_NAME=$DB_CONNECTION_NAME,REDIS_HOST=$REDIS_HOST,PROJECT_ID=$PROJECT_ID" \
        --set-secrets="DB_PASSWORD=erpnext-db-password:latest" \
        --service-account "erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --memory 1Gi \
        --cpu 1 \
        --concurrency 10 \
        --timeout 900 \
        --min-instances 0 \
        --max-instances 10
    
    if [[ -n "$REDIS_AUTH" ]]; then
        gcloud run services update "$BACKGROUND_SERVICE" \
            --region "$REGION" \
            --update-secrets="REDIS_AUTH=redis-auth-string:latest"
    fi
    
    # Get background service URL
    BACKGROUND_URL=$(gcloud run services describe "$BACKGROUND_SERVICE" --region="$REGION" --format="value(status.url)")
    
    print_success "Background service deployed: $BACKGROUND_URL"
}

# Function to initialize ERPNext site
initialize_site() {
    print_status "Initializing ERPNext site..."
    
    # Create a temporary Cloud Run job to initialize the site
    gcloud run jobs create erpnext-init \
        --image gcr.io/$PROJECT_ID/erpnext-backend-cloudrun:latest \
        --region "$REGION" \
        --vpc-connector "$VPC_CONNECTOR" \
        --set-env-vars="DB_CONNECTION_NAME=$DB_CONNECTION_NAME,REDIS_HOST=$REDIS_HOST,INIT_SITE=true" \
        --set-secrets="ADMIN_PASSWORD=erpnext-admin-password:latest,DB_PASSWORD=erpnext-db-password:latest" \
        --service-account "erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --memory 2Gi \
        --cpu 2 \
        --max-retries 3 \
        --parallelism 1 \
        --task-count 1 \
        --task-timeout 1800
    
    if [[ -n "$REDIS_AUTH" ]]; then
        gcloud run jobs update erpnext-init \
            --region "$REGION" \
            --update-secrets="REDIS_AUTH=redis-auth-string:latest"
    fi
    
    # Execute the job
    print_status "Executing site initialization job..."
    gcloud run jobs execute erpnext-init --region "$REGION" --wait
    
    # Check if job succeeded
    local job_status=$(gcloud run jobs describe erpnext-init --region="$REGION" --format="value(status.conditions[0].type)")
    if [[ "$job_status" == "Succeeded" ]]; then
        print_success "ERPNext site initialized successfully"
    else
        print_error "Site initialization failed. Check job logs:"
        gcloud logging read "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"erpnext-init\"" --limit=50
        exit 1
    fi
    
    # Clean up the job
    gcloud run jobs delete erpnext-init --region="$REGION" --quiet
}

# Function to setup Cloud Tasks and Cloud Scheduler
setup_background_processing() {
    print_status "Setting up Cloud Tasks and Cloud Scheduler..."
    
    # Create task queue
    gcloud tasks queues create erpnext-tasks \
        --location="$REGION" \
        --max-dispatches-per-second=100 \
        --max-concurrent-dispatches=1000 \
        --max-attempts=3 || true
    
    # Create scheduled jobs
    print_status "Creating scheduled jobs..."
    
    # ERPNext scheduler (every 5 minutes)
    gcloud scheduler jobs create http erpnext-scheduler \
        --location="$REGION" \
        --schedule="*/5 * * * *" \
        --uri="$BACKGROUND_URL/process-task" \
        --http-method=POST \
        --headers="Content-Type=application/json" \
        --message-body='{"job_name": "frappe.utils.scheduler.execute_all", "kwargs": {}}' \
        --oidc-service-account-email="erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --quiet || true
    
    # Email queue processor (every minute)
    gcloud scheduler jobs create http erpnext-email-queue \
        --location="$REGION" \
        --schedule="* * * * *" \
        --uri="$BACKGROUND_URL/process-task" \
        --http-method=POST \
        --headers="Content-Type=application/json" \
        --message-body='{"job_name": "frappe.email.queue.flush", "kwargs": {}}' \
        --oidc-service-account-email="erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --quiet || true
    
    # Daily backup job
    gcloud scheduler jobs create http erpnext-daily-backup \
        --location="$REGION" \
        --schedule="0 2 * * *" \
        --uri="$BACKGROUND_URL/process-task" \
        --http-method=POST \
        --headers="Content-Type=application/json" \
        --message-body='{"job_name": "frappe.utils.backup.backup_to_cloud", "kwargs": {}}' \
        --oidc-service-account-email="erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --quiet || true
    
    print_success "Background processing setup completed"
}

# Function to setup custom domain and load balancer
setup_custom_domain() {
    print_status "Setting up custom domain and load balancer..."
    
    # Create health check
    gcloud compute health-checks create http erpnext-health-check \
        --request-path="/health" \
        --port=8080 \
        --quiet || true
    
    # Create backend service for frontend
    gcloud compute backend-services create erpnext-frontend-backend \
        --protocol=HTTP \
        --health-checks=erpnext-health-check \
        --global \
        --quiet || true
    
    # Create NEG for frontend service
    gcloud compute network-endpoint-groups create erpnext-frontend-neg \
        --region="$REGION" \
        --network-endpoint-type=serverless \
        --cloud-run-service="$FRONTEND_SERVICE" \
        --quiet || true
    
    gcloud compute backend-services add-backend erpnext-frontend-backend \
        --global \
        --network-endpoint-group=erpnext-frontend-neg \
        --network-endpoint-group-region="$REGION" \
        --quiet || true
    
    # Create URL map
    gcloud compute url-maps create erpnext-url-map \
        --default-service=erpnext-frontend-backend \
        --quiet || true
    
    # Create managed SSL certificate
    gcloud compute ssl-certificates create erpnext-ssl-cert \
        --domains="$DOMAIN" \
        --quiet || true
    
    # Create HTTPS proxy
    gcloud compute target-https-proxies create erpnext-https-proxy \
        --ssl-certificates=erpnext-ssl-cert \
        --url-map=erpnext-url-map \
        --quiet || true
    
    # Create global forwarding rule
    gcloud compute forwarding-rules create erpnext-https-rule \
        --global \
        --target-https-proxy=erpnext-https-proxy \
        --ports=443 \
        --quiet || true
    
    # Get global IP address
    GLOBAL_IP=$(gcloud compute forwarding-rules describe erpnext-https-rule --global --format="value(IPAddress)")
    
    print_success "Custom domain setup completed"
    print_warning "Point your domain $DOMAIN to IP address: $GLOBAL_IP"
}

# Function to show deployment status
show_status() {
    print_status "Cloud Run deployment status:"
    
    echo ""
    echo "=== Cloud Run Services ==="
    gcloud run services list --region="$REGION" --filter="metadata.name:erpnext"
    
    echo ""
    echo "=== Managed Services ==="
    echo "Cloud SQL:"
    gcloud sql instances describe "$DB_INSTANCE_NAME" --format="table(name,state,region)"
    echo ""
    echo "Redis:"
    gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="table(name,state,host)"
    
    echo ""
    echo "=== Cloud Scheduler Jobs ==="
    gcloud scheduler jobs list --location="$REGION" --filter="name:erpnext"
    
    echo ""
    echo "=== Load Balancer ==="
    gcloud compute forwarding-rules list --global --filter="name:erpnext"
    
    echo ""
    echo "=== Service URLs ==="
    echo "Frontend: $(gcloud run services describe "$FRONTEND_SERVICE" --region="$REGION" --format="value(status.url)")"
    echo "Backend API: $(gcloud run services describe "$BACKEND_SERVICE" --region="$REGION" --format="value(status.url)")"
    echo "Custom Domain: https://$DOMAIN (if DNS is configured)"
}

# Function to cleanup deployment
cleanup() {
    print_warning "This will delete the Cloud Run deployment but preserve managed services. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Cleaning up Cloud Run deployment..."
        
        # Delete Cloud Run services
        gcloud run services delete "$FRONTEND_SERVICE" --region="$REGION" --quiet || true
        gcloud run services delete "$BACKEND_SERVICE" --region="$REGION" --quiet || true
        gcloud run services delete "$BACKGROUND_SERVICE" --region="$REGION" --quiet || true
        
        # Delete Cloud Scheduler jobs
        gcloud scheduler jobs delete erpnext-scheduler --location="$REGION" --quiet || true
        gcloud scheduler jobs delete erpnext-email-queue --location="$REGION" --quiet || true
        gcloud scheduler jobs delete erpnext-daily-backup --location="$REGION" --quiet || true
        
        # Delete Cloud Tasks queue
        gcloud tasks queues delete erpnext-tasks --location="$REGION" --quiet || true
        
        # Delete load balancer components
        gcloud compute forwarding-rules delete erpnext-https-rule --global --quiet || true
        gcloud compute target-https-proxies delete erpnext-https-proxy --quiet || true
        gcloud compute ssl-certificates delete erpnext-ssl-cert --quiet || true
        gcloud compute url-maps delete erpnext-url-map --quiet || true
        gcloud compute backend-services delete erpnext-frontend-backend --global --quiet || true
        gcloud compute network-endpoint-groups delete erpnext-frontend-neg --region="$REGION" --quiet || true
        gcloud compute health-checks delete erpnext-health-check --quiet || true
        
        print_success "Cloud Run deployment cleaned up"
        print_warning "Managed services (Cloud SQL, Redis) and container images are preserved"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    echo "ERPNext Cloud Run Deployment Script with Managed Services"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Full Cloud Run deployment (default)"
    echo "  status     - Show deployment status"
    echo "  cleanup    - Delete deployment (preserves managed services)"
    echo "  help       - Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_ID           - GCP Project ID"
    echo "  REGION               - GCP region (default: us-central1)"
    echo "  DOMAIN               - Domain name (default: erpnext.yourdomain.com)"
    echo "  API_DOMAIN           - API domain (default: api.yourdomain.com)"
    echo "  DB_INSTANCE_NAME     - Cloud SQL instance (default: erpnext-db)"
    echo "  REDIS_INSTANCE_NAME  - Memorystore instance (default: erpnext-redis)"
    echo "  VPC_NAME             - VPC network (default: erpnext-vpc)"
    echo "  VPC_CONNECTOR        - VPC connector (default: erpnext-connector)"
    echo ""
    echo "Prerequisites:"
    echo "  - Complete setup in 00-prerequisites-managed.md"
    echo "  - Cloud SQL and Memorystore instances must exist"
    echo "  - VPC network with VPC Access Connector"
    echo ""
    echo "Example:"
    echo "  PROJECT_ID=my-project DOMAIN=erp.mycompany.com $0 deploy"
}

# Main deployment function
main_deploy() {
    print_status "Starting ERPNext Cloud Run deployment with managed services..."
    
    check_prerequisites
    check_managed_services
    get_managed_services_info
    setup_cloud_storage
    setup_secrets
    build_and_push_images
    deploy_cloud_run_services
    initialize_site
    setup_background_processing
    setup_custom_domain
    
    print_success "Cloud Run deployment completed successfully!"
    echo ""
    print_status "Service URLs:"
    print_status "  Frontend: $FRONTEND_URL"
    print_status "  Backend API: $BACKEND_URL"
    print_status "  Custom Domain: https://$DOMAIN (after DNS configuration)"
    echo ""
    print_status "Managed Services:"
    print_status "  Cloud SQL: $DB_CONNECTION_NAME"
    print_status "  Redis: $REDIS_HOST:6379"
    print_status "  Storage: gs://erpnext-files-$PROJECT_ID"
    echo ""
    print_warning "Configure DNS to point $DOMAIN to $GLOBAL_IP"
    print_warning "Retrieve admin password: gcloud secrets versions access latest --secret=erpnext-admin-password"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        main_deploy
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac