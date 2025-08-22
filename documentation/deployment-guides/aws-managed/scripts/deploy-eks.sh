#!/bin/bash

# ERPNext EKS Deployment Script for AWS Managed Services
# This script automates the deployment of ERPNext on Amazon EKS with RDS and MemoryDB

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_PROFILE=${AWS_PROFILE:-default}
CLUSTER_NAME=${CLUSTER_NAME:-erpnext-cluster}
PROJECT_NAME=${PROJECT_NAME:-erpnext}
DOMAIN_NAME=${DOMAIN_NAME:-erpnext.yourdomain.com}
ENVIRONMENT=${ENVIRONMENT:-production}

# EKS configuration
KUBERNETES_VERSION=${KUBERNETES_VERSION:-1.28}
NODE_INSTANCE_TYPE=${NODE_INSTANCE_TYPE:-t3.medium}
NODE_GROUP_MIN_SIZE=${NODE_GROUP_MIN_SIZE:-2}
NODE_GROUP_MAX_SIZE=${NODE_GROUP_MAX_SIZE:-10}
NODE_GROUP_DESIRED_SIZE=${NODE_GROUP_DESIRED_SIZE:-3}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("aws" "kubectl" "eksctl" "helm" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity --profile $AWS_PROFILE &> /dev/null; then
        print_error "AWS credentials not configured properly."
        exit 1
    fi
    
    # Get Account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
    print_status "AWS Account ID: $ACCOUNT_ID"
    print_status "AWS Region: $AWS_REGION"
    print_status "AWS Profile: $AWS_PROFILE"
}

# Function to check if VPC exists
check_vpc() {
    print_header "Checking VPC configuration..."
    
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
        --query "Vpcs[0].VpcId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "None")
    
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_error "VPC not found. Please run the prerequisites setup first."
        exit 1
    fi
    
    print_status "Found VPC: $VPC_ID"
    
    # Get subnet IDs
    PRIVATE_SUBNET_1A=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-private-subnet-1a" \
        --query "Subnets[0].SubnetId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    PRIVATE_SUBNET_1B=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-private-subnet-1b" \
        --query "Subnets[0].SubnetId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    PUBLIC_SUBNET_1A=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-subnet-1a" \
        --query "Subnets[0].SubnetId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    PUBLIC_SUBNET_1B=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-subnet-1b" \
        --query "Subnets[0].SubnetId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    print_status "Private Subnets: $PRIVATE_SUBNET_1A, $PRIVATE_SUBNET_1B"
    print_status "Public Subnets: $PUBLIC_SUBNET_1A, $PUBLIC_SUBNET_1B"
}

# Function to get security group IDs
get_security_groups() {
    print_header "Getting security group IDs..."
    
    APP_SG=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-app-sg" \
        --query "SecurityGroups[0].GroupId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    print_status "Application Security Group: $APP_SG"
}

# Function to get database endpoints
get_database_endpoints() {
    print_header "Getting database endpoints..."
    
    # Get RDS endpoint
    DB_HOST=$(aws rds describe-db-instances \
        --db-instance-identifier ${PROJECT_NAME}-db \
        --query "DBInstances[0].Endpoint.Address" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "")
    
    if [ -z "$DB_HOST" ]; then
        print_error "RDS instance not found. Please create it first."
        exit 1
    fi
    
    # Get Redis endpoint
    REDIS_HOST=$(aws memorydb describe-clusters \
        --cluster-name ${PROJECT_NAME}-redis \
        --query "Clusters[0].ClusterEndpoint.Address" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "")
    
    if [ -z "$REDIS_HOST" ]; then
        print_error "MemoryDB cluster not found. Please create it first."
        exit 1
    fi
    
    print_status "Database Host: $DB_HOST"
    print_status "Redis Host: $REDIS_HOST"
}

# Function to create EFS file system
create_efs() {
    print_header "Creating EFS file system..."
    
    # Check if EFS already exists
    EFS_ID=$(aws efs describe-file-systems \
        --query "FileSystems[?Tags[?Key=='Name' && Value=='${PROJECT_NAME}-sites-efs']].FileSystemId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "")
    
    if [ -z "$EFS_ID" ]; then
        print_status "Creating EFS file system..."
        EFS_ID=$(aws efs create-file-system \
            --creation-token ${PROJECT_NAME}-sites-$(date +%s) \
            --performance-mode generalPurpose \
            --throughput-mode provisioned \
            --provisioned-throughput-in-mibps 100 \
            --encrypted \
            --tags Key=Name,Value=${PROJECT_NAME}-sites-efs Key=Application,Value=ERPNext \
            --query "FileSystemId" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
        
        print_status "Created EFS: $EFS_ID"
        
        # Wait for EFS to be available
        print_status "Waiting for EFS to be available..."
        aws efs wait file-system-available --file-system-id $EFS_ID --region $AWS_REGION --profile $AWS_PROFILE
        
        # Create mount targets
        print_status "Creating EFS mount targets..."
        aws efs create-mount-target \
            --file-system-id $EFS_ID \
            --subnet-id $PRIVATE_SUBNET_1A \
            --security-groups $APP_SG \
            --region $AWS_REGION \
            --profile $AWS_PROFILE
        
        aws efs create-mount-target \
            --file-system-id $EFS_ID \
            --subnet-id $PRIVATE_SUBNET_1B \
            --security-groups $APP_SG \
            --region $AWS_REGION \
            --profile $AWS_PROFILE
    else
        print_status "Using existing EFS: $EFS_ID"
    fi
}

# Function to create EKS cluster configuration
create_cluster_config() {
    print_header "Creating EKS cluster configuration..."
    
    cat > /tmp/erpnext-eks-cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: $AWS_REGION
  version: "$KUBERNETES_VERSION"

availabilityZones: ["${AWS_REGION}a", "${AWS_REGION}b"]

vpc:
  id: $VPC_ID
  subnets:
    private:
      ${AWS_REGION}a:
        id: $PRIVATE_SUBNET_1A
      ${AWS_REGION}b:
        id: $PRIVATE_SUBNET_1B
    public:
      ${AWS_REGION}a:
        id: $PUBLIC_SUBNET_1A
      ${AWS_REGION}b:
        id: $PUBLIC_SUBNET_1B

nodeGroups:
  - name: ${PROJECT_NAME}-workers
    instanceType: $NODE_INSTANCE_TYPE
    desiredCapacity: $NODE_GROUP_DESIRED_SIZE
    minSize: $NODE_GROUP_MIN_SIZE
    maxSize: $NODE_GROUP_MAX_SIZE
    volumeSize: 50
    volumeType: gp3
    subnets:
      - $PRIVATE_SUBNET_1A
      - $PRIVATE_SUBNET_1B
    privateNetworking: true
    securityGroups:
      attachIDs: ["$APP_SG"]
    ssh:
      allow: false
    iam:
      withAddonPolicies:
        ebs: true
        fsx: true
        efs: true
        albIngress: true
        autoScaler: true
        cloudWatch: true
        externalDNS: true
    labels:
      node-type: worker
      application: erpnext
    tags:
      Name: ${PROJECT_NAME}-worker-node
      Application: ERPNext
      Environment: $ENVIRONMENT

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest

iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: aws-load-balancer-controller
        namespace: kube-system
      wellKnownPolicies:
        awsLoadBalancerController: true
    - metadata:
        name: efs-csi-controller-sa
        namespace: kube-system
      wellKnownPolicies:
        efsCSIController: true
    - metadata:
        name: external-secrets-operator
        namespace: external-secrets
      attachPolicyARNs:
        - "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
    - metadata:
        name: erpnext-sa
        namespace: erpnext
      attachPolicyARNs:
        - "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
        - "arn:aws:iam::aws:policy/AmazonS3FullAccess"
EOF

    print_status "EKS cluster configuration created"
}

# Function to create EKS cluster
create_eks_cluster() {
    print_header "Creating EKS cluster..."
    
    # Check if cluster already exists
    CLUSTER_STATUS=$(aws eks describe-cluster \
        --name $CLUSTER_NAME \
        --query "cluster.status" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "")
    
    if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
        print_status "EKS cluster already exists and is active"
    else
        print_status "Creating EKS cluster (this may take 15-20 minutes)..."
        eksctl create cluster -f /tmp/erpnext-eks-cluster.yaml --profile $AWS_PROFILE
        print_status "EKS cluster created successfully"
    fi
    
    # Update kubeconfig
    print_status "Updating kubeconfig..."
    aws eks update-kubeconfig \
        --region $AWS_REGION \
        --name $CLUSTER_NAME \
        --profile $AWS_PROFILE
    
    # Verify cluster access
    print_status "Verifying cluster access..."
    kubectl cluster-info
    kubectl get nodes
}

# Function to install required add-ons
install_addons() {
    print_header "Installing required add-ons..."
    
    # Install AWS Load Balancer Controller
    install_aws_load_balancer_controller
    
    # Install EFS CSI Driver
    install_efs_csi_driver
    
    # Install External Secrets Operator
    install_external_secrets_operator
    
    # Install metrics server
    install_metrics_server
}

# Function to install AWS Load Balancer Controller
install_aws_load_balancer_controller() {
    print_status "Installing AWS Load Balancer Controller..."
    
    # Download IAM policy
    curl -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
    
    # Create IAM policy (ignore if already exists)
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file:///tmp/iam_policy.json \
        --profile $AWS_PROFILE 2>/dev/null || true
    
    # Install using Helm
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --wait
    
    print_status "AWS Load Balancer Controller installed"
}

# Function to install EFS CSI Driver
install_efs_csi_driver() {
    print_status "Installing EFS CSI Driver..."
    
    helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
    helm repo update
    
    helm upgrade --install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
        --namespace kube-system \
        --set controller.serviceAccount.create=false \
        --set controller.serviceAccount.name=efs-csi-controller-sa \
        --wait
    
    print_status "EFS CSI Driver installed"
}

# Function to install External Secrets Operator
install_external_secrets_operator() {
    print_status "Installing External Secrets Operator..."
    
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    
    helm upgrade --install external-secrets external-secrets/external-secrets \
        --namespace external-secrets \
        --create-namespace \
        --set installCRDs=true \
        --wait
    
    print_status "External Secrets Operator installed"
}

# Function to install metrics server
install_metrics_server() {
    print_status "Installing Metrics Server..."
    
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Wait for metrics server to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    
    print_status "Metrics Server installed"
}

# Function to create Kubernetes manifests
create_kubernetes_manifests() {
    print_header "Creating Kubernetes manifests..."
    
    # Create manifest directory
    mkdir -p /tmp/k8s-manifests
    
    # Create namespace and storage manifests
    create_namespace_manifest
    create_storage_manifest
    create_configmap_manifest
    create_secrets_manifest
    create_backend_manifest
    create_frontend_manifest
    create_workers_manifest
    create_ingress_manifest
    create_jobs_manifest
}

# Function to create namespace manifest
create_namespace_manifest() {
    cat > /tmp/k8s-manifests/namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: erpnext
  labels:
    name: erpnext
    application: erpnext
    environment: $ENVIRONMENT
EOF
}

# Function to create storage manifest
create_storage_manifest() {
    cat > /tmp/k8s-manifests/storage.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: $EFS_ID
  directoryPerms: "700"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-sites-pvc
  namespace: erpnext
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-backups-pvc
  namespace: erpnext
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-gp3
  resources:
    requests:
      storage: 100Gi
EOF
}

# Function to create configmap manifest
create_configmap_manifest() {
    cat > /tmp/k8s-manifests/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-config
  namespace: erpnext
data:
  APP_VERSION: "v14"
  APP_URL: "$DOMAIN_NAME"
  APP_USER: "Administrator"
  APP_DB_PARAM: "db"
  DEVELOPER_MODE: "0"
  ENABLE_SCHEDULER: "1"
  SOCKETIO_PORT: "9000"
  DB_HOST: "$DB_HOST"
  DB_PORT: "3306"
  DB_NAME: "erpnext"
  DB_USER: "admin"
  DB_TIMEOUT: "60"
  DB_CHARSET: "utf8mb4"
  REDIS_CACHE_URL: "redis://$REDIS_HOST:6379/0"
  REDIS_QUEUE_URL: "redis://$REDIS_HOST:6379/1"
  REDIS_SOCKETIO_URL: "redis://$REDIS_HOST:6379/2"
  AWS_DEFAULT_REGION: "$AWS_REGION"
  AWS_S3_BUCKET: "${PROJECT_NAME}-files-$ACCOUNT_ID"
EOF
}

# Function to create secrets manifest
create_secrets_manifest() {
    cat > /tmp/k8s-manifests/secrets.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretstore
  namespace: erpnext
spec:
  provider:
    aws:
      service: SecretsManager
      region: $AWS_REGION
      auth:
        jwt:
          serviceAccountRef:
            name: erpnext-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-db-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-db-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: ${PROJECT_NAME}/database/password
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-redis-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-redis-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: ${PROJECT_NAME}/redis/password
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-admin-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-admin-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: ${PROJECT_NAME}/admin/password
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: erpnext-sa
  namespace: erpnext
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$ACCOUNT_ID:role/eksctl-$CLUSTER_NAME-addon-iamserviceaccount-erpnext-erpnext-sa-Role1-XXXXXX
automountServiceAccountToken: true
EOF
}

# Function to create backend manifest
create_backend_manifest() {
    cat > /tmp/k8s-manifests/backend.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend
  namespace: erpnext
spec:
  replicas: 3
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        ports:
        - containerPort: 8000
        - containerPort: 9000
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
              key: password
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        - name: backups-data
          mountPath: /home/frappe/frappe-bench/sites/backups
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /api/method/ping
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /api/method/ping
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      - name: backups-data
        persistentVolumeClaim:
          claimName: erpnext-backups-pvc
      nodeSelector:
        node-type: worker
---
apiVersion: v1
kind: Service
metadata:
  name: erpnext-backend
  namespace: erpnext
spec:
  selector:
    app: erpnext-backend
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  - name: socketio
    port: 9000
    targetPort: 9000
EOF
}

# Function to create frontend manifest
create_frontend_manifest() {
    cat > /tmp/k8s-manifests/frontend.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-frontend
  namespace: erpnext
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-frontend
  template:
    metadata:
      labels:
        app: erpnext-frontend
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 1000
      containers:
      - name: erpnext-frontend
        image: frappe/erpnext-nginx:v14
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
          readOnly: true
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      nodeSelector:
        node-type: worker
---
apiVersion: v1
kind: Service
metadata:
  name: erpnext-frontend
  namespace: erpnext
spec:
  selector:
    app: erpnext-frontend
  ports:
  - port: 8080
    targetPort: 8080
EOF
}

# Function to create workers manifest
create_workers_manifest() {
    cat > /tmp/k8s-manifests/workers.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-queue-default
  namespace: erpnext
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-queue-default
  template:
    metadata:
      labels:
        app: erpnext-queue-default
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: queue-worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "default"]
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
              key: password
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      nodeSelector:
        node-type: worker
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-scheduler
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: erpnext-scheduler
  template:
    metadata:
      labels:
        app: erpnext-scheduler
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: scheduler
        image: frappe/erpnext-worker:v14
        command: ["bench", "schedule"]
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
              key: password
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "250m"
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      nodeSelector:
        node-type: worker
EOF
}

# Function to create ingress manifest
create_ingress_manifest() {
    cat > /tmp/k8s-manifests/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: erpnext-ingress
  namespace: erpnext
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/healthcheck-grace-period-seconds: "60"
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/success-codes: "200,201,202"
    alb.ingress.kubernetes.io/tags: |
      Environment=$ENVIRONMENT,
      Application=ERPNext,
      Project=$PROJECT_NAME
spec:
  rules:
  - host: $DOMAIN_NAME
    http:
      paths:
      - path: /socket.io
        pathType: Prefix
        backend:
          service:
            name: erpnext-backend
            port:
              number: 9000
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: erpnext-backend
            port:
              number: 8000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: erpnext-frontend
            port:
              number: 8080
EOF
}

# Function to create jobs manifest
create_jobs_manifest() {
    cat > /tmp/k8s-manifests/jobs.yaml <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: erpnext-create-site
  namespace: erpnext
spec:
  backoffLimit: 3
  template:
    spec:
      serviceAccountName: erpnext-sa
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: create-site
        image: frappe/erpnext-worker:v14
        command:
        - bash
        - -c
        - |
          set -e
          echo "Starting ERPNext site creation..."
          if [ -d "/home/frappe/frappe-bench/sites/frontend" ]; then
            echo "Site 'frontend' already exists. Skipping creation."
            exit 0
          fi
          bench new-site frontend \
            --admin-password "\$ADMIN_PASSWORD" \
            --mariadb-root-password "\$DB_PASSWORD" \
            --install-app erpnext \
            --set-default
          echo "Site creation completed successfully!"
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-admin-secret
              key: password
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
              key: password
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        - name: backups-data
          mountPath: /home/frappe/frappe-bench/sites/backups
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      - name: backups-data
        persistentVolumeClaim:
          claimName: erpnext-backups-pvc
      nodeSelector:
        node-type: worker
EOF
}

# Function to deploy to Kubernetes
deploy_to_kubernetes() {
    print_header "Deploying to Kubernetes..."
    
    # Apply manifests in order
    print_status "Creating namespace..."
    kubectl apply -f /tmp/k8s-manifests/namespace.yaml
    
    print_status "Creating storage resources..."
    kubectl apply -f /tmp/k8s-manifests/storage.yaml
    
    print_status "Creating configuration..."
    kubectl apply -f /tmp/k8s-manifests/configmap.yaml
    
    print_status "Creating secrets..."
    kubectl apply -f /tmp/k8s-manifests/secrets.yaml
    
    # Wait for external secrets to be ready
    print_status "Waiting for external secrets to be ready..."
    sleep 30
    
    print_status "Deploying backend..."
    kubectl apply -f /tmp/k8s-manifests/backend.yaml
    
    print_status "Deploying frontend..."
    kubectl apply -f /tmp/k8s-manifests/frontend.yaml
    
    print_status "Deploying workers..."
    kubectl apply -f /tmp/k8s-manifests/workers.yaml
    
    print_status "Creating ingress..."
    kubectl apply -f /tmp/k8s-manifests/ingress.yaml
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/erpnext-backend -n erpnext
    kubectl wait --for=condition=available --timeout=300s deployment/erpnext-frontend -n erpnext
    kubectl wait --for=condition=available --timeout=300s deployment/erpnext-queue-default -n erpnext
    kubectl wait --for=condition=available --timeout=300s deployment/erpnext-scheduler -n erpnext
    
    # Create site
    print_status "Creating ERPNext site..."
    kubectl apply -f /tmp/k8s-manifests/jobs.yaml
    
    # Wait for job to complete
    kubectl wait --for=condition=complete --timeout=600s job/erpnext-create-site -n erpnext
    
    print_status "Deployment completed successfully!"
}

# Function to configure autoscaling
configure_autoscaling() {
    print_header "Configuring autoscaling..."
    
    # Create HPA for backend
    kubectl autoscale deployment erpnext-backend \
        --namespace=erpnext \
        --cpu-percent=70 \
        --min=3 \
        --max=10
    
    # Create HPA for frontend
    kubectl autoscale deployment erpnext-frontend \
        --namespace=erpnext \
        --cpu-percent=70 \
        --min=2 \
        --max=8
    
    # Create HPA for workers
    kubectl autoscale deployment erpnext-queue-default \
        --namespace=erpnext \
        --cpu-percent=80 \
        --min=2 \
        --max=6
    
    print_status "Autoscaling configured"
}

# Function to display deployment summary
display_summary() {
    print_header "Deployment Summary"
    
    # Get ALB endpoint
    ALB_ENDPOINT=$(kubectl get ingress erpnext-ingress -n erpnext -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    echo ""
    print_status "ERPNext EKS deployment completed successfully!"
    echo ""
    print_status "Access Information:"
    if [ -n "$ALB_ENDPOINT" ]; then
        print_status "  Application URL: http://$ALB_ENDPOINT"
    else
        print_status "  Application URL: Check ALB endpoint with 'kubectl get ingress -n erpnext'"
    fi
    print_status "  Domain: $DOMAIN_NAME (configure DNS to point to ALB endpoint)"
    print_status "  Admin Username: Administrator"
    print_status "  Admin Password: Check AWS Secrets Manager (${PROJECT_NAME}/admin/password)"
    echo ""
    print_status "AWS Resources Created:"
    print_status "  EKS Cluster: $CLUSTER_NAME"
    print_status "  EFS File System: $EFS_ID"
    print_status "  VPC: $VPC_ID"
    echo ""
    print_status "Kubernetes Resources:"
    print_status "  Namespace: erpnext"
    print_status "  Deployments: erpnext-backend, erpnext-frontend, erpnext-queue-default, erpnext-scheduler"
    print_status "  Services: erpnext-backend, erpnext-frontend"
    print_status "  Ingress: erpnext-ingress"
    echo ""
    print_status "Next Steps:"
    print_status "  1. Configure DNS to point $DOMAIN_NAME to ALB endpoint"
    print_status "  2. Set up SSL certificate in ACM and update ingress"
    print_status "  3. Configure monitoring with Prometheus/Grafana"
    print_status "  4. Set up backup procedures"
    echo ""
    print_status "Useful Commands:"
    print_status "  kubectl get pods -n erpnext"
    print_status "  kubectl logs -f deployment/erpnext-backend -n erpnext"
    print_status "  kubectl get ingress -n erpnext"
    echo ""
}

# Function to clean up temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf /tmp/erpnext-eks-cluster.yaml /tmp/k8s-manifests /tmp/iam_policy.json
}

# Main execution function
main() {
    print_header "Starting ERPNext EKS Deployment"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --profile)
                AWS_PROFILE="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --project-name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --domain)
                DOMAIN_NAME="$2"
                shift 2
                ;;
            --kubernetes-version)
                KUBERNETES_VERSION="$2"
                shift 2
                ;;
            --node-type)
                NODE_INSTANCE_TYPE="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --region REGION              AWS region (default: us-east-1)"
                echo "  --profile PROFILE            AWS profile (default: default)"
                echo "  --cluster-name NAME          EKS cluster name (default: erpnext-cluster)"
                echo "  --project-name NAME          Project name prefix (default: erpnext)"
                echo "  --domain DOMAIN              Domain name (default: erpnext.yourdomain.com)"
                echo "  --kubernetes-version VERSION Kubernetes version (default: 1.28)"
                echo "  --node-type TYPE             EC2 instance type for nodes (default: t3.medium)"
                echo "  --help                       Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute deployment steps
    check_prerequisites
    check_vpc
    get_security_groups
    get_database_endpoints
    create_efs
    create_cluster_config
    create_eks_cluster
    install_addons
    create_kubernetes_manifests
    deploy_to_kubernetes
    configure_autoscaling
    display_summary
    cleanup
    
    print_header "Deployment completed successfully!"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Execute main function with all arguments
main "$@"