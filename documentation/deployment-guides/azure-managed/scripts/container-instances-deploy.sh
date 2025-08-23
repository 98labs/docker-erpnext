#!/bin/bash

# ERPNext Azure Container Instances Deployment Script
# Usage: ./container-instances-deploy.sh [deploy|update|delete|status|scale]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_color "$RED" "Docker not found. Please install it first."
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
        "DB_ADMIN_USER"
        "DB_ADMIN_PASSWORD"
        "REDIS_NAME"
        "REDIS_HOST"
        "REDIS_KEY"
        "STORAGE_ACCOUNT"
        "STORAGE_KEY"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_color "$RED" "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    print_color "$GREEN" "Prerequisites check passed!"
}

# Function to create container registry
create_container_registry() {
    print_color "$YELLOW" "Creating Azure Container Registry..."
    
    export ACR_NAME="erpnextacr$(openssl rand -hex 4)"
    
    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard \
        --admin-enabled true
    
    # Get registry credentials
    export ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
    export ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
    export ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)
    
    # Login to registry
    az acr login --name "$ACR_NAME"
    
    print_color "$GREEN" "Container Registry created: $ACR_LOGIN_SERVER"
}

# Function to build and push images
build_and_push_images() {
    print_color "$YELLOW" "Building and pushing Docker images..."
    
    # Create temporary build directory
    BUILD_DIR=$(mktemp -d)
    cd "$BUILD_DIR"
    
    # Create Dockerfile for ERPNext with Azure integrations
    cat > Dockerfile.azure <<'EOF'
FROM frappe/erpnext-worker:v14

# Install Azure Storage SDK for Python and PostgreSQL client
RUN pip install azure-storage-blob azure-identity psycopg2-binary

# Add custom entrypoint for Azure configurations
COPY entrypoint.azure.sh /entrypoint.azure.sh
RUN chmod +x /entrypoint.azure.sh

ENTRYPOINT ["/entrypoint.azure.sh"]
CMD ["start"]
EOF

    # Create entrypoint script
    cat > entrypoint.azure.sh <<'EOF'
#!/bin/bash
set -e

# Configure database connection for PostgreSQL
export DB_TYPE="postgres"
export DB_HOST="${DB_HOST}"
export DB_PORT="5432"
export DB_NAME="erpnext"

# Configure Redis with SSL
export REDIS_CACHE="rediss://:${REDIS_PASSWORD}@${REDIS_HOST}:6380/0?ssl_cert_reqs=required"
export REDIS_QUEUE="rediss://:${REDIS_PASSWORD}@${REDIS_HOST}:6380/1?ssl_cert_reqs=required"
export REDIS_SOCKETIO="rediss://:${REDIS_PASSWORD}@${REDIS_HOST}:6380/2?ssl_cert_reqs=required"

# Execute command
if [ "$1" = "start" ]; then
    exec bench start
else
    exec "$@"
fi
EOF

    # Build and push image
    docker build -f Dockerfile.azure -t "$ACR_LOGIN_SERVER/erpnext-azure:v14" .
    docker push "$ACR_LOGIN_SERVER/erpnext-azure:v14"
    
    # Clean up
    cd -
    rm -rf "$BUILD_DIR"
    
    print_color "$GREEN" "Images built and pushed successfully!"
}

# Function to create file shares
create_file_shares() {
    print_color "$YELLOW" "Creating Azure File Shares..."
    
    # Create file shares
    az storage share create \
        --name erpnext-sites \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --quota 100
    
    az storage share create \
        --name erpnext-assets \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --quota 50
    
    az storage share create \
        --name erpnext-logs \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --quota 10
    
    print_color "$GREEN" "File shares created successfully!"
}

# Function to deploy backend container group
deploy_backend() {
    print_color "$YELLOW" "Deploying backend container group..."
    
    # Create YAML deployment file
    cat > aci-backend.yaml <<EOF
apiVersion: 2021-10-01
location: $LOCATION
name: erpnext-backend
properties:
  containers:
  - name: backend
    properties:
      image: $ACR_LOGIN_SERVER/erpnext-azure:v14
      command: ["bench", "start"]
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
        secureValue: ${ADMIN_PASSWORD:-YourSecurePassword123!}
      volumeMounts:
      - name: sites
        mountPath: /home/frappe/frappe-bench/sites
      - name: logs
        mountPath: /home/frappe/frappe-bench/logs
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
  - name: logs
    azureFile:
      shareName: erpnext-logs
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

    # Deploy container group
    az container create \
        --resource-group "$RESOURCE_GROUP" \
        --file aci-backend.yaml
    
    print_color "$GREEN" "Backend container group deployed!"
}

# Function to deploy frontend container group
deploy_frontend() {
    print_color "$YELLOW" "Deploying frontend container group..."
    
    # Create YAML deployment file
    cat > aci-frontend.yaml <<EOF
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
        value: 10.0.2.4:8000
      - name: FRAPPE_SITE_NAME_HEADER
        value: frontend
      - name: SOCKETIO
        value: 10.0.2.4:9000
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
  - server: docker.io
    username: _
    password: _
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
    dnsNameLabel: erpnext-${RESOURCE_GROUP}
type: Microsoft.ContainerInstance/containerGroups
EOF

    # Deploy container group
    az container create \
        --resource-group "$RESOURCE_GROUP" \
        --file aci-frontend.yaml
    
    # Get public FQDN
    export FRONTEND_FQDN=$(az container show \
        --resource-group "$RESOURCE_GROUP" \
        --name erpnext-frontend \
        --query ipAddress.fqdn -o tsv)
    
    print_color "$GREEN" "Frontend deployed! URL: http://$FRONTEND_FQDN:8080"
}

# Function to initialize site
initialize_site() {
    print_color "$YELLOW" "Initializing ERPNext site..."
    
    # Run site initialization
    az container create \
        --resource-group "$RESOURCE_GROUP" \
        --name erpnext-init \
        --image "$ACR_LOGIN_SERVER/erpnext-azure:v14" \
        --cpu 2 \
        --memory 4 \
        --restart-policy Never \
        --environment-variables \
            DB_HOST="$DB_SERVER_NAME.postgres.database.azure.com" \
            DB_USER="$DB_ADMIN_USER" \
            REDIS_HOST="$REDIS_HOST" \
        --secure-environment-variables \
            DB_PASSWORD="$DB_ADMIN_PASSWORD" \
            REDIS_PASSWORD="$REDIS_KEY" \
            ADMIN_PASSWORD="${ADMIN_PASSWORD:-YourSecurePassword123!}" \
        --azure-file-volume-account-name "$STORAGE_ACCOUNT" \
        --azure-file-volume-account-key "$STORAGE_KEY" \
        --azure-file-volume-share-name erpnext-sites \
        --azure-file-volume-mount-path /home/frappe/frappe-bench/sites \
        --command-line "/bin/bash -c 'bench new-site frontend --db-type postgres --db-host \$DB_HOST --db-port 5432 --db-name erpnext --db-user \$DB_USER --db-password \$DB_PASSWORD --admin-password \$ADMIN_PASSWORD --install-app erpnext && bench --site frontend migrate'" \
        --subnet "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/erpnext-vnet/subnets/aci-subnet" \
        --registry-login-server "$ACR_LOGIN_SERVER" \
        --registry-username "$ACR_USERNAME" \
        --registry-password "$ACR_PASSWORD"
    
    # Wait for completion
    print_color "$YELLOW" "Waiting for site initialization to complete..."
    
    while true; do
        STATE=$(az container show \
            --resource-group "$RESOURCE_GROUP" \
            --name erpnext-init \
            --query containers[0].instanceView.currentState.state -o tsv)
        
        if [ "$STATE" = "Terminated" ]; then
            break
        fi
        
        sleep 10
    done
    
    # View logs
    az container logs \
        --resource-group "$RESOURCE_GROUP" \
        --name erpnext-init
    
    # Delete init container
    az container delete \
        --resource-group "$RESOURCE_GROUP" \
        --name erpnext-init \
        --yes
    
    print_color "$GREEN" "Site initialization completed!"
}

# Function to scale deployment
scale_deployment() {
    local replicas=${1:-3}
    print_color "$YELLOW" "Scaling deployment to $replicas instances..."
    
    # Deploy additional backend instances
    for i in $(seq 2 $replicas); do
        sed "s/erpnext-backend/erpnext-backend-$i/g" aci-backend.yaml > "aci-backend-$i.yaml"
        az container create \
            --resource-group "$RESOURCE_GROUP" \
            --file "aci-backend-$i.yaml"
    done
    
    print_color "$GREEN" "Scaled to $replicas instances!"
}

# Function to show status
show_status() {
    print_color "$YELLOW" "Container Instances Status:"
    echo ""
    
    # List all container groups
    az container list \
        --resource-group "$RESOURCE_GROUP" \
        --output table
    
    # Show detailed status for main containers
    for container in erpnext-backend erpnext-frontend; do
        if az container show --resource-group "$RESOURCE_GROUP" --name "$container" &> /dev/null; then
            print_color "$GREEN" "\n$container status:"
            az container show \
                --resource-group "$RESOURCE_GROUP" \
                --name "$container" \
                --query "{Name:name, State:containers[0].instanceView.currentState.state, CPU:containers[0].resources.requests.cpu, Memory:containers[0].resources.requests.memoryInGb, RestartCount:containers[0].instanceView.restartCount}" \
                --output table
        fi
    done
    
    # Show application URL
    if [ -n "${FRONTEND_FQDN:-}" ]; then
        print_color "$GREEN" "\nApplication URL: http://$FRONTEND_FQDN:8080"
    else
        FRONTEND_FQDN=$(az container show \
            --resource-group "$RESOURCE_GROUP" \
            --name erpnext-frontend \
            --query ipAddress.fqdn -o tsv 2>/dev/null || echo "")
        if [ -n "$FRONTEND_FQDN" ]; then
            print_color "$GREEN" "\nApplication URL: http://$FRONTEND_FQDN:8080"
        fi
    fi
}

# Function to delete deployment
delete_deployment() {
    print_color "$YELLOW" "Deleting Container Instances deployment..."
    
    read -p "Are you sure you want to delete the deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_color "$YELLOW" "Deletion cancelled."
        exit 0
    fi
    
    # Delete container groups
    for container in $(az container list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv); do
        print_color "$YELLOW" "Deleting $container..."
        az container delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$container" \
            --yes
    done
    
    print_color "$GREEN" "Deployment deleted!"
}

# Function to view logs
view_logs() {
    local container=${1:-erpnext-backend}
    local container_name=${2:-backend}
    
    print_color "$YELLOW" "Viewing logs for $container/$container_name..."
    
    az container logs \
        --resource-group "$RESOURCE_GROUP" \
        --name "$container" \
        --container-name "$container_name" \
        --follow
}

# Main script
main() {
    case "${1:-}" in
        deploy)
            check_prerequisites
            create_container_registry
            build_and_push_images
            create_file_shares
            deploy_backend
            deploy_frontend
            initialize_site
            show_status
            ;;
        update)
            check_prerequisites
            source "$ENV_FILE"
            build_and_push_images
            print_color "$YELLOW" "Restarting containers..."
            az container restart --resource-group "$RESOURCE_GROUP" --name erpnext-backend
            az container restart --resource-group "$RESOURCE_GROUP" --name erpnext-frontend
            show_status
            ;;
        scale)
            check_prerequisites
            source "$ENV_FILE"
            scale_deployment "${2:-3}"
            ;;
        delete)
            check_prerequisites
            delete_deployment
            ;;
        status)
            check_prerequisites
            show_status
            ;;
        logs)
            check_prerequisites
            view_logs "${2:-erpnext-backend}" "${3:-backend}"
            ;;
        *)
            echo "Usage: $0 [deploy|update|scale|delete|status|logs] [options]"
            echo ""
            echo "Commands:"
            echo "  deploy         - Deploy ERPNext on Container Instances"
            echo "  update         - Update existing deployment"
            echo "  scale <count>  - Scale backend instances (default: 3)"
            echo "  delete         - Delete deployment"
            echo "  status         - Show deployment status"
            echo "  logs [container] [name] - View container logs"
            echo ""
            echo "Examples:"
            echo "  $0 deploy"
            echo "  $0 scale 5"
            echo "  $0 logs erpnext-backend worker-default"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"