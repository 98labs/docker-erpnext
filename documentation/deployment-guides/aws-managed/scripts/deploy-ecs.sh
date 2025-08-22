#!/bin/bash

# ERPNext ECS Deployment Script for AWS Managed Services
# This script automates the deployment of ERPNext on Amazon ECS with RDS and MemoryDB

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

# Infrastructure settings
DB_INSTANCE_CLASS=${DB_INSTANCE_CLASS:-db.t3.medium}
REDIS_NODE_TYPE=${REDIS_NODE_TYPE:-db.t4g.small}
ECS_TASK_CPU=${ECS_TASK_CPU:-1024}
ECS_TASK_MEMORY=${ECS_TASK_MEMORY:-2048}

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
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first."
        exit 1
    fi
    
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
    
    ALB_SG=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-alb-sg" \
        --query "SecurityGroups[0].GroupId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    APP_SG=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-app-sg" \
        --query "SecurityGroups[0].GroupId" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    print_status "ALB Security Group: $ALB_SG"
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
        
        # Create access point
        ACCESS_POINT_ID=$(aws efs create-access-point \
            --file-system-id $EFS_ID \
            --posix-user Uid=1000,Gid=1000 \
            --root-directory Path="/sites",CreationInfo='{OwnerUid=1000,OwnerGid=1000,Permissions=755}' \
            --tags Key=Name,Value=${PROJECT_NAME}-sites-access-point \
            --query "AccessPointId" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
        
        print_status "Created EFS Access Point: $ACCESS_POINT_ID"
    else
        print_status "Using existing EFS: $EFS_ID"
        
        # Get access point ID
        ACCESS_POINT_ID=$(aws efs describe-access-points \
            --file-system-id $EFS_ID \
            --query "AccessPoints[?Tags[?Key=='Name' && Value=='${PROJECT_NAME}-sites-access-point']].AccessPointId" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
    fi
}

# Function to create ECS cluster
create_ecs_cluster() {
    print_header "Creating ECS cluster..."
    
    # Check if cluster exists
    CLUSTER_EXISTS=$(aws ecs describe-clusters \
        --clusters $CLUSTER_NAME \
        --query "clusters[0].status" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "")
    
    if [ "$CLUSTER_EXISTS" != "ACTIVE" ]; then
        print_status "Creating ECS cluster: $CLUSTER_NAME"
        aws ecs create-cluster \
            --cluster-name $CLUSTER_NAME \
            --capacity-providers FARGATE FARGATE_SPOT \
            --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
            --settings name=containerInsights,value=enabled \
            --tags key=Name,value=$CLUSTER_NAME key=Application,value=ERPNext \
            --region $AWS_REGION \
            --profile $AWS_PROFILE
    else
        print_status "Using existing ECS cluster: $CLUSTER_NAME"
    fi
}

# Function to create ALB
create_alb() {
    print_header "Creating Application Load Balancer..."
    
    # Check if ALB exists
    ALB_ARN=$(aws elbv2 describe-load-balancers \
        --names ${PROJECT_NAME}-alb \
        --query "LoadBalancers[0].LoadBalancerArn" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || echo "")
    
    if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
        print_status "Creating Application Load Balancer..."
        ALB_ARN=$(aws elbv2 create-load-balancer \
            --name ${PROJECT_NAME}-alb \
            --subnets $PUBLIC_SUBNET_1A $PUBLIC_SUBNET_1B \
            --security-groups $ALB_SG \
            --scheme internet-facing \
            --type application \
            --ip-address-type ipv4 \
            --tags Key=Name,Value=${PROJECT_NAME}-alb Key=Application,Value=ERPNext \
            --query "LoadBalancers[0].LoadBalancerArn" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
        
        print_status "Created ALB: $ALB_ARN"
        
        # Wait for ALB to be active
        print_status "Waiting for ALB to be active..."
        aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN --region $AWS_REGION --profile $AWS_PROFILE
    else
        print_status "Using existing ALB: $ALB_ARN"
    fi
    
    # Create target groups
    create_target_groups
    
    # Create listeners
    create_listeners
}

# Function to create target groups
create_target_groups() {
    print_header "Creating target groups..."
    
    # Frontend target group
    FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
        --name ${PROJECT_NAME}-frontend-tg \
        --protocol HTTP \
        --port 8080 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /health \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 5 \
        --tags Key=Name,Value=${PROJECT_NAME}-frontend-tg \
        --query "TargetGroups[0].TargetGroupArn" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || \
        aws elbv2 describe-target-groups \
            --names ${PROJECT_NAME}-frontend-tg \
            --query "TargetGroups[0].TargetGroupArn" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
    
    # Backend target group
    BACKEND_TG_ARN=$(aws elbv2 create-target-group \
        --name ${PROJECT_NAME}-backend-tg \
        --protocol HTTP \
        --port 8000 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /api/method/ping \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 5 \
        --tags Key=Name,Value=${PROJECT_NAME}-backend-tg \
        --query "TargetGroups[0].TargetGroupArn" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || \
        aws elbv2 describe-target-groups \
            --names ${PROJECT_NAME}-backend-tg \
            --query "TargetGroups[0].TargetGroupArn" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
    
    # Socket.IO target group
    SOCKETIO_TG_ARN=$(aws elbv2 create-target-group \
        --name ${PROJECT_NAME}-socketio-tg \
        --protocol HTTP \
        --port 9000 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /socket.io/ \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 5 \
        --tags Key=Name,Value=${PROJECT_NAME}-socketio-tg \
        --query "TargetGroups[0].TargetGroupArn" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || \
        aws elbv2 describe-target-groups \
            --names ${PROJECT_NAME}-socketio-tg \
            --query "TargetGroups[0].TargetGroupArn" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
    
    print_status "Target Groups created:"
    print_status "  Frontend: $FRONTEND_TG_ARN"
    print_status "  Backend: $BACKEND_TG_ARN"
    print_status "  Socket.IO: $SOCKETIO_TG_ARN"
}

# Function to create listeners
create_listeners() {
    print_header "Creating ALB listeners..."
    
    # HTTP listener (redirects to HTTPS)
    LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
        --tags Key=Name,Value=${PROJECT_NAME}-alb-listener-80 \
        --query "Listeners[0].ListenerArn" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || \
        aws elbv2 describe-listeners \
            --load-balancer-arn $ALB_ARN \
            --query "Listeners[?Port==\`80\`].ListenerArn" \
            --output text \
            --region $AWS_REGION \
            --profile $AWS_PROFILE)
    
    # Create listener rules
    create_listener_rules $LISTENER_ARN
}

# Function to create listener rules
create_listener_rules() {
    local listener_arn=$1
    
    print_header "Creating listener rules..."
    
    # Rule for Socket.IO traffic
    aws elbv2 create-rule \
        --listener-arn $listener_arn \
        --priority 100 \
        --conditions Field=path-pattern,Values="/socket.io/*" \
        --actions Type=forward,TargetGroupArn=$SOCKETIO_TG_ARN \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || true
    
    # Rule for API traffic
    aws elbv2 create-rule \
        --listener-arn $listener_arn \
        --priority 200 \
        --conditions Field=path-pattern,Values="/api/*" \
        --actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN \
        --region $AWS_REGION \
        --profile $AWS_PROFILE 2>/dev/null || true
}

# Function to register task definitions
register_task_definitions() {
    print_header "Registering ECS task definitions..."
    
    # Create backend task definition
    create_backend_task_definition
    
    # Create frontend task definition
    create_frontend_task_definition
    
    # Create worker task definition
    create_worker_task_definition
    
    # Create scheduler task definition
    create_scheduler_task_definition
}

# Function to create backend task definition
create_backend_task_definition() {
    print_status "Creating backend task definition..."
    
    cat > /tmp/erpnext-backend-task.json <<EOF
{
    "family": "${PROJECT_NAME}-backend",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "$ECS_TASK_CPU",
    "memory": "$ECS_TASK_MEMORY",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "${PROJECT_NAME}-backend",
            "image": "frappe/erpnext-worker:v14",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 8000,
                    "protocol": "tcp"
                },
                {
                    "containerPort": 9000,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "APP_VERSION",
                    "value": "v14"
                },
                {
                    "name": "APP_URL",
                    "value": "$DOMAIN_NAME"
                },
                {
                    "name": "DB_HOST",
                    "value": "$DB_HOST"
                },
                {
                    "name": "DB_PORT",
                    "value": "3306"
                },
                {
                    "name": "DB_NAME",
                    "value": "erpnext"
                },
                {
                    "name": "DB_USER",
                    "value": "admin"
                },
                {
                    "name": "REDIS_CACHE_URL",
                    "value": "redis://$REDIS_HOST:6379/0"
                },
                {
                    "name": "REDIS_QUEUE_URL",
                    "value": "redis://$REDIS_HOST:6379/1"
                },
                {
                    "name": "REDIS_SOCKETIO_URL",
                    "value": "redis://$REDIS_HOST:6379/2"
                }
            ],
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/database/password"
                },
                {
                    "name": "REDIS_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/redis/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "${PROJECT_NAME}-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/${PROJECT_NAME}-backend",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": [
                    "CMD-SHELL",
                    "curl -f http://localhost:8000/api/method/ping || exit 1"
                ],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 60
            }
        }
    ],
    "volumes": [
        {
            "name": "${PROJECT_NAME}-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

    aws ecs register-task-definition \
        --cli-input-json file:///tmp/erpnext-backend-task.json \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    print_status "Backend task definition registered"
}

# Function to create frontend task definition
create_frontend_task_definition() {
    print_status "Creating frontend task definition..."
    
    cat > /tmp/erpnext-frontend-task.json <<EOF
{
    "family": "${PROJECT_NAME}-frontend",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "${PROJECT_NAME}-frontend",
            "image": "frappe/erpnext-nginx:v14",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 8080,
                    "protocol": "tcp"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "${PROJECT_NAME}-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites",
                    "readOnly": true
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/${PROJECT_NAME}-frontend",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": [
                    "CMD-SHELL",
                    "curl -f http://localhost:8080/health || exit 1"
                ],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 30
            }
        }
    ],
    "volumes": [
        {
            "name": "${PROJECT_NAME}-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

    aws ecs register-task-definition \
        --cli-input-json file:///tmp/erpnext-frontend-task.json \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    print_status "Frontend task definition registered"
}

# Function to create worker task definition
create_worker_task_definition() {
    print_status "Creating worker task definition..."
    
    cat > /tmp/erpnext-worker-task.json <<EOF
{
    "family": "${PROJECT_NAME}-worker",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "${PROJECT_NAME}-worker-default",
            "image": "frappe/erpnext-worker:v14",
            "essential": true,
            "command": ["bench", "worker", "--queue", "default"],
            "environment": [
                {
                    "name": "DB_HOST",
                    "value": "$DB_HOST"
                },
                {
                    "name": "DB_PORT",
                    "value": "3306"
                },
                {
                    "name": "DB_NAME",
                    "value": "erpnext"
                },
                {
                    "name": "DB_USER",
                    "value": "admin"
                },
                {
                    "name": "REDIS_CACHE_URL",
                    "value": "redis://$REDIS_HOST:6379/0"
                },
                {
                    "name": "REDIS_QUEUE_URL",
                    "value": "redis://$REDIS_HOST:6379/1"
                },
                {
                    "name": "REDIS_SOCKETIO_URL",
                    "value": "redis://$REDIS_HOST:6379/2"
                }
            ],
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/database/password"
                },
                {
                    "name": "REDIS_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/redis/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "${PROJECT_NAME}-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/${PROJECT_NAME}-worker",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "${PROJECT_NAME}-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

    aws ecs register-task-definition \
        --cli-input-json file:///tmp/erpnext-worker-task.json \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    print_status "Worker task definition registered"
}

# Function to create scheduler task definition
create_scheduler_task_definition() {
    print_status "Creating scheduler task definition..."
    
    cat > /tmp/erpnext-scheduler-task.json <<EOF
{
    "family": "${PROJECT_NAME}-scheduler",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "${PROJECT_NAME}-scheduler",
            "image": "frappe/erpnext-worker:v14",
            "essential": true,
            "command": ["bench", "schedule"],
            "environment": [
                {
                    "name": "DB_HOST",
                    "value": "$DB_HOST"
                },
                {
                    "name": "DB_PORT",
                    "value": "3306"
                },
                {
                    "name": "DB_NAME",
                    "value": "erpnext"
                },
                {
                    "name": "DB_USER",
                    "value": "admin"
                },
                {
                    "name": "REDIS_CACHE_URL",
                    "value": "redis://$REDIS_HOST:6379/0"
                },
                {
                    "name": "REDIS_QUEUE_URL",
                    "value": "redis://$REDIS_HOST:6379/1"
                },
                {
                    "name": "REDIS_SOCKETIO_URL",
                    "value": "redis://$REDIS_HOST:6379/2"
                }
            ],
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/database/password"
                },
                {
                    "name": "REDIS_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/redis/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "${PROJECT_NAME}-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/${PROJECT_NAME}-worker",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "scheduler"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "${PROJECT_NAME}-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

    aws ecs register-task-definition \
        --cli-input-json file:///tmp/erpnext-scheduler-task.json \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    print_status "Scheduler task definition registered"
}

# Function to create ECS services
create_ecs_services() {
    print_header "Creating ECS services..."
    
    # Create backend service
    print_status "Creating backend service..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name ${PROJECT_NAME}-backend \
        --task-definition ${PROJECT_NAME}-backend:1 \
        --desired-count 2 \
        --launch-type FARGATE \
        --platform-version LATEST \
        --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
        --load-balancers targetGroupArn=$BACKEND_TG_ARN,containerName=${PROJECT_NAME}-backend,containerPort=8000 targetGroupArn=$SOCKETIO_TG_ARN,containerName=${PROJECT_NAME}-backend,containerPort=9000 \
        --health-check-grace-period-seconds 60 \
        --tags key=Name,value=${PROJECT_NAME}-backend key=Application,value=ERPNext \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    # Create frontend service
    print_status "Creating frontend service..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name ${PROJECT_NAME}-frontend \
        --task-definition ${PROJECT_NAME}-frontend:1 \
        --desired-count 2 \
        --launch-type FARGATE \
        --platform-version LATEST \
        --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
        --load-balancers targetGroupArn=$FRONTEND_TG_ARN,containerName=${PROJECT_NAME}-frontend,containerPort=8080 \
        --health-check-grace-period-seconds 30 \
        --tags key=Name,value=${PROJECT_NAME}-frontend key=Application,value=ERPNext \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    # Create worker service
    print_status "Creating worker service..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name ${PROJECT_NAME}-worker \
        --task-definition ${PROJECT_NAME}-worker:1 \
        --desired-count 2 \
        --launch-type FARGATE \
        --platform-version LATEST \
        --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
        --tags key=Name,value=${PROJECT_NAME}-worker key=Application,value=ERPNext \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    # Create scheduler service
    print_status "Creating scheduler service..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name ${PROJECT_NAME}-scheduler \
        --task-definition ${PROJECT_NAME}-scheduler:1 \
        --desired-count 1 \
        --launch-type FARGATE \
        --platform-version LATEST \
        --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
        --tags key=Name,value=${PROJECT_NAME}-scheduler key=Application,value=ERPNext \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
}

# Function to create site
create_site() {
    print_header "Creating ERPNext site..."
    
    print_status "Running site creation task..."
    
    # Create site task definition (temporary)
    cat > /tmp/erpnext-create-site-task.json <<EOF
{
    "family": "${PROJECT_NAME}-create-site",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "1024",
    "memory": "2048",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "create-site",
            "image": "frappe/erpnext-worker:v14",
            "essential": true,
            "command": [
                "bash",
                "-c",
                "set -e; echo 'Starting ERPNext site creation...'; if [ -d '/home/frappe/frappe-bench/sites/frontend' ]; then echo 'Site already exists. Skipping creation.'; exit 0; fi; bench new-site frontend --admin-password \\$ADMIN_PASSWORD --mariadb-root-password \\$DB_PASSWORD --install-app erpnext --set-default; echo 'Site creation completed successfully!'"
            ],
            "environment": [
                {
                    "name": "DB_HOST",
                    "value": "$DB_HOST"
                },
                {
                    "name": "DB_PORT",
                    "value": "3306"
                },
                {
                    "name": "DB_NAME",
                    "value": "erpnext"
                },
                {
                    "name": "DB_USER",
                    "value": "admin"
                },
                {
                    "name": "REDIS_CACHE_URL",
                    "value": "redis://$REDIS_HOST:6379/0"
                },
                {
                    "name": "REDIS_QUEUE_URL",
                    "value": "redis://$REDIS_HOST:6379/1"
                },
                {
                    "name": "REDIS_SOCKETIO_URL",
                    "value": "redis://$REDIS_HOST:6379/2"
                }
            ],
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/database/password"
                },
                {
                    "name": "ADMIN_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${PROJECT_NAME}/admin/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "${PROJECT_NAME}-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/${PROJECT_NAME}-backend",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "create-site"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "${PROJECT_NAME}-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

    # Register task definition
    aws ecs register-task-definition \
        --cli-input-json file:///tmp/erpnext-create-site-task.json \
        --region $AWS_REGION \
        --profile $AWS_PROFILE > /dev/null
    
    # Run the task
    TASK_ARN=$(aws ecs run-task \
        --cluster $CLUSTER_NAME \
        --task-definition ${PROJECT_NAME}-create-site:1 \
        --launch-type FARGATE \
        --platform-version LATEST \
        --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
        --query "tasks[0].taskArn" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    print_status "Site creation task started: $TASK_ARN"
    print_status "Waiting for site creation to complete..."
    
    # Wait for task to complete
    aws ecs wait tasks-stopped \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARN \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
    
    # Check task exit code
    EXIT_CODE=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARN \
        --query "tasks[0].containers[0].exitCode" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    if [ "$EXIT_CODE" = "0" ]; then
        print_status "Site creation completed successfully!"
    else
        print_error "Site creation failed with exit code: $EXIT_CODE"
        print_error "Check the logs for more details:"
        print_error "aws logs get-log-events --log-group-name /aws/ecs/${PROJECT_NAME}-backend --log-stream-name ecs/create-site/$(echo $TASK_ARN | cut -d'/' -f3) --region $AWS_REGION"
        exit 1
    fi
}

# Function to display deployment summary
display_summary() {
    print_header "Deployment Summary"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names ${PROJECT_NAME}-alb \
        --query "LoadBalancers[0].DNSName" \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    
    echo ""
    print_status "ERPNext ECS deployment completed successfully!"
    echo ""
    print_status "Access Information:"
    print_status "  Application URL: http://$ALB_DNS"
    print_status "  Domain: $DOMAIN_NAME (configure DNS to point to $ALB_DNS)"
    print_status "  Admin Username: Administrator"
    print_status "  Admin Password: Check AWS Secrets Manager (${PROJECT_NAME}/admin/password)"
    echo ""
    print_status "AWS Resources Created:"
    print_status "  ECS Cluster: $CLUSTER_NAME"
    print_status "  Load Balancer: ${PROJECT_NAME}-alb"
    print_status "  EFS File System: $EFS_ID"
    print_status "  VPC: $VPC_ID"
    echo ""
    print_status "Next Steps:"
    print_status "  1. Configure DNS to point $DOMAIN_NAME to $ALB_DNS"
    print_status "  2. Set up SSL certificate in ACM and update ALB listener"
    print_status "  3. Configure monitoring and alerts"
    print_status "  4. Set up backup procedures"
    echo ""
    print_warning "Note: This deployment uses HTTP only. Configure HTTPS for production use."
}

# Function to clean up temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f /tmp/erpnext-*-task.json
}

# Main execution function
main() {
    print_header "Starting ERPNext ECS Deployment"
    
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
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --region REGION        AWS region (default: us-east-1)"
                echo "  --profile PROFILE      AWS profile (default: default)"
                echo "  --cluster-name NAME    ECS cluster name (default: erpnext-cluster)"
                echo "  --project-name NAME    Project name prefix (default: erpnext)"
                echo "  --domain DOMAIN        Domain name (default: erpnext.yourdomain.com)"
                echo "  --help                 Show this help message"
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
    create_ecs_cluster
    create_alb
    register_task_definitions
    create_ecs_services
    
    # Wait for services to stabilize
    print_header "Waiting for services to stabilize..."
    sleep 60
    
    create_site
    display_summary
    cleanup
    
    print_header "Deployment completed successfully!"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Execute main function with all arguments
main "$@"