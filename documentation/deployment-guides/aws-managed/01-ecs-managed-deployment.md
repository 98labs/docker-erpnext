# ERPNext ECS Deployment with Managed Database Services

## Overview

This guide provides step-by-step instructions for deploying ERPNext on Amazon Elastic Container Service (ECS) using Amazon RDS for MySQL and Amazon MemoryDB for Redis. This approach offers excellent scalability, reliability, and operational efficiency with AWS managed services.

## 🏗️ ECS Cluster Setup

### 1. Create ECS Cluster with Fargate
```bash
# Create ECS cluster
aws ecs create-cluster \
    --cluster-name erpnext-cluster \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --settings name=containerInsights,value=enabled \
    --tags key=Name,value=erpnext-cluster key=Application,value=ERPNext

# Verify cluster creation
aws ecs describe-clusters --clusters erpnext-cluster
```

### 2. Create Application Load Balancer
```bash
# Get subnet IDs
PUBLIC_SUBNET_1A=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-public-subnet-1a" \
    --query "Subnets[0].SubnetId" --output text)

PUBLIC_SUBNET_1B=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-public-subnet-1b" \
    --query "Subnets[0].SubnetId" --output text)

ALB_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=erpnext-alb-sg" \
    --query "SecurityGroups[0].GroupId" --output text)

# Create Application Load Balancer
aws elbv2 create-load-balancer \
    --name erpnext-alb \
    --subnets $PUBLIC_SUBNET_1A $PUBLIC_SUBNET_1B \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value=erpnext-alb Key=Application,Value=ERPNext

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names erpnext-alb \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=erpnext-vpc" \
    --query "Vpcs[0].VpcId" --output text)

# Create target groups
aws elbv2 create-target-group \
    --name erpnext-frontend-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 5 \
    --tags Key=Name,Value=erpnext-frontend-tg

aws elbv2 create-target-group \
    --name erpnext-backend-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /api/method/ping \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 5 \
    --tags Key=Name,Value=erpnext-backend-tg

aws elbv2 create-target-group \
    --name erpnext-socketio-tg \
    --protocol HTTP \
    --port 9000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /socket.io/ \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 5 \
    --tags Key=Name,Value=erpnext-socketio-tg

# Get target group ARNs
FRONTEND_TG_ARN=$(aws elbv2 describe-target-groups \
    --names erpnext-frontend-tg \
    --query "TargetGroups[0].TargetGroupArn" --output text)

BACKEND_TG_ARN=$(aws elbv2 describe-target-groups \
    --names erpnext-backend-tg \
    --query "TargetGroups[0].TargetGroupArn" --output text)

SOCKETIO_TG_ARN=$(aws elbv2 describe-target-groups \
    --names erpnext-socketio-tg \
    --query "TargetGroups[0].TargetGroupArn" --output text)

# Create ALB listeners
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --tags Key=Name,Value=erpnext-alb-listener-80

# Create listener rules for routing
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --query "Listeners[0].ListenerArn" --output text)

# Rule for Socket.IO traffic
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/socket.io/*" \
    --actions Type=forward,TargetGroupArn=$SOCKETIO_TG_ARN

# Rule for API traffic
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN
```

## 📦 EFS for Shared Storage
```bash
# Create EFS file system for shared sites data
aws efs create-file-system \
    --creation-token erpnext-sites-$(date +%s) \
    --performance-mode generalPurpose \
    --throughput-mode provisioned \
    --provisioned-throughput-in-mibps 100 \
    --encrypted \
    --tags Key=Name,Value=erpnext-sites-efs Key=Application,Value=ERPNext

# Get EFS ID
EFS_ID=$(aws efs describe-file-systems \
    --query "FileSystems[?Tags[?Key=='Name' && Value=='erpnext-sites-efs']].FileSystemId" --output text)

# Get private subnet IDs
PRIVATE_SUBNET_1A=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-private-subnet-1a" \
    --query "Subnets[0].SubnetId" --output text)

PRIVATE_SUBNET_1B=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-private-subnet-1b" \
    --query "Subnets[0].SubnetId" --output text)

APP_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=erpnext-app-sg" \
    --query "SecurityGroups[0].GroupId" --output text)

# Create EFS mount targets
aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $PRIVATE_SUBNET_1A \
    --security-groups $APP_SG

aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $PRIVATE_SUBNET_1B \
    --security-groups $APP_SG

# Create access point for ERPNext sites
aws efs create-access-point \
    --file-system-id $EFS_ID \
    --posix-user Uid=1000,Gid=1000 \
    --root-directory Path="/sites",CreationInfo='{OwnerUid=1000,OwnerGid=1000,Permissions=755}' \
    --tags Key=Name,Value=erpnext-sites-access-point

# Get access point ARN
SITES_ACCESS_POINT_ID=$(aws efs describe-access-points \
    --file-system-id $EFS_ID \
    --query "AccessPoints[?Tags[?Key=='Name' && Value=='erpnext-sites-access-point']].AccessPointId" --output text)
```

## 🔐 Task Execution Role and Task Role
```bash
# Create task execution role
cat > ecs-task-execution-role-trust.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name ERPNextECSExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-role-trust.json

# Attach required policies
aws iam attach-role-policy \
    --role-name ERPNextECSExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create custom policy for Secrets Manager and Parameter Store
cat > ecs-secrets-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "kms:Decrypt"
            ],
            "Resource": [
                "arn:aws:secretsmanager:us-east-1:*:secret:erpnext/*",
                "arn:aws:ssm:us-east-1:*:parameter/erpnext/*"
            ]
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name ERPNextSecretsPolicy \
    --policy-document file://ecs-secrets-policy.json

aws iam attach-role-policy \
    --role-name ERPNextECSExecutionRole \
    --policy-arn $(aws iam list-policies --query "Policies[?PolicyName=='ERPNextSecretsPolicy'].Arn" --output text)

# Create task role for application permissions
aws iam create-role \
    --role-name ERPNextECSTaskRole \
    --assume-role-policy-document file://ecs-task-execution-role-trust.json

# Attach policies for S3 access (for file uploads)
aws iam attach-role-policy \
    --role-name ERPNextECSTaskRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

## 🐳 ECS Task Definitions

### 1. ERPNext Backend Task Definition
```bash
# Get database and Redis endpoints
DB_HOST=$(aws ssm get-parameter --name "/erpnext/database/host" --query "Parameter.Value" --output text)
REDIS_HOST=$(aws ssm get-parameter --name "/erpnext/redis/host" --query "Parameter.Value" --output text)

# Create backend task definition
cat > erpnext-backend-task.json <<EOF
{
    "family": "erpnext-backend",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "1024",
    "memory": "2048",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "erpnext-backend",
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
                    "value": "erpnext.yourdomain.com"
                },
                {
                    "name": "APP_USER",
                    "value": "Administrator"
                },
                {
                    "name": "APP_DB_PARAM",
                    "value": "db"
                },
                {
                    "name": "DEVELOPER_MODE",
                    "value": "0"
                },
                {
                    "name": "ENABLE_SCHEDULER",
                    "value": "1"
                },
                {
                    "name": "SOCKETIO_PORT",
                    "value": "9000"
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
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/database/password"
                },
                {
                    "name": "REDIS_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/redis/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "erpnext-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/erpnext-backend",
                    "awslogs-region": "us-east-1",
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
            "name": "erpnext-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$SITES_ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://erpnext-backend-task.json
```

### 2. ERPNext Frontend Task Definition
```bash
cat > erpnext-frontend-task.json <<EOF
{
    "family": "erpnext-frontend",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "erpnext-frontend",
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
                    "sourceVolume": "erpnext-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites",
                    "readOnly": true
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/erpnext-frontend",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": [
                    "CMD-SHELL",
                    "curl -f http://localhost:8080/ || exit 1"
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
            "name": "erpnext-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$SITES_ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://erpnext-frontend-task.json
```

### 3. ERPNext Worker Task Definition
```bash
cat > erpnext-worker-task.json <<EOF
{
    "family": "erpnext-worker",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "erpnext-worker-default",
            "image": "frappe/erpnext-worker:v14",
            "essential": true,
            "command": ["bench", "worker", "--queue", "default"],
            "environment": [
                {
                    "name": "APP_VERSION",
                    "value": "v14"
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
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/database/password"
                },
                {
                    "name": "REDIS_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/redis/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "erpnext-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/erpnext-worker",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "erpnext-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$SITES_ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://erpnext-worker-task.json
```

### 4. ERPNext Scheduler Task Definition
```bash
cat > erpnext-scheduler-task.json <<EOF
{
    "family": "erpnext-scheduler",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSTaskRole",
    "containerDefinitions": [
        {
            "name": "erpnext-scheduler",
            "image": "frappe/erpnext-worker:v14",
            "essential": true,
            "command": ["bench", "schedule"],
            "environment": [
                {
                    "name": "APP_VERSION",
                    "value": "v14"
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
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/database/password"
                },
                {
                    "name": "REDIS_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/redis/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "erpnext-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/erpnext-worker",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "scheduler"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "erpnext-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$SITES_ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://erpnext-scheduler-task.json
```

## 🚀 Deploy ECS Services

### 1. Create ERPNext Backend Service
```bash
aws ecs create-service \
    --cluster erpnext-cluster \
    --service-name erpnext-backend \
    --task-definition erpnext-backend:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
    --load-balancers targetGroupArn=$BACKEND_TG_ARN,containerName=erpnext-backend,containerPort=8000 targetGroupArn=$SOCKETIO_TG_ARN,containerName=erpnext-backend,containerPort=9000 \
    --health-check-grace-period-seconds 60 \
    --tags key=Name,value=erpnext-backend key=Application,value=ERPNext
```

### 2. Create ERPNext Frontend Service
```bash
aws ecs create-service \
    --cluster erpnext-cluster \
    --service-name erpnext-frontend \
    --task-definition erpnext-frontend:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
    --load-balancers targetGroupArn=$FRONTEND_TG_ARN,containerName=erpnext-frontend,containerPort=8080 \
    --health-check-grace-period-seconds 30 \
    --tags key=Name,value=erpnext-frontend key=Application,value=ERPNext
```

### 3. Create ERPNext Worker Service
```bash
aws ecs create-service \
    --cluster erpnext-cluster \
    --service-name erpnext-worker \
    --task-definition erpnext-worker:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
    --tags key=Name,value=erpnext-worker key=Application,value=ERPNext
```

### 4. Create ERPNext Scheduler Service
```bash
aws ecs create-service \
    --cluster erpnext-cluster \
    --service-name erpnext-scheduler \
    --task-definition erpnext-scheduler:1 \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
    --tags key=Name,value=erpnext-scheduler key=Application,value=ERPNext
```

## 🏗️ Initialize ERPNext Site

### 1. Create Site Initialization Task
```bash
cat > erpnext-create-site-task.json <<EOF
{
    "family": "erpnext-create-site",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "1024",
    "memory": "2048",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextECSTaskRole",
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
                    "name": "APP_VERSION",
                    "value": "v14"
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
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/database/password"
                },
                {
                    "name": "ADMIN_PASSWORD",
                    "valueFrom": "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:erpnext/admin/password"
                }
            ],
            "mountPoints": [
                {
                    "sourceVolume": "erpnext-sites",
                    "containerPath": "/home/frappe/frappe-bench/sites"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/aws/ecs/erpnext-backend",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "create-site"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "erpnext-sites",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "accessPointId": "$SITES_ACCESS_POINT_ID"
            }
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://erpnext-create-site-task.json

# Run the site creation task
aws ecs run-task \
    --cluster erpnext-cluster \
    --task-definition erpnext-create-site:1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A],securityGroups=[$APP_SG],assignPublicIp=DISABLED}"
```

### 2. Monitor Site Creation
```bash
# List running tasks
aws ecs list-tasks --cluster erpnext-cluster --family erpnext-create-site

# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster erpnext-cluster --family erpnext-create-site --query "taskArns[0]" --output text)

# Check task status
aws ecs describe-tasks --cluster erpnext-cluster --tasks $TASK_ARN

# View logs (replace log stream with actual stream name)
aws logs describe-log-streams --log-group-name "/aws/ecs/erpnext-backend" --order-by LastEventTime --descending

# Get specific log stream
LOG_STREAM=$(aws logs describe-log-streams \
    --log-group-name "/aws/ecs/erpnext-backend" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query "logStreams[0].logStreamName" --output text)

aws logs get-log-events \
    --log-group-name "/aws/ecs/erpnext-backend" \
    --log-stream-name $LOG_STREAM
```

## 📊 Auto Scaling Configuration

### 1. Application Auto Scaling for ECS Services
```bash
# Register scalable targets
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/erpnext-cluster/erpnext-backend \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 10

aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/erpnext-cluster/erpnext-frontend \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 10

aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/erpnext-cluster/erpnext-worker \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 8

# Create scaling policies
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/erpnext-cluster/erpnext-backend \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name erpnext-backend-cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleOutCooldown": 300,
        "ScaleInCooldown": 300
    }'

aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/erpnext-cluster/erpnext-frontend \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name erpnext-frontend-cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleOutCooldown": 300,
        "ScaleInCooldown": 300
    }'

# ALB request count scaling for frontend
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/erpnext-cluster/erpnext-frontend \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name erpnext-frontend-request-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 1000.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ALBRequestCountPerTarget",
            "ResourceLabel": "'$(echo $ALB_ARN | cut -d'/' -f2-)'/'$(echo $FRONTEND_TG_ARN | cut -d'/' -f2-)'"
        },
        "ScaleOutCooldown": 300,
        "ScaleInCooldown": 300
    }'
```

## 🔍 Verification and Testing

### 1. Check Service Status
```bash
# Check all services
aws ecs describe-services \
    --cluster erpnext-cluster \
    --services erpnext-backend erpnext-frontend erpnext-worker erpnext-scheduler

# Check running tasks
aws ecs list-tasks --cluster erpnext-cluster --service-name erpnext-backend
aws ecs list-tasks --cluster erpnext-cluster --service-name erpnext-frontend
aws ecs list-tasks --cluster erpnext-cluster --service-name erpnext-worker
aws ecs list-tasks --cluster erpnext-cluster --service-name erpnext-scheduler

# Check target group health
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN
aws elbv2 describe-target-health --target-group-arn $BACKEND_TG_ARN
aws elbv2 describe-target-health --target-group-arn $SOCKETIO_TG_ARN
```

### 2. Test Application
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names erpnext-alb \
    --query "LoadBalancers[0].DNSName" --output text)

# Test frontend
curl -I http://$ALB_DNS/

# Test backend API
curl -I http://$ALB_DNS/api/method/ping

# Test Socket.IO
curl -I http://$ALB_DNS/socket.io/
```

## 🗄️ Backup Strategy

### 1. EFS Backup
```bash
# Create backup vault
aws backup create-backup-vault \
    --backup-vault-name erpnext-backup-vault \
    --encryption-key-arn arn:aws:kms:us-east-1:$(aws sts get-caller-identity --query Account --output text):alias/aws/backup

# Create backup plan
cat > backup-plan.json <<EOF
{
    "BackupPlanName": "ERPNextEFSBackupPlan",
    "Rules": [
        {
            "RuleName": "DailyBackups",
            "TargetBackupVaultName": "erpnext-backup-vault",
            "ScheduleExpression": "cron(0 5 ? * * *)",
            "StartWindowMinutes": 60,
            "CompletionWindowMinutes": 120,
            "Lifecycle": {
                "DeleteAfterDays": 30,
                "MoveToColdStorageAfterDays": 7
            }
        }
    ]
}
EOF

aws backup create-backup-plan --backup-plan file://backup-plan.json

# Create IAM role for AWS Backup
cat > backup-role-trust.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "backup.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name AWSBackupServiceRole \
    --assume-role-policy-document file://backup-role-trust.json

aws iam attach-role-policy \
    --role-name AWSBackupServiceRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup

# Create backup selection
BACKUP_PLAN_ID=$(aws backup get-backup-plan --backup-plan-id $(aws backup list-backup-plans --query "BackupPlansList[?BackupPlanName=='ERPNextEFSBackupPlan'].BackupPlanId" --output text) --query "BackupPlan.BackupPlanId" --output text)

cat > backup-selection.json <<EOF
{
    "SelectionName": "ERPNextEFSSelection",
    "IamRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AWSBackupServiceRole",
    "Resources": [
        "arn:aws:elasticfilesystem:us-east-1:$(aws sts get-caller-identity --query Account --output text):file-system/$EFS_ID"
    ]
}
EOF

aws backup create-backup-selection \
    --backup-plan-id $BACKUP_PLAN_ID \
    --backup-selection file://backup-selection.json
```

## 🛠️ Troubleshooting

### 1. Service Issues
```bash
# Check service events
aws ecs describe-services \
    --cluster erpnext-cluster \
    --services erpnext-backend \
    --query "services[0].events"

# Check task definition issues
aws ecs describe-task-definition --task-definition erpnext-backend:1

# Check task failures
aws ecs describe-tasks \
    --cluster erpnext-cluster \
    --tasks $(aws ecs list-tasks --cluster erpnext-cluster --service-name erpnext-backend --query "taskArns[0]" --output text)
```

### 2. Database Connectivity
```bash
# Test RDS connectivity
aws rds describe-db-instances --db-instance-identifier erpnext-db --query "DBInstances[0].DBInstanceStatus"

# Test from ECS task
aws ecs run-task \
    --cluster erpnext-cluster \
    --task-definition erpnext-backend:1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A],securityGroups=[$APP_SG],assignPublicIp=DISABLED}" \
    --overrides '{
        "containerOverrides": [
            {
                "name": "erpnext-backend",
                "command": ["mysql", "-h", "'$DB_HOST'", "-u", "admin", "-p", "-e", "SHOW DATABASES;"]
            }
        ]
    }'
```

### 3. Load Balancer Issues
```bash
# Check ALB health
aws elbv2 describe-load-balancers --names erpnext-alb

# Check target group targets
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN
```

## 💰 Cost Optimization for ECS

### 1. Use Fargate Spot
```bash
# Update services to use Fargate Spot for cost savings
aws ecs update-service \
    --cluster erpnext-cluster \
    --service erpnext-worker \
    --capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=3 capacityProvider=FARGATE,weight=1
```

### 2. Right-size Tasks
```bash
# Monitor task utilization and adjust CPU/memory
aws logs filter-log-events \
    --log-group-name /aws/ecs/erpnext-backend \
    --filter-pattern "Memory" \
    --start-time $(date -d '1 day ago' +%s)000
```

## 📚 Additional Resources

- [Amazon ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/userguide/AWS_Fargate.html)
- [Amazon RDS Documentation](https://docs.aws.amazon.com/rds/)
- [Amazon MemoryDB Documentation](https://docs.aws.amazon.com/memorydb/)
- [Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

## ➡️ Next Steps

1. **Production Hardening**: Follow `03-production-managed-setup.md`
2. **Monitoring Setup**: Configure detailed CloudWatch monitoring
3. **CI/CD Pipeline**: Set up automated deployments
4. **Security**: Implement WAF and additional security measures

---

**⚠️ Important**: This deployment uses managed services that incur continuous costs. Monitor your usage and optimize resource allocation based on actual requirements.