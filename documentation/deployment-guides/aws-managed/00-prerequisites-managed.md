# AWS Prerequisites for ERPNext with Managed Services

## Overview

This guide covers the prerequisites and initial setup required for deploying ERPNext on Amazon Web Services (AWS) using managed database services: Amazon RDS for MySQL and Amazon MemoryDB for Redis. This approach provides better reliability, security, and operational efficiency compared to self-hosted databases.

## 🔧 Required Tools

### 1. AWS CLI
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# Enter your Access Key ID, Secret Access Key, Default region, and output format
```

### 2. kubectl (Kubernetes CLI) - For EKS Option
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### 3. eksctl (EKS CLI) - For EKS Option
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Verify installation
eksctl version
```

### 4. Docker (for local testing and ECS)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Enable Docker BuildKit
export DOCKER_BUILDKIT=1
```

### 5. AWS ECS CLI - For ECS Option
```bash
# Install ECS CLI
sudo curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest
sudo chmod +x /usr/local/bin/ecs-cli

# Verify installation
ecs-cli --version
```

### 6. Helm (for EKS Kubernetes package management)
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## 🏗️ AWS Account Setup

### 1. Create or Configure AWS Account
```bash
# Verify AWS account and permissions
aws sts get-caller-identity

# Set default region
export AWS_DEFAULT_REGION=us-east-1
aws configure set default.region us-east-1

# Verify configuration
aws configure list
```

### 2. Enable Required AWS Services
```bash
# Verify access to required services
aws ec2 describe-regions --output table
aws rds describe-db-instances --output table
aws elasticache describe-cache-clusters --output table
aws ecs list-clusters --output table
aws eks list-clusters --output table
```

### 3. Create IAM Policies and Roles
```bash
# Create IAM policy for ERPNext managed services
cat > erpnext-managed-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "elasticache:*",
                "ecs:*",
                "eks:*",
                "ec2:*",
                "iam:PassRole",
                "logs:*",
                "cloudwatch:*",
                "secretsmanager:*",
                "ssm:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create the policy
aws iam create-policy \
    --policy-name ERPNextManagedPolicy \
    --policy-document file://erpnext-managed-policy.json

# Create service role for ECS tasks
cat > ecs-task-role-trust.json <<EOF
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
    --role-name ERPNextECSTaskRole \
    --assume-role-policy-document file://ecs-task-role-trust.json

# Attach policies to ECS task role
aws iam attach-role-policy \
    --role-name ERPNextECSTaskRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
    --role-name ERPNextECSTaskRole \
    --policy-arn $(aws iam list-policies --query "Policies[?PolicyName=='ERPNextManagedPolicy'].Arn" --output text)
```

## 🔐 Security Setup

### 1. VPC and Networking Configuration
```bash
# Create VPC for ERPNext deployment
aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=erpnext-vpc}]'

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=erpnext-vpc" \
    --query "Vpcs[0].VpcId" --output text)

# Create Internet Gateway
aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=erpnext-igw}]'

IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=erpnext-igw" \
    --query "InternetGateways[0].InternetGatewayId" --output text)

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID

# Create subnets
# Public subnet for load balancers
aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=erpnext-public-subnet-1a}]'

aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=erpnext-public-subnet-1b}]'

# Private subnets for application
aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.10.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=erpnext-private-subnet-1a}]'

aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.11.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=erpnext-private-subnet-1b}]'

# Database subnets
aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.20.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=erpnext-db-subnet-1a}]'

aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.21.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=erpnext-db-subnet-1b}]'
```

### 2. Route Tables and NAT Gateway
```bash
# Get subnet IDs
PUBLIC_SUBNET_1A=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-public-subnet-1a" \
    --query "Subnets[0].SubnetId" --output text)

PUBLIC_SUBNET_1B=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-public-subnet-1b" \
    --query "Subnets[0].SubnetId" --output text)

PRIVATE_SUBNET_1A=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-private-subnet-1a" \
    --query "Subnets[0].SubnetId" --output text)

PRIVATE_SUBNET_1B=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-private-subnet-1b" \
    --query "Subnets[0].SubnetId" --output text)

# Create NAT Gateway
aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=erpnext-nat-eip}]'

NAT_EIP=$(aws ec2 describe-addresses \
    --filters "Name=tag:Name,Values=erpnext-nat-eip" \
    --query "Addresses[0].AllocationId" --output text)

aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1A \
    --allocation-id $NAT_EIP \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=erpnext-nat}]'

NAT_ID=$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=erpnext-nat" \
    --query "NatGateways[0].NatGatewayId" --output text)

# Create route tables
# Public route table
aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=erpnext-public-rt}]'

PUBLIC_RT=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=erpnext-public-rt" \
    --query "RouteTables[0].RouteTableId" --output text)

# Private route table
aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=erpnext-private-rt}]'

PRIVATE_RT=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=erpnext-private-rt" \
    --query "RouteTables[0].RouteTableId" --output text)

# Add routes
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

aws ec2 create-route \
    --route-table-id $PRIVATE_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_ID

# Associate subnets with route tables
aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_1A \
    --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_1B \
    --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_1A \
    --route-table-id $PRIVATE_RT

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_1B \
    --route-table-id $PRIVATE_RT
```

### 3. Security Groups
```bash
# Create security group for ALB
aws ec2 create-security-group \
    --group-name erpnext-alb-sg \
    --description "Security group for ERPNext Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=erpnext-alb-sg}]'

ALB_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=erpnext-alb-sg" \
    --query "SecurityGroups[0].GroupId" --output text)

# Create security group for application
aws ec2 create-security-group \
    --group-name erpnext-app-sg \
    --description "Security group for ERPNext Application" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=erpnext-app-sg}]'

APP_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=erpnext-app-sg" \
    --query "SecurityGroups[0].GroupId" --output text)

# Create security group for database
aws ec2 create-security-group \
    --group-name erpnext-db-sg \
    --description "Security group for ERPNext Database" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=erpnext-db-sg}]'

DB_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=erpnext-db-sg" \
    --query "SecurityGroups[0].GroupId" --output text)

# Configure security group rules
# ALB security group
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Application security group
aws ec2 authorize-security-group-ingress \
    --group-id $APP_SG \
    --protocol tcp \
    --port 8000 \
    --source-group $ALB_SG

aws ec2 authorize-security-group-ingress \
    --group-id $APP_SG \
    --protocol tcp \
    --port 9000 \
    --source-group $ALB_SG

# Database security group
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 3306 \
    --source-group $APP_SG

aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 6379 \
    --source-group $APP_SG
```

## 💾 Managed Database Services Setup

### 1. RDS MySQL Instance
```bash
# Create DB subnet group
DB_SUBNET_1A=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-db-subnet-1a" \
    --query "Subnets[0].SubnetId" --output text)

DB_SUBNET_1B=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=erpnext-db-subnet-1b" \
    --query "Subnets[0].SubnetId" --output text)

aws rds create-db-subnet-group \
    --db-subnet-group-name erpnext-db-subnet-group \
    --db-subnet-group-description "Subnet group for ERPNext database" \
    --subnet-ids $DB_SUBNET_1A $DB_SUBNET_1B \
    --tags Key=Name,Value=erpnext-db-subnet-group

# Create RDS MySQL instance
aws rds create-db-instance \
    --db-instance-identifier erpnext-db \
    --db-instance-class db.t3.medium \
    --engine mysql \
    --engine-version 8.0.35 \
    --master-username admin \
    --master-user-password YourSecureDBPassword123! \
    --allocated-storage 100 \
    --storage-type gp3 \
    --storage-encrypted \
    --vpc-security-group-ids $DB_SG \
    --db-subnet-group-name erpnext-db-subnet-group \
    --backup-retention-period 7 \
    --backup-window 03:00-04:00 \
    --maintenance-window sun:04:00-sun:05:00 \
    --auto-minor-version-upgrade \
    --deletion-protection \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags Key=Name,Value=erpnext-db

# Wait for instance to be available
aws rds wait db-instance-available --db-instance-identifier erpnext-db

# Create ERPNext database
aws rds create-db-instance \
    --db-instance-identifier erpnext-db \
    --allocated-storage 100 \
    --db-instance-class db.t3.medium \
    --engine mysql \
    --master-username admin \
    --master-user-password YourSecureDBPassword123! \
    --vpc-security-group-ids $DB_SG \
    --db-subnet-group-name erpnext-db-subnet-group
```

### 2. MemoryDB for Redis Instance
```bash
# Create MemoryDB subnet group
aws memorydb create-subnet-group \
    --subnet-group-name erpnext-redis-subnet-group \
    --description "Subnet group for ERPNext Redis" \
    --subnet-ids $DB_SUBNET_1A $DB_SUBNET_1B \
    --tags Key=Name,Value=erpnext-redis-subnet-group

# Create MemoryDB user
aws memorydb create-user \
    --user-name erpnext-redis-user \
    --authentication-mode Type=password,Passwords=YourSecureRedisPassword123! \
    --access-string "on ~* &* +@all" \
    --tags Key=Name,Value=erpnext-redis-user

# Create MemoryDB ACL
aws memorydb create-acl \
    --acl-name erpnext-redis-acl \
    --user-names erpnext-redis-user \
    --tags Key=Name,Value=erpnext-redis-acl

# Create MemoryDB cluster
aws memorydb create-cluster \
    --cluster-name erpnext-redis \
    --node-type db.t4g.small \
    --engine-version 6.2 \
    --num-shards 1 \
    --num-replicas-per-shard 1 \
    --acl-name erpnext-redis-acl \
    --subnet-group-name erpnext-redis-subnet-group \
    --security-group-ids $DB_SG \
    --maintenance-window sun:05:00-sun:06:00 \
    --sns-topic-arn arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-notifications \
    --tls-enabled \
    --tags Key=Name,Value=erpnext-redis

# Wait for cluster to be available
aws memorydb describe-clusters \
    --cluster-name erpnext-redis \
    --query "Clusters[0].Status" --output text
```

### 3. AWS Systems Manager Parameter Store for Configuration
```bash
# Store database configuration
aws ssm put-parameter \
    --name "/erpnext/database/host" \
    --value $(aws rds describe-db-instances \
        --db-instance-identifier erpnext-db \
        --query "DBInstances[0].Endpoint.Address" --output text) \
    --type "String" \
    --description "ERPNext Database Host"

aws ssm put-parameter \
    --name "/erpnext/database/port" \
    --value "3306" \
    --type "String" \
    --description "ERPNext Database Port"

aws ssm put-parameter \
    --name "/erpnext/database/name" \
    --value "erpnext" \
    --type "String" \
    --description "ERPNext Database Name"

aws ssm put-parameter \
    --name "/erpnext/database/username" \
    --value "admin" \
    --type "String" \
    --description "ERPNext Database Username"

# Store Redis configuration
aws ssm put-parameter \
    --name "/erpnext/redis/host" \
    --value $(aws memorydb describe-clusters \
        --cluster-name erpnext-redis \
        --query "Clusters[0].ClusterEndpoint.Address" --output text) \
    --type "String" \
    --description "ERPNext Redis Host"

aws ssm put-parameter \
    --name "/erpnext/redis/port" \
    --value "6379" \
    --type "String" \
    --description "ERPNext Redis Port"
```

## 🔑 AWS Secrets Manager for Sensitive Data
```bash
# Store database password
aws secretsmanager create-secret \
    --name "erpnext/database/password" \
    --description "ERPNext Database Password" \
    --secret-string "YourSecureDBPassword123!" \
    --tags '[{"Key":"Application","Value":"ERPNext"},{"Key":"Environment","Value":"Production"}]'

# Store Redis password
aws secretsmanager create-secret \
    --name "erpnext/redis/password" \
    --description "ERPNext Redis Password" \
    --secret-string "YourSecureRedisPassword123!" \
    --tags '[{"Key":"Application","Value":"ERPNext"},{"Key":"Environment","Value":"Production"}]'

# Store ERPNext admin password
aws secretsmanager create-secret \
    --name "erpnext/admin/password" \
    --description "ERPNext Admin Password" \
    --secret-string "YourSecureAdminPassword123!" \
    --tags '[{"Key":"Application","Value":"ERPNext"},{"Key":"Environment","Value":"Production"}]'

# Store API credentials
aws secretsmanager create-secret \
    --name "erpnext/api/credentials" \
    --description "ERPNext API Credentials" \
    --secret-string '{"api_key":"your-api-key-here","api_secret":"your-api-secret-here"}' \
    --tags '[{"Key":"Application","Value":"ERPNext"},{"Key":"Environment","Value":"Production"}]'
```

## 📊 CloudWatch and Monitoring Setup
```bash
# Create CloudWatch log groups
aws logs create-log-group \
    --log-group-name /aws/ecs/erpnext-backend \
    --retention-in-days 7

aws logs create-log-group \
    --log-group-name /aws/ecs/erpnext-frontend \
    --retention-in-days 7

aws logs create-log-group \
    --log-group-name /aws/ecs/erpnext-worker \
    --retention-in-days 7

# Create SNS topic for alerts
aws sns create-topic \
    --name erpnext-alerts \
    --tags Key=Application,Value=ERPNext

# Subscribe email to alerts (replace with your email)
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-alerts \
    --protocol email \
    --notification-endpoint your-email@yourdomain.com
```

## 🔍 Verification Checklist

Before proceeding to deployment, verify:

```bash
# Check AWS credentials and region
aws sts get-caller-identity
aws configure get region

# Verify VPC and subnets
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erpnext-vpc"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"

# Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID"

# Verify RDS instance
aws rds describe-db-instances --db-instance-identifier erpnext-db

# Check MemoryDB cluster
aws memorydb describe-clusters --cluster-name erpnext-redis

# Verify secrets
aws secretsmanager list-secrets --filters Key=tag-key,Values=Application Key=tag-value,Values=ERPNext

# Check IAM roles
aws iam get-role --role-name ERPNextECSTaskRole

# Verify CloudWatch log groups
aws logs describe-log-groups --log-group-name-prefix /aws/ecs/erpnext
```

## 💡 Cost Optimization for Managed Services

### 1. RDS Optimization
```bash
# Use appropriate instance types
# Development: db.t3.micro or db.t3.small
# Production: db.t3.medium or larger

# Enable storage autoscaling
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --max-allocated-storage 1000 \
    --apply-immediately

# Use Reserved Instances for production (1-3 year terms)
aws rds describe-reserved-db-instances-offerings \
    --db-instance-class db.t3.medium \
    --engine mysql
```

### 2. MemoryDB Optimization
```bash
# Right-size cluster based on memory usage
# Start with db.t4g.small and scale based on usage
# Monitor memory utilization and adjust

# Use Multi-AZ only for production
# Single-AZ for development/testing environments
```

### 3. Network Cost Optimization
```bash
# Use same AZ for services to minimize data transfer costs
# Monitor VPC Flow Logs for inter-AZ traffic
# Consider VPC endpoints for AWS services if needed
```

## 🚨 Security Best Practices for Managed Services

### 1. Network Security
- **VPC isolation**: All managed services use private subnets
- **Security groups**: Restrictive access between tiers
- **No public access**: Database and Redis not accessible from internet

### 2. Access Control
```bash
# Enable RDS IAM database authentication
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --enable-iam-database-authentication \
    --apply-immediately

# Create IAM database user
aws rds create-db-instance-read-replica \
    --db-instance-identifier erpnext-db-read-replica \
    --source-db-instance-identifier erpnext-db \
    --db-instance-class db.t3.small
```

### 3. Encryption
- **Encryption at rest**: Enabled by default for both services
- **Encryption in transit**: SSL/TLS enforced
- **Secrets management**: AWS Secrets Manager for credentials

## 📚 Additional Resources

- [Amazon RDS Documentation](https://docs.aws.amazon.com/rds/)
- [Amazon MemoryDB Documentation](https://docs.aws.amazon.com/memorydb/)
- [Amazon ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)

## ➡️ Next Steps

After completing prerequisites:
1. **ECS with Managed Services**: Follow `01-ecs-managed-deployment.md`
2. **EKS with Managed Services**: Follow `02-eks-managed-deployment.md`
3. **Production Hardening**: See `03-production-managed-setup.md`

---

**⚠️ Important Notes**:
- Managed services incur continuous costs even when not in use
- Plan your backup and disaster recovery strategy
- Monitor costs regularly using AWS Cost Explorer
- Keep track of all resources created for billing purposes
- Use AWS Config for compliance and governance