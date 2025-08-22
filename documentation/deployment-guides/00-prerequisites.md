# Google Cloud Prerequisites for ERPNext Deployment

## Overview

This guide covers the prerequisites and initial setup required for deploying ERPNext on Google Cloud Platform (GCP).

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

### 2. kubectl (Kubernetes CLI)
```bash
# Install kubectl
gcloud components install kubectl

# Verify installation
kubectl version --client
```

### 3. Docker (for local testing)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Enable Docker BuildKit
export DOCKER_BUILDKIT=1
```

### 4. Helm (for Kubernetes package management)
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
# Enable essential APIs
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    secretmanager.googleapis.com \
    cloudbuild.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com
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
gcloud iam service-accounts create erpnext-gke \
    --display-name="ERPNext GKE Service Account" \
    --description="Service account for ERPNext GKE deployment"

# Grant necessary roles
gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-gke@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/container.developer"

gcloud projects add-iam-policy-binding erpnext-production \
    --member="serviceAccount:erpnext-gke@erpnext-production.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### 2. Create Service Account Key (Optional)
```bash
# Generate service account key (for local development)
gcloud iam service-accounts keys create ~/erpnext-gke-key.json \
    --iam-account=erpnext-gke@erpnext-production.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/erpnext-gke-key.json
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
```

## 💾 Storage Configuration

### 1. Cloud SQL (Managed Database Option)
```bash
# Create Cloud SQL instance for production
gcloud sql instances create erpnext-db \
    --database-version=MYSQL_8_0 \
    --cpu=2 \
    --memory=7680MB \
    --storage-size=100GB \
    --storage-type=SSD \
    --region=us-central1 \
    --backup \
    --maintenance-window-day=SUN \
    --maintenance-window-hour=3

# Create database
gcloud sql databases create erpnext --instance=erpnext-db

# Create database user
gcloud sql users create erpnext \
    --instance=erpnext-db \
    --password=YourDBPassword123!
```

### 2. Persistent Disks (for GKE Storage)
```bash
# Create persistent disks for ERPNext data
gcloud compute disks create erpnext-sites-disk \
    --size=50GB \
    --type=pd-ssd \
    --zone=us-central1-a

gcloud compute disks create erpnext-assets-disk \
    --size=20GB \
    --type=pd-ssd \
    --zone=us-central1-a
```

## 🌐 Networking Setup

### 1. VPC Network (Optional - for advanced setups)
```bash
# Create custom VPC network
gcloud compute networks create erpnext-vpc \
    --subnet-mode=custom

# Create subnet
gcloud compute networks subnets create erpnext-subnet \
    --network=erpnext-vpc \
    --range=10.0.0.0/24 \
    --region=us-central1

# Create firewall rules
gcloud compute firewall-rules create erpnext-allow-internal \
    --network=erpnext-vpc \
    --allow=tcp,udp,icmp \
    --source-ranges=10.0.0.0/24

gcloud compute firewall-rules create erpnext-allow-http \
    --network=erpnext-vpc \
    --allow=tcp:80,tcp:443,tcp:8080 \
    --source-ranges=0.0.0.0/0
```

## 📊 Monitoring and Logging

### 1. Enable Monitoring
```bash
# Monitoring is enabled by default with the APIs
# Verify monitoring is working
gcloud logging logs list --limit=5
```

### 2. Create Log-based Metrics (Optional)
```bash
# Create custom log metric for ERPNext errors
gcloud logging metrics create erpnext_errors \
    --description="ERPNext application errors" \
    --log-filter='resource.type="k8s_container" AND resource.labels.container_name="backend" AND severity="ERROR"'
```

## 🔍 Verification Checklist

Before proceeding to deployment, verify:

```bash
# Check project and authentication
gcloud auth list
gcloud config get-value project

# Verify APIs are enabled
gcloud services list --enabled | grep -E "(container|compute|sql)"

# Check service account exists
gcloud iam service-accounts list | grep erpnext-gke

# Verify secrets are created
gcloud secrets list | grep erpnext

# Check kubectl configuration
kubectl cluster-info --show-labels 2>/dev/null || echo "GKE cluster not yet created"
```

## 💡 Cost Optimization Tips

### 1. Use Preemptible Instances
- For non-production workloads
- 60-91% cost savings
- Automatic restarts handled by Kubernetes

### 2. Right-size Resources
- Start with smaller instances
- Monitor usage and scale as needed
- Use Horizontal Pod Autoscaler

### 3. Storage Optimization
- Use Standard persistent disks for non-critical data
- Enable automatic storage increases
- Regular cleanup of logs and temporary files

## 🚨 Security Best Practices

1. **Never commit secrets to code**
   - Always use Secret Manager
   - Use Workload Identity when possible

2. **Network Security**
   - Use private GKE clusters
   - Implement proper firewall rules
   - Enable network policies

3. **Access Control**
   - Use IAM roles with least privilege
   - Enable audit logging
   - Regular security reviews

## 📚 Additional Resources

- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)

## ➡️ Next Steps

After completing prerequisites:
1. **GKE Deployment**: Follow `01-gke-deployment.md`
2. **Cloud Run Assessment**: Review `02-cloud-run-analysis.md`
3. **Production Hardening**: See `03-production-setup.md`

---

**⚠️ Important**: Keep track of all resources created for billing purposes. Use resource labels and proper naming conventions for easier management.