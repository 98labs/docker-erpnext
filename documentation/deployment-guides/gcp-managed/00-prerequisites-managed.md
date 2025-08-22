# Google Cloud Prerequisites for ERPNext with Managed Services

## Overview

This guide covers the prerequisites and initial setup required for deploying ERPNext on Google Cloud Platform (GCP) using managed database services: Cloud SQL for MySQL and Memorystore for Redis.

## 🔧 Required Tools

### 1. Google Cloud SDK
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize gcloud
gcloud init
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 2. kubectl (Kubernetes CLI) - For GKE Option
```bash
# Install kubectl
gcloud components install kubectl

# Verify installation
kubectl version --client
```

### 3. Docker (for local testing and Cloud Run)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Enable Docker BuildKit
export DOCKER_BUILDKIT=1
```

### 4. Helm (for GKE Kubernetes package management)
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## 🏗️ Google Cloud Project Setup

### 1. Create or Select Project
```bash
# Create new project
gcloud projects create erpnext-production --name="ERPNext Production"

# Set as current project
gcloud config set project erpnext-production

# Enable billing (required for most services)
# This must be done via the Console: https://console.cloud.google.com/billing
```

### 2. Enable Required APIs
```bash
# Enable essential APIs for managed services deployment
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    redis.googleapis.com \
    secretmanager.googleapis.com \
    cloudbuild.googleapis.com \
    cloudresourcemanager.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    run.googleapis.com \
    vpcaccess.googleapis.com \
    servicenetworking.googleapis.com
```

### 3. Set Default Region/Zone
```bash
# Set default compute region and zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Verify configuration
gcloud config list
```

## 🔐 Security Setup

### 1. Service Account Creation
```bash
# Create service account for ERPNext
gcloud iam service-accounts create erpnext-managed \
    --display-name="ERPNext Managed Services Account" \
    --description="Service account for ERPNext with managed database services"

# Grant necessary roles for managed services
gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-managed@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-managed@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/redis.editor"

gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-managed@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# For GKE deployment
gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-managed@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/container.developer"

# For Cloud Run deployment
gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-managed@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/run.developer"
```

### 2. Create Service Account Key (for local development)
```bash
# Generate service account key
gcloud iam service-accounts keys create ~/erpnext-managed-key.json \
    --iam-account=erpnext-managed@erpnext-production.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/erpnext-managed-key.json
```

### 3. Secret Manager Setup
```bash
# Create secrets for ERPNext
gcloud secrets create erpnext-admin-password \
    --data-file=<(echo -n "YourSecurePassword123!")

gcloud secrets create erpnext-db-password \
    --data-file=<(echo -n "YourDBPassword123!")

gcloud secrets create erpnext-api-key \
    --data-file=<(echo -n "your-api-key-here")

gcloud secrets create erpnext-api-secret \
    --data-file=<(echo -n "your-api-secret-here")

# Additional secret for database connection
gcloud secrets create erpnext-db-connection-name \
    --data-file=<(echo -n "erpnext-production:us-central1:erpnext-db")
```

## 🌐 Networking Setup

### 1. VPC Network for Private Services
```bash
# Create custom VPC network for managed services
gcloud compute networks create erpnext-vpc \
    --subnet-mode=custom

# Create subnet for compute resources
gcloud compute networks subnets create erpnext-subnet \
    --network=erpnext-vpc \
    --range=10.0.0.0/24 \
    --region=us-central1

# Create subnet for private services (Cloud SQL, Memorystore)
gcloud compute networks subnets create erpnext-private-subnet \
    --network=erpnext-vpc \
    --range=10.1.0.0/24 \
    --region=us-central1

# Allocate IP range for private services
gcloud compute addresses create erpnext-private-ip-range \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --network=erpnext-vpc

# Create private connection for managed services
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=erpnext-private-ip-range \
    --network=erpnext-vpc
```

### 2. VPC Access Connector (for Cloud Run)
```bash
# Create VPC access connector for Cloud Run to access private services
gcloud compute networks vpc-access connectors create erpnext-connector \
    --network=erpnext-vpc \
    --region=us-central1 \
    --range=10.2.0.0/28 \
    --min-instances=2 \
    --max-instances=10
```

### 3. Firewall Rules
```bash
# Create firewall rules
gcloud compute firewall-rules create erpnext-allow-internal \
    --network=erpnext-vpc \
    --allow=tcp,udp,icmp \
    --source-ranges=10.0.0.0/16

gcloud compute firewall-rules create erpnext-allow-http \
    --network=erpnext-vpc \
    --allow=tcp:80,tcp:443,tcp:8080 \
    --source-ranges=0.0.0.0/0

# Allow Cloud SQL connections
gcloud compute firewall-rules create erpnext-allow-mysql \
    --network=erpnext-vpc \
    --allow=tcp:3306 \
    --source-ranges=10.0.0.0/16,10.1.0.0/16,10.2.0.0/28

# Allow Redis connections
gcloud compute firewall-rules create erpnext-allow-redis \
    --network=erpnext-vpc \
    --allow=tcp:6379 \
    --source-ranges=10.0.0.0/16,10.1.0.0/16,10.2.0.0/28
```

## 💾 Managed Database Services Setup

### 1. Cloud SQL (MySQL) Instance
```bash
# Create Cloud SQL instance
gcloud sql instances create erpnext-db \
    --database-version=MYSQL_8_0 \
    --tier=db-n1-standard-2 \
    --region=us-central1 \
    --network=erpnext-vpc \
    --no-assign-ip \
    --storage-size=100GB \
    --storage-type=SSD \
    --storage-auto-increase \
    --backup \
    --backup-start-time=02:00 \
    --maintenance-window-day=SUN \
    --maintenance-window-hour=3 \
    --maintenance-release-channel=production \
    --deletion-protection

# Create database
gcloud sql databases create erpnext --instance=erpnext-db

# Create database user
gcloud sql users create erpnext \
    --instance=erpnext-db \
    --password=YourDBPassword123!

# Get connection name for applications
gcloud sql instances describe erpnext-db --format="value(connectionName)"
```

### 2. Memorystore (Redis) Instance
```bash
# Create Memorystore Redis instance
gcloud redis instances create erpnext-redis \
    --size=1 \
    --region=us-central1 \
    --network=erpnext-vpc \
    --redis-version=redis_6_x \
    --maintenance-window-day=sunday \
    --maintenance-window-hour=3 \
    --redis-config maxmemory-policy=allkeys-lru

# Get Redis host IP for applications
gcloud redis instances describe erpnext-redis --region=us-central1 --format="value(host)"
```

### 3. Database Initialization
```bash
# Create initialization script
cat > /tmp/init_erpnext_db.sql <<EOF
-- Create ERPNext database with proper charset
CREATE DATABASE IF NOT EXISTS erpnext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges to erpnext user
GRANT ALL PRIVILEGES ON erpnext.* TO 'erpnext'@'%';
FLUSH PRIVILEGES;

-- Set MySQL configurations for ERPNext
SET GLOBAL innodb_file_format = Barracuda;
SET GLOBAL innodb_large_prefix = 1;
SET GLOBAL innodb_file_per_table = 1;
SET GLOBAL character_set_server = utf8mb4;
SET GLOBAL collation_server = utf8mb4_unicode_ci;
EOF

# Apply initialization script
gcloud sql connect erpnext-db --user=root < /tmp/init_erpnext_db.sql
```

## 📊 Monitoring and Logging

### 1. Enable Enhanced Monitoring
```bash
# Enable enhanced monitoring for Cloud SQL
gcloud sql instances patch erpnext-db \
    --insights-config-query-insights-enabled \
    --insights-config-record-application-tags \
    --insights-config-record-client-address

# Monitoring is enabled by default for Memorystore
# Verify monitoring is working
gcloud logging logs list --limit=5
```

### 2. Create Log-based Metrics
```bash
# Create custom log metric for ERPNext errors
gcloud logging metrics create erpnext_errors \
    --description="ERPNext application errors" \
    --log-filter='resource.type="cloud_run_revision" OR resource.type="k8s_container" AND severity="ERROR"'

# Create metric for Cloud SQL slow queries
gcloud logging metrics create erpnext_slow_queries \
    --description="ERPNext slow database queries" \
    --log-filter='resource.type="cloudsql_database" AND protoPayload.methodName="cloudsql.instances.query" AND protoPayload.request.query_time > 1'
```

## 🔍 Verification Checklist

Before proceeding to deployment, verify:

```bash
# Check project and authentication
gcloud auth list
gcloud config get-value project

# Verify APIs are enabled
gcloud services list --enabled | grep -E "(container|compute|sql|redis|run)"

# Check service account exists
gcloud iam service-accounts list | grep erpnext-managed

# Verify secrets are created
gcloud secrets list | grep erpnext

# Check VPC network
gcloud compute networks list | grep erpnext-vpc

# Verify Cloud SQL instance
gcloud sql instances list | grep erpnext-db

# Check Memorystore instance
gcloud redis instances list --region=us-central1 | grep erpnext-redis

# Test VPC connector (for Cloud Run)
gcloud compute networks vpc-access connectors list --region=us-central1 | grep erpnext-connector

# Check private service connection
gcloud services vpc-peerings list --network=erpnext-vpc
```

## 💡 Cost Optimization for Managed Services

### 1. Cloud SQL Optimization
```bash
# Use appropriate machine types
# Development: db-f1-micro or db-g1-small
# Production: db-n1-standard-2 or higher

# Enable automatic storage increases
gcloud sql instances patch erpnext-db \
    --storage-auto-increase

# Use regional persistent disks for HA
gcloud sql instances patch erpnext-db \
    --availability-type=REGIONAL  # Only for production
```

### 2. Memorystore Optimization
```bash
# Right-size Redis instance
# Start with 1GB and scale based on usage
# Monitor memory utilization and adjust

# Use basic tier for non-HA workloads
# Use standard tier only for production HA requirements
```

### 3. Network Cost Optimization
```bash
# Use same region for all services to minimize egress costs
# Monitor VPC connector usage for Cloud Run
# Consider shared VPC for multiple projects
```

## 🚨 Security Best Practices for Managed Services

### 1. Network Security
- **Private IP only**: All managed services use private IPs
- **VPC peering**: Secure communication within VPC
- **No public access**: Database and Redis not accessible from internet

### 2. Access Control
```bash
# Use IAM database authentication (Cloud SQL)
gcloud sql instances patch erpnext-db \
    --database-flags=cloudsql_iam_authentication=on

# Create IAM database user
gcloud sql users create erpnext-iam-user \
    --instance=erpnext-db \
    --type=cloud_iam_service_account \
    --iam-account=erpnext-managed@erpnext-production.iam.gserviceaccount.com
```

### 3. Encryption
- **Encryption at rest**: Enabled by default for both services
- **Encryption in transit**: SSL/TLS enforced
- **Customer-managed keys**: Optional for additional security

## 📚 Additional Resources

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Memorystore Documentation](https://cloud.google.com/memorystore/docs)
- [VPC Documentation](https://cloud.google.com/vpc/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)

## ➡️ Next Steps

After completing prerequisites:
1. **GKE with Managed Services**: Follow `01-gke-managed-deployment.md`
2. **Cloud Run Deployment**: Follow `02-cloud-run-deployment.md`
3. **Production Hardening**: See `03-production-managed-setup.md`

---

**⚠️ Important Notes**:
- Managed services incur continuous costs even when not in use
- Plan your backup and disaster recovery strategy
- Monitor costs regularly using Cloud Billing
- Keep track of all resources created for billing purposes