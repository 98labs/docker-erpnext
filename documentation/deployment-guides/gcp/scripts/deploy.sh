#!/bin/bash

# ERPNext GKE Deployment Script
# This script automates the deployment of ERPNext on Google Kubernetes Engine

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"erpnext-cluster"}
ZONE=${ZONE:-"us-central1-a"}
PROJECT_ID=${PROJECT_ID:-""}
DOMAIN=${DOMAIN:-"erpnext.yourdomain.com"}
EMAIL=${EMAIL:-"admin@yourdomain.com"}
NAMESPACE=${NAMESPACE:-"erpnext"}

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
    print_status "Checking prerequisites..."
    
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

# Function to create GKE cluster
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
        --max-nodes=10 \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-network-policy \
        --enable-ip-alias \
        --enable-cloud-logging \
        --enable-cloud-monitoring \
        --workload-pool="$PROJECT_ID.svc.id.goog" \
        --enable-shielded-nodes
    
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

# Function to install nginx ingress controller
install_nginx_ingress() {
    print_status "Installing NGINX Ingress Controller..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    print_success "NGINX Ingress Controller installed"
}

# Function to install cert-manager
install_cert_manager() {
    print_status "Installing cert-manager..."
    
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    
    print_success "cert-manager installed"
}

# Function to create namespace and basic resources
create_namespace() {
    print_status "Creating namespace and basic resources..."
    
    kubectl apply -f ../kubernetes-manifests/namespace.yaml
    
    print_success "Namespace created"
}

# Function to create secrets
create_secrets() {
    print_status "Creating secrets..."
    
    # Generate random passwords if not provided
    local admin_password=${ADMIN_PASSWORD:-$(openssl rand -base64 32)}
    local db_password=${DB_PASSWORD:-$(openssl rand -base64 32)}
    local api_key=${API_KEY:-$(openssl rand -hex 32)}
    local api_secret=${API_SECRET:-$(openssl rand -hex 32)}
    
    # Create secrets
    kubectl create secret generic erpnext-secrets \
        --namespace="$NAMESPACE" \
        --from-literal=admin-password="$admin_password" \
        --from-literal=db-password="$db_password" \
        --from-literal=api-key="$api_key" \
        --from-literal=api-secret="$api_secret" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Secrets created"
    print_warning "Admin password: $admin_password"
    print_warning "Please save these credentials securely!"
}

# Function to update configmap with domain
update_configmap() {
    print_status "Updating ConfigMap with domain configuration..."
    
    # Copy configmap template and update domain
    cp ../kubernetes-manifests/configmap.yaml /tmp/configmap-updated.yaml
    sed -i "s/erpnext.yourdomain.com/$DOMAIN/g" /tmp/configmap-updated.yaml
    
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

# Function to deploy database and redis
deploy_infrastructure() {
    print_status "Deploying infrastructure components..."
    
    kubectl apply -f ../kubernetes-manifests/redis.yaml
    kubectl apply -f ../kubernetes-manifests/mariadb.yaml
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    kubectl wait --for=condition=available deployment/mariadb -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=available deployment/redis -n "$NAMESPACE" --timeout=300s
    
    print_success "Infrastructure components deployed"
}

# Function to deploy ERPNext application
deploy_application() {
    print_status "Deploying ERPNext application..."
    
    kubectl apply -f ../kubernetes-manifests/erpnext-backend.yaml
    kubectl apply -f ../kubernetes-manifests/erpnext-frontend.yaml
    kubectl apply -f ../kubernetes-manifests/erpnext-workers.yaml
    
    # Wait for backend to be ready
    print_status "Waiting for ERPNext backend to be ready..."
    kubectl wait --for=condition=available deployment/erpnext-backend -n "$NAMESPACE" --timeout=600s
    
    print_success "ERPNext application deployed"
}

# Function to create ERPNext site
create_site() {
    print_status "Creating ERPNext site..."
    
    # Apply site creation job
    kubectl apply -f ../kubernetes-manifests/jobs.yaml
    
    # Wait for job to complete
    print_status "Waiting for site creation to complete..."
    kubectl wait --for=condition=complete job/erpnext-create-site -n "$NAMESPACE" --timeout=600s
    
    if kubectl get job erpnext-create-site -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        print_success "ERPNext site created successfully"
    else
        print_error "Site creation failed. Check job logs:"
        kubectl logs job/erpnext-create-site -n "$NAMESPACE"
        exit 1
    fi
}

# Function to deploy ingress
deploy_ingress() {
    print_status "Deploying ingress..."
    
    # Update ingress with correct domain and email
    cp ../kubernetes-manifests/ingress.yaml /tmp/ingress-updated.yaml
    sed -i "s/erpnext.yourdomain.com/$DOMAIN/g" /tmp/ingress-updated.yaml
    sed -i "s/admin@yourdomain.com/$EMAIL/g" /tmp/ingress-updated.yaml
    
    kubectl apply -f /tmp/ingress-updated.yaml
    rm /tmp/ingress-updated.yaml
    
    print_success "Ingress deployed"
}

# Function to get deployment status
get_status() {
    print_status "Getting deployment status..."
    
    echo ""
    echo "=== Cluster Information ==="
    kubectl cluster-info
    
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
}

# Function to cleanup deployment
cleanup() {
    print_warning "This will delete the entire ERPNext deployment. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Cleaning up deployment..."
        
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        
        print_status "Deleting cluster..."
        gcloud container clusters delete "$CLUSTER_NAME" --zone="$ZONE" --quiet
        
        print_success "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    echo "ERPNext GKE Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Full deployment (default)"
    echo "  status     - Show deployment status"
    echo "  cleanup    - Delete deployment"
    echo "  help       - Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_ID    - GCP Project ID"
    echo "  CLUSTER_NAME  - GKE cluster name (default: erpnext-cluster)"
    echo "  ZONE          - GCP zone (default: us-central1-a)"
    echo "  DOMAIN        - Domain name (default: erpnext.yourdomain.com)"
    echo "  EMAIL         - Email for Let's Encrypt (default: admin@yourdomain.com)"
    echo "  NAMESPACE     - Kubernetes namespace (default: erpnext)"
    echo ""
    echo "Example:"
    echo "  PROJECT_ID=my-project DOMAIN=erp.mycompany.com $0 deploy"
}

# Main deployment function
main_deploy() {
    print_status "Starting ERPNext GKE deployment..."
    
    check_prerequisites
    create_cluster
    configure_kubectl
    install_nginx_ingress
    install_cert_manager
    create_namespace
    create_secrets
    update_configmap
    deploy_storage
    deploy_infrastructure
    deploy_application
    create_site
    deploy_ingress
    
    print_success "Deployment completed successfully!"
    echo ""
    print_status "Access your ERPNext instance at: https://$DOMAIN"
    print_status "Default credentials: Administrator / [check secrets]"
    echo ""
    print_warning "It may take a few minutes for the SSL certificate to be issued."
    print_warning "Monitor certificate status with: kubectl get certificate -n $NAMESPACE"
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