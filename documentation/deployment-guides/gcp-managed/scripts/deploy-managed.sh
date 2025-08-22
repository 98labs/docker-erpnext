#!/bin/bash

# ERPNext GKE Deployment Script with Managed Services
# This script automates the deployment of ERPNext on GKE using Cloud SQL and Memorystore

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"erpnext-managed-cluster"}
ZONE=${ZONE:-"us-central1-a"}
REGION=${REGION:-"us-central1"}
PROJECT_ID=${PROJECT_ID:-""}
DOMAIN=${DOMAIN:-"erpnext.yourdomain.com"}
EMAIL=${EMAIL:-"admin@yourdomain.com"}
NAMESPACE=${NAMESPACE:-"erpnext"}

# Managed services configuration
DB_INSTANCE_NAME=${DB_INSTANCE_NAME:-"erpnext-db"}
REDIS_INSTANCE_NAME=${REDIS_INSTANCE_NAME:-"erpnext-redis"}
VPC_NAME=${VPC_NAME:-"erpnext-vpc"}
VPC_CONNECTOR=${VPC_CONNECTOR:-"erpnext-connector"}

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
    print_status "Checking prerequisites for managed services deployment..."
    
    # Check if required tools are installed
    local required_tools=("gcloud" "kubectl" "helm")
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
    
    # Check VPC network
    if ! gcloud compute networks describe "$VPC_NAME" &> /dev/null; then
        print_error "VPC network '$VPC_NAME' not found. Please create it first."
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
    
    # Get VPC connector
    if ! gcloud compute networks vpc-access connectors describe "$VPC_CONNECTOR" --region="$REGION" &> /dev/null; then
        print_warning "VPC connector '$VPC_CONNECTOR' not found. This is needed for Cloud Run deployment."
    fi
    
    print_success "Managed services information gathered"
}

# Function to create GKE cluster for managed services
create_cluster() {
    print_status "Creating GKE cluster: $CLUSTER_NAME"
    
    # Check if cluster already exists
    if gcloud container clusters describe "$CLUSTER_NAME" --zone="$ZONE" &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME already exists"
        return 0
    fi
    
    gcloud container clusters create "$CLUSTER_NAME" \
        --zone="$ZONE" \
        --num-nodes=3 \
        --node-locations="$ZONE" \
        --machine-type=e2-standard-4 \
        --disk-type=pd-ssd \
        --disk-size=50GB \
        --enable-autoscaling \
        --min-nodes=2 \
        --max-nodes=15 \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-network-policy \
        --enable-ip-alias \
        --network="$VPC_NAME" \
        --subnetwork=erpnext-subnet \
        --enable-private-nodes \
        --master-ipv4-cidr-block=172.16.0.0/28 \
        --enable-cloud-logging \
        --enable-cloud-monitoring \
        --workload-pool="$PROJECT_ID.svc.id.goog" \
        --enable-shielded-nodes \
        --enable-image-streaming \
        --logging=SYSTEM,WORKLOAD,API_SERVER \
        --monitoring=SYSTEM,WORKLOAD,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,CADVISOR,KUBELET
    
    print_success "Cluster created successfully"
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE"
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_success "kubectl configured successfully"
    else
        print_error "Failed to configure kubectl"
        exit 1
    fi
}

# Function to install required operators and controllers
install_operators() {
    print_status "Installing required operators and controllers..."
    
    # Install External Secrets Operator
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    helm install external-secrets external-secrets/external-secrets \
        -n external-secrets-system \
        --create-namespace \
        --wait
    
    # Install nginx ingress controller
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    
    print_success "Operators and controllers installed"
}

# Function to create namespace and basic resources
create_namespace() {
    print_status "Creating namespace and basic resources..."
    
    # Update namespace.yaml with correct labels
    cp ../kubernetes-manifests/namespace.yaml /tmp/namespace-updated.yaml
    
    kubectl apply -f /tmp/namespace-updated.yaml
    rm /tmp/namespace-updated.yaml
    
    print_success "Namespace created"
}

# Function to create service account and workload identity
setup_workload_identity() {
    print_status "Setting up Workload Identity..."
    
    # Create Kubernetes service account
    kubectl create serviceaccount erpnext-ksa --namespace="$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Google Cloud service account if it doesn't exist
    if ! gcloud iam service-accounts describe "erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" &> /dev/null; then
        gcloud iam service-accounts create erpnext-managed \
            --display-name="ERPNext Managed Services Account"
    fi
    
    # Grant necessary permissions
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/cloudsql.client"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/redis.editor"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/secretmanager.secretAccessor"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/storage.admin"
    
    # Bind service accounts
    gcloud iam service-accounts add-iam-policy-binding \
        --role roles/iam.workloadIdentityUser \
        --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/erpnext-ksa]" \
        "erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com"
    
    # Annotate Kubernetes service account
    kubectl annotate serviceaccount erpnext-ksa \
        --namespace="$NAMESPACE" \
        "iam.gke.io/gcp-service-account=erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com" \
        --overwrite
    
    print_success "Workload Identity configured"
}

# Function to create secrets using External Secrets Operator
create_secrets() {
    print_status "Creating secrets with External Secrets Operator..."
    
    # Generate random passwords if secrets don't exist in Secret Manager
    if ! gcloud secrets describe erpnext-admin-password &> /dev/null; then
        local admin_password=${ADMIN_PASSWORD:-$(openssl rand -base64 32)}
        gcloud secrets create erpnext-admin-password --data-file=<(echo -n "$admin_password")
        print_warning "Admin password: $admin_password"
    fi
    
    if ! gcloud secrets describe erpnext-db-password &> /dev/null; then
        local db_password=${DB_PASSWORD:-$(openssl rand -base64 32)}
        gcloud secrets create erpnext-db-password --data-file=<(echo -n "$db_password")
        print_warning "Database password: $db_password"
    fi
    
    if ! gcloud secrets describe erpnext-api-key &> /dev/null; then
        local api_key=${API_KEY:-$(openssl rand -hex 32)}
        gcloud secrets create erpnext-api-key --data-file=<(echo -n "$api_key")
    fi
    
    if ! gcloud secrets describe erpnext-api-secret &> /dev/null; then
        local api_secret=${API_SECRET:-$(openssl rand -hex 32)}
        gcloud secrets create erpnext-api-secret --data-file=<(echo -n "$api_secret")
    fi
    
    # Create connection name secret
    gcloud secrets create erpnext-db-connection-name --data-file=<(echo -n "$DB_CONNECTION_NAME") --quiet || \
    gcloud secrets versions add erpnext-db-connection-name --data-file=<(echo -n "$DB_CONNECTION_NAME")
    
    # Get Redis AUTH string if enabled
    local redis_auth=""
    if gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="value(authEnabled)" | grep -q "True"; then
        redis_auth=$(gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="value(authString)")
        gcloud secrets create redis-auth-string --data-file=<(echo -n "$redis_auth") --quiet || \
        gcloud secrets versions add redis-auth-string --data-file=<(echo -n "$redis_auth")
    fi
    
    # Apply External Secrets configuration
    cp ../kubernetes-manifests/secrets.yaml /tmp/secrets-updated.yaml
    sed -i "s/PROJECT_ID/$PROJECT_ID/g" /tmp/secrets-updated.yaml
    sed -i "s/REGION/$REGION/g" /tmp/secrets-updated.yaml
    sed -i "s/erpnext-managed-cluster/$CLUSTER_NAME/g" /tmp/secrets-updated.yaml
    
    kubectl apply -f /tmp/secrets-updated.yaml
    rm /tmp/secrets-updated.yaml
    
    # Wait for External Secrets to sync
    print_status "Waiting for secrets to be synced..."
    sleep 30
    
    # Create service account key for Cloud SQL Proxy
    if ! kubectl get secret gcp-service-account-key -n "$NAMESPACE" &> /dev/null; then
        local key_file="/tmp/erpnext-managed-key.json"
        gcloud iam service-accounts keys create "$key_file" \
            --iam-account="erpnext-managed@$PROJECT_ID.iam.gserviceaccount.com"
        
        kubectl create secret generic gcp-service-account-key \
            --namespace="$NAMESPACE" \
            --from-file=key.json="$key_file"
        
        rm "$key_file"
    fi
    
    print_success "Secrets created"
    print_warning "Please save the generated credentials securely!"
}

# Function to update ConfigMap with managed services configuration
update_configmap() {
    print_status "Updating ConfigMap with managed services configuration..."
    
    # Copy and update configmap
    cp ../kubernetes-manifests/configmap.yaml /tmp/configmap-updated.yaml
    sed -i "s/erpnext.yourdomain.com/$DOMAIN/g" /tmp/configmap-updated.yaml
    sed -i "s/PROJECT_ID/$PROJECT_ID/g" /tmp/configmap-updated.yaml
    sed -i "s/REGION/$REGION/g" /tmp/configmap-updated.yaml
    sed -i "s/REDIS_HOST/$REDIS_HOST/g" /tmp/configmap-updated.yaml
    
    kubectl apply -f /tmp/configmap-updated.yaml
    rm /tmp/configmap-updated.yaml
    
    print_success "ConfigMap updated"
}

# Function to deploy storage
deploy_storage() {
    print_status "Deploying storage resources..."
    
    kubectl apply -f ../kubernetes-manifests/storage.yaml
    
    print_success "Storage resources deployed"
}

# Function to deploy ERPNext application with managed services
deploy_application() {
    print_status "Deploying ERPNext application with managed services..."
    
    # Update manifests with managed services configuration
    local manifests=("erpnext-backend.yaml" "erpnext-frontend.yaml" "erpnext-workers.yaml")
    
    for manifest in "${manifests[@]}"; do
        cp "../kubernetes-manifests/$manifest" "/tmp/${manifest%.yaml}-updated.yaml"
        sed -i "s/PROJECT_ID/$PROJECT_ID/g" "/tmp/${manifest%.yaml}-updated.yaml"
        sed -i "s/REDIS_HOST/$REDIS_HOST/g" "/tmp/${manifest%.yaml}-updated.yaml"
        
        kubectl apply -f "/tmp/${manifest%.yaml}-updated.yaml"
        rm "/tmp/${manifest%.yaml}-updated.yaml"
    done
    
    # Wait for backend to be ready
    print_status "Waiting for ERPNext backend to be ready..."
    kubectl wait --for=condition=available deployment/erpnext-backend -n "$NAMESPACE" --timeout=600s
    
    print_success "ERPNext application deployed"
}

# Function to create ERPNext site
create_site() {
    print_status "Creating ERPNext site with managed services..."
    
    # Update jobs manifest
    cp ../kubernetes-manifests/jobs.yaml /tmp/jobs-updated.yaml
    sed -i "s/PROJECT_ID_PLACEHOLDER/$PROJECT_ID/g" /tmp/jobs-updated.yaml
    sed -i "s/REDIS_HOST_PLACEHOLDER/$REDIS_HOST/g" /tmp/jobs-updated.yaml
    
    # Apply site creation job
    kubectl apply -f /tmp/jobs-updated.yaml
    rm /tmp/jobs-updated.yaml
    
    # Wait for job to complete
    print_status "Waiting for site creation to complete..."
    kubectl wait --for=condition=complete job/erpnext-create-site -n "$NAMESPACE" --timeout=1200s
    
    if kubectl get job erpnext-create-site -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        print_success "ERPNext site created successfully with managed services"
    else
        print_error "Site creation failed. Check job logs:"
        kubectl logs job/erpnext-create-site -n "$NAMESPACE"
        exit 1
    fi
}

# Function to deploy ingress with managed services optimization
deploy_ingress() {
    print_status "Deploying ingress with managed services optimization..."
    
    # Update ingress with correct domains and managed services configuration
    cp ../kubernetes-manifests/ingress.yaml /tmp/ingress-updated.yaml
    sed -i "s/erpnext.yourdomain.com/$DOMAIN/g" /tmp/ingress-updated.yaml
    sed -i "s/api.yourdomain.com/api.$DOMAIN/g" /tmp/ingress-updated.yaml
    sed -i "s/admin@yourdomain.com/$EMAIL/g" /tmp/ingress-updated.yaml
    sed -i "s/PROJECT_ID/$PROJECT_ID/g" /tmp/ingress-updated.yaml
    
    kubectl apply -f /tmp/ingress-updated.yaml
    rm /tmp/ingress-updated.yaml
    
    print_success "Ingress deployed with managed services optimization"
}

# Function to setup monitoring for managed services
setup_monitoring() {
    print_status "Setting up monitoring for managed services..."
    
    # Install Prometheus stack with managed services configuration
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Create values file for managed services monitoring
    cat > /tmp/prometheus-values.yaml <<EOF
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Gi
    retention: 30d
    additionalScrapeConfigs:
    - job_name: 'cloud-sql-exporter'
      static_configs:
      - targets: ['cloud-sql-exporter:9308']
    - job_name: 'redis-exporter'
      static_configs:
      - targets: ['redis-exporter:9121']

grafana:
  adminPassword: SecurePassword123!
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'erpnext-managed'
        orgId: 1
        folder: 'ERPNext Managed Services'
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/erpnext-managed
  dashboards:
    erpnext-managed:
      cloud-sql-dashboard:
        gnetId: 14114
        revision: 1
        datasource: Prometheus
      redis-dashboard:
        gnetId: 763
        revision: 4
        datasource: Prometheus

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi
EOF
    
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values /tmp/prometheus-values.yaml \
        --wait
    
    rm /tmp/prometheus-values.yaml
    
    print_success "Monitoring setup completed for managed services"
}

# Function to create backup bucket and setup backup jobs
setup_backup() {
    print_status "Setting up backup for managed services..."
    
    # Create backup bucket
    gsutil mb gs://erpnext-backups-$PROJECT_ID || true
    
    # Set lifecycle policy
    gsutil lifecycle set - gs://erpnext-backups-$PROJECT_ID <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 60}
      }
    ]
  }
}
EOF
    
    # Backup jobs are already included in jobs.yaml and will be deployed
    print_success "Backup setup completed (Cloud SQL automated backups + file backups)"
}

# Function to get deployment status
get_status() {
    print_status "Getting deployment status..."
    
    echo ""
    echo "=== Cluster Information ==="
    kubectl cluster-info
    
    echo ""
    echo "=== Managed Services Status ==="
    echo "Cloud SQL Instance:"
    gcloud sql instances describe "$DB_INSTANCE_NAME" --format="table(name,state,region,databaseVersion)"
    
    echo ""
    echo "Redis Instance:"
    gcloud redis instances describe "$REDIS_INSTANCE_NAME" --region="$REGION" --format="table(name,state,host,port)"
    
    echo ""
    echo "=== Namespace Resources ==="
    kubectl get all -n "$NAMESPACE"
    
    echo ""
    echo "=== Ingress Information ==="
    kubectl get ingress -n "$NAMESPACE"
    
    echo ""
    echo "=== Certificate Status ==="
    kubectl get certificate -n "$NAMESPACE" 2>/dev/null || echo "No certificates found"
    
    echo ""
    echo "=== External IP ==="
    kubectl get service -n ingress-nginx ingress-nginx-controller
    
    echo ""
    echo "=== Secrets Status ==="
    kubectl get externalsecret -n "$NAMESPACE" 2>/dev/null || echo "External Secrets not found"
}

# Function to cleanup deployment
cleanup() {
    print_warning "This will delete the entire ERPNext deployment but preserve managed services. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Cleaning up deployment..."
        
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        
        print_status "Deleting cluster..."
        gcloud container clusters delete "$CLUSTER_NAME" --zone="$ZONE" --quiet
        
        print_warning "Managed services (Cloud SQL, Redis) are preserved."
        print_warning "To delete them manually:"
        print_warning "  gcloud sql instances delete $DB_INSTANCE_NAME"
        print_warning "  gcloud redis instances delete $REDIS_INSTANCE_NAME --region=$REGION"
        
        print_success "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    echo "ERPNext GKE Deployment Script with Managed Services"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Full deployment with managed services (default)"
    echo "  status     - Show deployment status"
    echo "  cleanup    - Delete deployment (preserves managed services)"
    echo "  help       - Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_ID           - GCP Project ID"
    echo "  CLUSTER_NAME         - GKE cluster name (default: erpnext-managed-cluster)"
    echo "  ZONE                 - GCP zone (default: us-central1-a)"
    echo "  REGION               - GCP region (default: us-central1)"
    echo "  DOMAIN               - Domain name (default: erpnext.yourdomain.com)"
    echo "  EMAIL                - Email for Let's Encrypt (default: admin@yourdomain.com)"
    echo "  NAMESPACE            - Kubernetes namespace (default: erpnext)"
    echo "  DB_INSTANCE_NAME     - Cloud SQL instance name (default: erpnext-db)"
    echo "  REDIS_INSTANCE_NAME  - Memorystore instance name (default: erpnext-redis)"
    echo "  VPC_NAME             - VPC network name (default: erpnext-vpc)"
    echo ""
    echo "Prerequisites:"
    echo "  - Complete setup in 00-prerequisites-managed.md"
    echo "  - Cloud SQL and Memorystore instances must exist"
    echo "  - VPC network with proper configuration"
    echo ""
    echo "Example:"
    echo "  PROJECT_ID=my-project DOMAIN=erp.mycompany.com $0 deploy"
}

# Main deployment function
main_deploy() {
    print_status "Starting ERPNext GKE deployment with managed services..."
    
    check_prerequisites
    check_managed_services
    get_managed_services_info
    create_cluster
    configure_kubectl
    install_operators
    create_namespace
    setup_workload_identity
    create_secrets
    update_configmap
    deploy_storage
    deploy_application
    create_site
    deploy_ingress
    setup_monitoring
    setup_backup
    
    print_success "Deployment completed successfully with managed services!"
    echo ""
    print_status "Access your ERPNext instance at: https://$DOMAIN"
    print_status "API endpoint: https://api.$DOMAIN"
    echo ""
    print_status "Managed Services:"
    print_status "  Cloud SQL: $DB_CONNECTION_NAME"
    print_status "  Redis: $REDIS_HOST:6379"
    echo ""
    print_warning "It may take a few minutes for the SSL certificate to be issued."
    print_warning "Monitor certificate status with: kubectl get certificate -n $NAMESPACE"
    echo ""
    print_status "Default credentials are stored in Secret Manager."
    print_status "Retrieve admin password with: gcloud secrets versions access latest --secret=erpnext-admin-password"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        main_deploy
        ;;
    "status")
        get_status
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