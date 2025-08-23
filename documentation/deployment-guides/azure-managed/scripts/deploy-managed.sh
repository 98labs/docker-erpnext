#!/bin/bash

# ERPNext AKS Deployment Script with Azure Managed Services
# Usage: ./deploy-managed.sh [deploy|update|delete|status]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="${SCRIPT_DIR}/../kubernetes-manifests"
ENV_FILE="${HOME}/erpnext-azure-env.sh"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_color "$YELLOW" "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_color "$RED" "Azure CLI not found. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_color "$RED" "kubectl not found. Please install it first."
        exit 1
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        print_color "$RED" "Helm not found. Please install it first."
        exit 1
    fi
    
    # Check environment file
    if [ ! -f "$ENV_FILE" ]; then
        print_color "$RED" "Environment file not found at $ENV_FILE"
        print_color "$YELLOW" "Please complete the prerequisites first (00-prerequisites-managed.md)"
        exit 1
    fi
    
    # Source environment variables
    source "$ENV_FILE"
    
    # Check required environment variables
    local required_vars=(
        "RESOURCE_GROUP"
        "LOCATION"
        "DB_SERVER_NAME"
        "REDIS_NAME"
        "STORAGE_ACCOUNT"
        "KEYVAULT_NAME"
        "CLIENT_ID"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_color "$RED" "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    print_color "$GREEN" "Prerequisites check passed!"
}

# Function to create AKS cluster
create_aks_cluster() {
    print_color "$YELLOW" "Creating AKS cluster..."
    
    az aks create \
        --name erpnext-aks \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --node-count 3 \
        --node-vm-size Standard_D4s_v3 \
        --enable-managed-identity \
        --assign-identity "$IDENTITY_ID" \
        --network-plugin azure \
        --vnet-subnet-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/erpnext-vnet/subnets/aks-subnet" \
        --docker-bridge-address 172.17.0.1/16 \
        --dns-service-ip 10.0.10.10 \
        --service-cidr 10.0.10.0/24 \
        --enable-cluster-autoscaler \
        --min-count 3 \
        --max-count 10 \
        --enable-addons monitoring,azure-keyvault-secrets-provider \
        --workspace-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/erpnext-logs" \
        --generate-ssh-keys \
        --yes
    
    print_color "$GREEN" "AKS cluster created successfully!"
}

# Function to get AKS credentials
get_aks_credentials() {
    print_color "$YELLOW" "Getting AKS credentials..."
    
    az aks get-credentials \
        --name erpnext-aks \
        --resource-group "$RESOURCE_GROUP" \
        --overwrite-existing
    
    # Verify connection
    kubectl get nodes
    
    print_color "$GREEN" "Connected to AKS cluster!"
}

# Function to install NGINX Ingress
install_nginx_ingress() {
    print_color "$YELLOW" "Installing NGINX Ingress Controller..."
    
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
        --set controller.service.externalTrafficPolicy=Local \
        --wait
    
    # Wait for external IP
    print_color "$YELLOW" "Waiting for LoadBalancer IP..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    INGRESS_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    print_color "$GREEN" "NGINX Ingress installed! External IP: $INGRESS_IP"
}

# Function to install cert-manager
install_cert_manager() {
    print_color "$YELLOW" "Installing cert-manager..."
    
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.12.0 \
        --set installCRDs=true \
        --wait
    
    # Create ClusterIssuer
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL:-admin@example.com}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    print_color "$GREEN" "cert-manager installed successfully!"
}

# Function to prepare manifests
prepare_manifests() {
    print_color "$YELLOW" "Preparing Kubernetes manifests..."
    
    # Export additional variables
    export TENANT_ID=$(az account show --query tenantId -o tsv)
    export ACR_AUTH=$(echo -n "${ACR_USERNAME}:${ACR_PASSWORD}" | base64)
    export DOMAIN=${DOMAIN:-erpnext.example.com}
    
    # Create temporary directory for processed manifests
    TEMP_DIR=$(mktemp -d)
    
    # Process each manifest file
    for manifest in "$MANIFEST_DIR"/*.yaml; do
        filename=$(basename "$manifest")
        envsubst < "$manifest" > "$TEMP_DIR/$filename"
    done
    
    echo "$TEMP_DIR"
}

# Function to deploy ERPNext
deploy_erpnext() {
    print_color "$YELLOW" "Deploying ERPNext to AKS..."
    
    # Prepare manifests
    TEMP_DIR=$(prepare_manifests)
    
    # Apply manifests in order
    kubectl apply -f "$TEMP_DIR/namespace.yaml"
    kubectl apply -f "$TEMP_DIR/storage.yaml"
    kubectl apply -f "$TEMP_DIR/configmap.yaml"
    kubectl apply -f "$TEMP_DIR/secrets.yaml"
    
    # Wait for PVCs to be bound
    print_color "$YELLOW" "Waiting for storage provisioning..."
    kubectl wait --for=condition=Bound pvc/erpnext-sites -n erpnext --timeout=120s
    kubectl wait --for=condition=Bound pvc/erpnext-assets -n erpnext --timeout=120s
    
    # Deploy applications
    kubectl apply -f "$TEMP_DIR/erpnext-backend.yaml"
    kubectl apply -f "$TEMP_DIR/erpnext-frontend.yaml"
    kubectl apply -f "$TEMP_DIR/erpnext-workers.yaml"
    
    # Wait for deployments
    print_color "$YELLOW" "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/erpnext-backend -n erpnext
    kubectl wait --for=condition=available --timeout=300s deployment/erpnext-frontend -n erpnext
    
    # Apply ingress
    kubectl apply -f "$TEMP_DIR/ingress.yaml"
    
    # Run site initialization
    kubectl apply -f "$TEMP_DIR/jobs.yaml"
    
    # Wait for site initialization
    print_color "$YELLOW" "Waiting for site initialization..."
    kubectl wait --for=condition=complete --timeout=600s job/erpnext-site-init -n erpnext
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    
    print_color "$GREEN" "ERPNext deployed successfully!"
}

# Function to update deployment
update_deployment() {
    print_color "$YELLOW" "Updating ERPNext deployment..."
    
    # Prepare manifests
    TEMP_DIR=$(prepare_manifests)
    
    # Apply updates
    kubectl apply -f "$TEMP_DIR/configmap.yaml"
    kubectl apply -f "$TEMP_DIR/erpnext-backend.yaml"
    kubectl apply -f "$TEMP_DIR/erpnext-frontend.yaml"
    kubectl apply -f "$TEMP_DIR/erpnext-workers.yaml"
    
    # Restart deployments to pick up changes
    kubectl rollout restart deployment -n erpnext
    
    # Wait for rollout
    kubectl rollout status deployment/erpnext-backend -n erpnext
    kubectl rollout status deployment/erpnext-frontend -n erpnext
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    
    print_color "$GREEN" "Deployment updated successfully!"
}

# Function to delete deployment
delete_deployment() {
    print_color "$YELLOW" "Deleting ERPNext deployment..."
    
    read -p "Are you sure you want to delete the deployment? This will delete all data! (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_color "$YELLOW" "Deletion cancelled."
        exit 0
    fi
    
    # Delete namespace (this will delete all resources in it)
    kubectl delete namespace erpnext --ignore-not-found
    
    # Delete cert-manager resources
    kubectl delete clusterissuer letsencrypt-prod --ignore-not-found
    
    print_color "$GREEN" "Deployment deleted!"
}

# Function to show deployment status
show_status() {
    print_color "$YELLOW" "ERPNext Deployment Status:"
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace erpnext &> /dev/null; then
        print_color "$RED" "ERPNext namespace not found. Deployment may not exist."
        exit 1
    fi
    
    # Show deployments
    print_color "$GREEN" "Deployments:"
    kubectl get deployments -n erpnext
    echo ""
    
    # Show pods
    print_color "$GREEN" "Pods:"
    kubectl get pods -n erpnext
    echo ""
    
    # Show services
    print_color "$GREEN" "Services:"
    kubectl get services -n erpnext
    echo ""
    
    # Show ingress
    print_color "$GREEN" "Ingress:"
    kubectl get ingress -n erpnext
    echo ""
    
    # Show PVCs
    print_color "$GREEN" "Storage:"
    kubectl get pvc -n erpnext
    echo ""
    
    # Show HPA
    print_color "$GREEN" "Autoscaling:"
    kubectl get hpa -n erpnext
    echo ""
    
    # Get application URL
    if kubectl get ingress erpnext-ingress -n erpnext &> /dev/null; then
        INGRESS_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        print_color "$GREEN" "Application URL: http://$INGRESS_IP"
        print_color "$YELLOW" "Configure your DNS to point ${DOMAIN:-erpnext.example.com} to $INGRESS_IP"
    fi
}

# Function to run diagnostics
run_diagnostics() {
    print_color "$YELLOW" "Running diagnostics..."
    
    # Check database connectivity
    print_color "$YELLOW" "Testing database connectivity..."
    kubectl run pg-test --rm -i --image=postgres:13 -n erpnext --restart=Never -- \
        psql -h "$DB_SERVER_NAME.postgres.database.azure.com" -U "$DB_ADMIN_USER" -d erpnext -c "SELECT 1" || true
    
    # Check Redis connectivity
    print_color "$YELLOW" "Testing Redis connectivity..."
    kubectl run redis-test --rm -i --image=redis:alpine -n erpnext --restart=Never -- \
        redis-cli -h "$REDIS_HOST" -a "$REDIS_KEY" ping || true
    
    # Check pod logs
    print_color "$YELLOW" "Recent pod events:"
    kubectl get events -n erpnext --sort-by='.lastTimestamp' | tail -20
    
    print_color "$GREEN" "Diagnostics complete!"
}

# Main script
main() {
    case "${1:-}" in
        deploy)
            check_prerequisites
            create_aks_cluster
            get_aks_credentials
            install_nginx_ingress
            install_cert_manager
            deploy_erpnext
            show_status
            ;;
        update)
            check_prerequisites
            get_aks_credentials
            update_deployment
            show_status
            ;;
        delete)
            check_prerequisites
            get_aks_credentials
            delete_deployment
            ;;
        status)
            check_prerequisites
            get_aks_credentials
            show_status
            ;;
        diagnose)
            check_prerequisites
            get_aks_credentials
            run_diagnostics
            ;;
        *)
            echo "Usage: $0 [deploy|update|delete|status|diagnose]"
            echo ""
            echo "Commands:"
            echo "  deploy   - Create AKS cluster and deploy ERPNext"
            echo "  update   - Update existing deployment"
            echo "  delete   - Delete deployment and all resources"
            echo "  status   - Show deployment status"
            echo "  diagnose - Run diagnostic checks"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"