# ERPNext Production Setup with AWS Managed Services

## Overview

This guide covers production-ready configurations, security hardening, monitoring, backup strategies, and operational best practices for ERPNext using AWS managed services (Amazon RDS, MemoryDB, ECS/EKS). This setup provides enterprise-grade reliability, security, and operational efficiency.

## 🔐 Enhanced Security Configuration

### 1. AWS WAF (Web Application Firewall)
```bash
# Create WAF Web ACL for ALB protection
cat > waf-web-acl.json <<EOF
{
    "Name": "ERPNextWAF",
    "Scope": "REGIONAL",
    "DefaultAction": {
        "Allow": {}
    },
    "Rules": [
        {
            "Name": "AWSManagedRulesCommonRuleSet",
            "Priority": 1,
            "OverrideAction": {
                "None": {}
            },
            "Statement": {
                "ManagedRuleGroupStatement": {
                    "VendorName": "AWS",
                    "Name": "AWSManagedRulesCommonRuleSet"
                }
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "CommonRuleSetMetric"
            }
        },
        {
            "Name": "AWSManagedRulesKnownBadInputsRuleSet",
            "Priority": 2,
            "OverrideAction": {
                "None": {}
            },
            "Statement": {
                "ManagedRuleGroupStatement": {
                    "VendorName": "AWS",
                    "Name": "AWSManagedRulesKnownBadInputsRuleSet"
                }
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "KnownBadInputsMetric"
            }
        },
        {
            "Name": "AWSManagedRulesSQLiRuleSet",
            "Priority": 3,
            "OverrideAction": {
                "None": {}
            },
            "Statement": {
                "ManagedRuleGroupStatement": {
                    "VendorName": "AWS",
                    "Name": "AWSManagedRulesSQLiRuleSet"
                }
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "SQLiRuleSetMetric"
            }
        },
        {
            "Name": "RateLimitRule",
            "Priority": 4,
            "Action": {
                "Block": {}
            },
            "Statement": {
                "RateBasedStatement": {
                    "Limit": 1000,
                    "AggregateKeyType": "IP"
                }
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "RateLimitMetric"
            }
        }
    ],
    "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "ERPNextWAFMetric"
    }
}
EOF

# Create the WAF Web ACL
aws wafv2 create-web-acl \
    --scope REGIONAL \
    --region us-east-1 \
    --cli-input-json file://waf-web-acl.json

# Get WAF ARN
WAF_ARN=$(aws wafv2 list-web-acls --scope REGIONAL --region us-east-1 --query "WebACLs[?Name=='ERPNextWAF'].ARN" --output text)

# Associate WAF with ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --names erpnext-alb --query "LoadBalancers[0].LoadBalancerArn" --output text)

aws wafv2 associate-web-acl \
    --web-acl-arn $WAF_ARN \
    --resource-arn $ALB_ARN
```

### 2. Enhanced RDS Security
```bash
# Enable RDS Performance Insights
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --apply-immediately

# Enable enhanced monitoring
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --monitoring-interval 60 \
    --monitoring-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/rds-monitoring-role \
    --apply-immediately

# Create monitoring role
cat > rds-monitoring-role-trust.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "monitoring.rds.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name rds-monitoring-role \
    --assume-role-policy-document file://rds-monitoring-role-trust.json

aws iam attach-role-policy \
    --role-name rds-monitoring-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole

# Enable RDS encryption for backups
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --backup-retention-period 30 \
    --backup-window 03:00-04:00 \
    --apply-immediately

# Create read replica for disaster recovery
aws rds create-db-instance-read-replica \
    --db-instance-identifier erpnext-db-read-replica \
    --source-db-instance-identifier erpnext-db \
    --db-instance-class db.t3.medium \
    --publicly-accessible false \
    --storage-encrypted \
    --auto-minor-version-upgrade \
    --tags Key=Name,Value=erpnext-db-read-replica Key=Purpose,Value=disaster-recovery
```

### 3. MemoryDB Security Enhancements
```bash
# Update MemoryDB with encryption in transit
aws memorydb update-cluster \
    --cluster-name erpnext-redis \
    --description "ERPNext Redis with enhanced security" \
    --maintenance-window sun:05:00-sun:06:00 \
    --sns-topic-arn arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-security-alerts

# Create security alerts SNS topic
aws sns create-topic \
    --name erpnext-security-alerts \
    --tags Key=Application,Value=ERPNext Key=Purpose,Value=security-monitoring

# Subscribe to security alerts
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-security-alerts \
    --protocol email \
    --notification-endpoint security@yourdomain.com
```

### 4. VPC Security Hardening
```bash
# Create VPC Flow Logs for network monitoring
aws logs create-log-group \
    --log-group-name /aws/vpc/flowlogs \
    --retention-in-days 30

# Create IAM role for VPC Flow Logs
cat > vpc-flowlogs-role-trust.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "vpc-flow-logs.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name VPCFlowLogsRole \
    --assume-role-policy-document file://vpc-flowlogs-role-trust.json

cat > vpc-flowlogs-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name VPCFlowLogsPolicy \
    --policy-document file://vpc-flowlogs-policy.json

aws iam attach-role-policy \
    --role-name VPCFlowLogsRole \
    --policy-arn $(aws iam list-policies --query "Policies[?PolicyName=='VPCFlowLogsPolicy'].Arn" --output text)

# Enable VPC Flow Logs
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erpnext-vpc" --query "Vpcs[0].VpcId" --output text)

aws ec2 create-flow-logs \
    --resource-type VPC \
    --resource-ids $VPC_ID \
    --traffic-type ALL \
    --log-destination-type cloud-watch-logs \
    --log-group-name /aws/vpc/flowlogs \
    --deliver-logs-permission-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/VPCFlowLogsRole \
    --tags Key=Name,Value=erpnext-vpc-flowlogs
```

## 📊 Advanced Monitoring and Observability

### 1. CloudWatch Custom Metrics and Dashboards
```bash
# Create custom CloudWatch dashboard
cat > erpnext-dashboard.json <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "erpnext-db" ],
                    [ ".", "DatabaseConnections", ".", "." ],
                    [ ".", "ReadLatency", ".", "." ],
                    [ ".", "WriteLatency", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "RDS Performance Metrics",
                "period": 300
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/MemoryDB", "CPUUtilization", "ClusterName", "erpnext-redis" ],
                    [ ".", "DatabaseMemoryUsagePercentage", ".", "." ],
                    [ ".", "NetworkBytesIn", ".", "." ],
                    [ ".", "NetworkBytesOut", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "MemoryDB Performance Metrics",
                "period": 300
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ECS", "CPUUtilization", "ServiceName", "erpnext-backend", "ClusterName", "erpnext-cluster" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ],
                    [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/erpnext-alb/1234567890abcdef" ],
                    [ ".", "RequestCount", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "Application Performance Metrics",
                "period": 300
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "query": "SOURCE '/aws/ecs/erpnext-backend'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                "region": "us-east-1",
                "title": "Recent Application Errors",
                "view": "table"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name ERPNextProduction \
    --dashboard-body file://erpnext-dashboard.json
```

### 2. CloudWatch Alarms for Critical Metrics
```bash
# RDS CPU Utilization Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ERPNext-RDS-High-CPU" \
    --alarm-description "RDS CPU utilization is too high" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-alerts \
    --dimensions Name=DBInstanceIdentifier,Value=erpnext-db

# RDS Connection Count Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ERPNext-RDS-High-Connections" \
    --alarm-description "RDS connection count is too high" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 150 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-alerts \
    --dimensions Name=DBInstanceIdentifier,Value=erpnext-db

# MemoryDB Memory Utilization Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ERPNext-Redis-High-Memory" \
    --alarm-description "MemoryDB memory utilization is too high" \
    --metric-name DatabaseMemoryUsagePercentage \
    --namespace AWS/MemoryDB \
    --statistic Average \
    --period 300 \
    --threshold 85 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-alerts \
    --dimensions Name=ClusterName,Value=erpnext-redis

# ALB Response Time Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ERPNext-ALB-High-Response-Time" \
    --alarm-description "ALB response time is too high" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 2.0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 3 \
    --alarm-actions arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-alerts \
    --dimensions Name=LoadBalancer,Value=app/erpnext-alb/$(echo $ALB_ARN | cut -d'/' -f2-)

# ECS Service CPU Utilization Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ERPNext-ECS-High-CPU" \
    --alarm-description "ECS service CPU utilization is too high" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):erpnext-alerts \
    --dimensions Name=ServiceName,Value=erpnext-backend Name=ClusterName,Value=erpnext-cluster
```

### 3. AWS X-Ray for Distributed Tracing
```bash
# Enable X-Ray tracing for ECS tasks (add to task definition)
cat > xray-daemon-container.json <<EOF
{
    "name": "xray-daemon",
    "image": "amazon/aws-xray-daemon:latest",
    "essential": false,
    "portMappings": [
        {
            "containerPort": 2000,
            "protocol": "udp"
        }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "/aws/ecs/erpnext-xray",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "xray"
        }
    }
}
EOF

# Create CloudWatch log group for X-Ray
aws logs create-log-group \
    --log-group-name /aws/ecs/erpnext-xray \
    --retention-in-days 7

# Update IAM task role to include X-Ray permissions
cat > xray-permissions.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:PutTraceSegments",
                "xray:PutTelemetryRecords"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name ERPNextXRayPolicy \
    --policy-document file://xray-permissions.json

aws iam attach-role-policy \
    --role-name ERPNextECSTaskRole \
    --policy-arn $(aws iam list-policies --query "Policies[?PolicyName=='ERPNextXRayPolicy'].Arn" --output text)
```

## 🗄️ Advanced Backup and Disaster Recovery

### 1. Multi-Region Backup Strategy
```bash
# Create cross-region backup bucket
aws s3 mb s3://erpnext-backups-dr-$(aws sts get-caller-identity --query Account --output text) --region us-west-2

# Enable versioning and encryption
aws s3api put-bucket-versioning \
    --bucket erpnext-backups-dr-$(aws sts get-caller-identity --query Account --output text) \
    --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
    --bucket erpnext-backups-dr-$(aws sts get-caller-identity --query Account --output text) \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Set up cross-region replication
cat > replication-config.json <<EOF
{
    "Role": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/S3ReplicationRole",
    "Rules": [
        {
            "ID": "ERPNextBackupReplication",
            "Status": "Enabled",
            "Priority": 1,
            "Filter": {
                "Prefix": "backups/"
            },
            "Destination": {
                "Bucket": "arn:aws:s3:::erpnext-backups-dr-$(aws sts get-caller-identity --query Account --output text)",
                "StorageClass": "STANDARD_IA"
            }
        }
    ]
}
EOF

# Create replication role
cat > s3-replication-role-trust.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "s3.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name S3ReplicationRole \
    --assume-role-policy-document file://s3-replication-role-trust.json

aws iam attach-role-policy \
    --role-name S3ReplicationRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSS3ReplicationServiceRolePolicy

# Apply replication configuration
aws s3api put-bucket-replication \
    --bucket erpnext-backups-$(aws sts get-caller-identity --query Account --output text) \
    --replication-configuration file://replication-config.json
```

### 2. Automated RDS Snapshot Management
```bash
# Create Lambda function for automated snapshot management
cat > snapshot-management.py <<'EOF'
import boto3
import json
from datetime import datetime, timedelta

def lambda_handler(event, context):
    rds = boto3.client('rds')
    
    # Create manual snapshot
    snapshot_id = f"erpnext-manual-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    
    try:
        response = rds.create_db_snapshot(
            DBSnapshotIdentifier=snapshot_id,
            DBInstanceIdentifier='erpnext-db',
            Tags=[
                {'Key': 'Application', 'Value': 'ERPNext'},
                {'Key': 'Type', 'Value': 'manual'},
                {'Key': 'CreatedBy', 'Value': 'lambda-automation'}
            ]
        )
        
        # Delete old manual snapshots (keep last 7)
        snapshots = rds.describe_db_snapshots(
            DBInstanceIdentifier='erpnext-db',
            SnapshotType='manual'
        )
        
        manual_snapshots = [s for s in snapshots['DBSnapshots'] 
                          if s['DBSnapshotIdentifier'].startswith('erpnext-manual-')]
        
        # Sort by creation time and delete old ones
        manual_snapshots.sort(key=lambda x: x['SnapshotCreateTime'])
        
        if len(manual_snapshots) > 7:
            for snapshot in manual_snapshots[:-7]:
                rds.delete_db_snapshot(
                    DBSnapshotIdentifier=snapshot['DBSnapshotIdentifier']
                )
                print(f"Deleted old snapshot: {snapshot['DBSnapshotIdentifier']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Snapshot created: {snapshot_id}')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error creating snapshot: {str(e)}')
        }
EOF

# Create Lambda deployment package
zip snapshot-management.zip snapshot-management.py

# Create Lambda function
aws lambda create-function \
    --function-name erpnext-snapshot-management \
    --runtime python3.9 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextSnapshotLambdaRole \
    --handler snapshot-management.lambda_handler \
    --zip-file fileb://snapshot-management.zip \
    --description "Automated RDS snapshot management for ERPNext" \
    --timeout 300 \
    --tags Application=ERPNext,Purpose=backup-automation

# Create EventBridge rule for daily execution
aws events put-rule \
    --name erpnext-daily-snapshot \
    --schedule-expression "cron(0 6 * * ? *)" \
    --description "Daily ERPNext database snapshot" \
    --state ENABLED

# Add Lambda permission for EventBridge
aws lambda add-permission \
    --function-name erpnext-snapshot-management \
    --statement-id allow-eventbridge \
    --action lambda:InvokeFunction \
    --principal events.amazonaws.com \
    --source-arn arn:aws:events:us-east-1:$(aws sts get-caller-identity --query Account --output text):rule/erpnext-daily-snapshot

# Create target for EventBridge rule
aws events put-targets \
    --rule erpnext-daily-snapshot \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:$(aws sts get-caller-identity --query Account --output text):function:erpnext-snapshot-management"
```

### 3. Disaster Recovery Testing Automation
```bash
# Create Lambda function for DR testing
cat > dr-test.py <<'EOF'
import boto3
import json
from datetime import datetime

def lambda_handler(event, context):
    rds = boto3.client('rds')
    ecs = boto3.client('ecs')
    
    try:
        # Get latest snapshot
        snapshots = rds.describe_db_snapshots(
            DBInstanceIdentifier='erpnext-db',
            SnapshotType='automated'
        )
        
        latest_snapshot = max(snapshots['DBSnapshots'], 
                            key=lambda x: x['SnapshotCreateTime'])
        
        # Create test instance from snapshot
        test_instance_id = f"erpnext-dr-test-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        response = rds.restore_db_instance_from_db_snapshot(
            DBInstanceIdentifier=test_instance_id,
            DBSnapshotIdentifier=latest_snapshot['DBSnapshotIdentifier'],
            DBInstanceClass='db.t3.small',
            VpcSecurityGroupIds=[
                'sg-xxxxxxxxx'  # Replace with your security group
            ],
            DBSubnetGroupName='erpnext-db-subnet-group',
            Tags=[
                {'Key': 'Application', 'Value': 'ERPNext'},
                {'Key': 'Purpose', 'Value': 'DR-Test'},
                {'Key': 'DeleteAfter', 'Value': datetime.now().strftime('%Y-%m-%d')}
            ]
        )
        
        # Schedule cleanup in 4 hours
        # Implementation depends on your cleanup strategy
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'DR test instance created: {test_instance_id}')
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'DR test failed: {str(e)}')
        }
EOF

# Create DR test Lambda function
zip dr-test.zip dr-test.py

aws lambda create-function \
    --function-name erpnext-dr-test \
    --runtime python3.9 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextDRTestLambdaRole \
    --handler dr-test.lambda_handler \
    --zip-file fileb://dr-test.zip \
    --description "Automated DR testing for ERPNext" \
    --timeout 300

# Schedule monthly DR tests
aws events put-rule \
    --name erpnext-monthly-dr-test \
    --schedule-expression "cron(0 10 1 * ? *)" \
    --description "Monthly ERPNext DR test" \
    --state ENABLED

aws events put-targets \
    --rule erpnext-monthly-dr-test \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:$(aws sts get-caller-identity --query Account --output text):function:erpnext-dr-test"
```

## 🚀 Performance Optimization

### 1. RDS Performance Tuning
```bash
# Create custom parameter group for MySQL optimization
aws rds create-db-parameter-group \
    --db-parameter-group-name erpnext-mysql8-params \
    --db-parameter-group-family mysql8.0 \
    --description "Optimized parameters for ERPNext MySQL 8.0"

# Set optimized parameters
aws rds modify-db-parameter-group \
    --db-parameter-group-name erpnext-mysql8-params \
    --parameters \
        "ParameterName=innodb_buffer_pool_size,ParameterValue={DBInstanceClassMemory*3/4},ApplyMethod=pending-reboot" \
        "ParameterName=innodb_log_file_size,ParameterValue=268435456,ApplyMethod=pending-reboot" \
        "ParameterName=innodb_flush_log_at_trx_commit,ParameterValue=2,ApplyMethod=immediate" \
        "ParameterName=innodb_io_capacity,ParameterValue=2000,ApplyMethod=immediate" \
        "ParameterName=innodb_read_io_threads,ParameterValue=8,ApplyMethod=pending-reboot" \
        "ParameterName=innodb_write_io_threads,ParameterValue=8,ApplyMethod=pending-reboot" \
        "ParameterName=max_connections,ParameterValue=200,ApplyMethod=immediate" \
        "ParameterName=query_cache_size,ParameterValue=67108864,ApplyMethod=pending-reboot" \
        "ParameterName=query_cache_type,ParameterValue=1,ApplyMethod=pending-reboot" \
        "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate" \
        "ParameterName=long_query_time,ParameterValue=2,ApplyMethod=immediate"

# Apply parameter group to RDS instance
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --db-parameter-group-name erpnext-mysql8-params \
    --apply-immediately

# Upgrade to larger instance class for production
aws rds modify-db-instance \
    --db-instance-identifier erpnext-db \
    --db-instance-class db.r5.xlarge \
    --allocated-storage 500 \
    --storage-type gp3 \
    --iops 3000 \
    --apply-immediately
```

### 2. MemoryDB Performance Optimization
```bash
# Scale MemoryDB cluster for production workload
aws memorydb update-cluster \
    --cluster-name erpnext-redis \
    --node-type db.r6g.large \
    --num-shards 2 \
    --num-replicas-per-shard 1

# Configure Redis parameters for ERPNext
aws memorydb create-parameter-group \
    --parameter-group-name erpnext-redis-params \
    --family memorydb_redis6 \
    --description "Optimized parameters for ERPNext Redis"

aws memorydb update-parameter-group \
    --parameter-group-name erpnext-redis-params \
    --parameter-name-values \
        "ParameterName=maxmemory-policy,ParameterValue=allkeys-lru" \
        "ParameterName=timeout,ParameterValue=300" \
        "ParameterName=tcp-keepalive,ParameterValue=60" \
        "ParameterName=maxclients,ParameterValue=20000"

# Apply parameter group to cluster
aws memorydb update-cluster \
    --cluster-name erpnext-redis \
    --parameter-group-name erpnext-redis-params
```

### 3. ECS/EKS Performance Optimization
```bash
# For ECS: Update task definitions with performance optimizations
cat > erpnext-backend-optimized-task.json <<EOF
{
    "family": "erpnext-backend-optimized",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "2048",
    "memory": "4096",
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
                    "name": "WORKERS",
                    "value": "4"
                },
                {
                    "name": "THREADS",
                    "value": "2"
                },
                {
                    "name": "MAX_REQUESTS",
                    "value": "1000"
                },
                {
                    "name": "MAX_REQUESTS_JITTER",
                    "value": "100"
                },
                {
                    "name": "WORKER_TIMEOUT",
                    "value": "120"
                },
                {
                    "name": "KEEPALIVE",
                    "value": "5"
                }
            ],
            "ulimits": [
                {
                    "name": "nofile",
                    "softLimit": 65536,
                    "hardLimit": 65536
                }
            ]
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://erpnext-backend-optimized-task.json
```

## 🔧 Advanced Operational Procedures

### 1. Blue-Green Deployment with CodeDeploy
```bash
# Create CodeDeploy application
aws deploy create-application \
    --application-name ERPNextECS \
    --compute-platform ECS

# Create deployment group
aws deploy create-deployment-group \
    --application-name ERPNextECS \
    --deployment-group-name ERPNextBlueGreen \
    --service-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodeDeployServiceRole \
    --deployment-config-name CodeDeployDefault.ECSAllAtOnceBlueGreen \
    --ecs-services clusterName=erpnext-cluster,serviceName=erpnext-backend \
    --load-balancer-info targetGroupInfoList='[{name=erpnext-backend-tg}]' \
    --blue-green-deployment-configuration '{
        "terminateBlueInstancesOnDeploymentSuccess": {
            "action": "TERMINATE",
            "terminationWaitTimeInMinutes": 5
        },
        "deploymentReadyOption": {
            "actionOnTimeout": "CONTINUE_DEPLOYMENT"
        },
        "greenFleetProvisioningOption": {
            "action": "COPY_AUTO_SCALING_GROUP"
        }
    }'

# Create deployment script
cat > deploy-blue-green.sh <<'EOF'
#!/bin/bash
set -e

APPLICATION_NAME="ERPNextECS"
DEPLOYMENT_GROUP="ERPNextBlueGreen"
NEW_IMAGE="$1"

if [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <new-image-uri>"
    exit 1
fi

echo "Starting blue-green deployment with image: $NEW_IMAGE"

# Create new task definition with updated image
NEW_TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition erpnext-backend \
    --query 'taskDefinition' | \
    jq --arg IMAGE "$NEW_IMAGE" '.containerDefinitions[0].image = $IMAGE' | \
    jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')

# Register new task definition
NEW_REVISION=$(echo $NEW_TASK_DEF | aws ecs register-task-definition --cli-input-json file:///dev/stdin --query 'taskDefinition.revision')

echo "New task definition revision: $NEW_REVISION"

# Create CodeDeploy deployment
aws deploy create-deployment \
    --application-name $APPLICATION_NAME \
    --deployment-group-name $DEPLOYMENT_GROUP \
    --revision '{
        "revisionType": "S3",
        "s3Location": {
            "bucket": "your-deployment-bucket",
            "key": "appspec.yaml",
            "bundleType": "YAML"
        }
    }'

echo "Blue-green deployment initiated"
EOF

chmod +x deploy-blue-green.sh
```

### 2. Canary Deployment for EKS
```bash
# Install Argo Rollouts for advanced deployment strategies
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Create Rollout resource for canary deployments
cat > erpnext-rollout.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: erpnext-backend-rollout
  namespace: erpnext
spec:
  replicas: 5
  strategy:
    canary:
      canaryService: erpnext-backend-canary
      stableService: erpnext-backend
      trafficRouting:
        alb:
          ingress: erpnext-ingress
          servicePort: 8000
      steps:
      - setWeight: 20
      - pause: {duration: 10m}
      - setWeight: 40
      - pause: {duration: 10m}
      - setWeight: 60
      - pause: {duration: 10m}
      - setWeight: 80
      - pause: {duration: 10m}
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: erpnext-backend
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      serviceAccountName: erpnext-sa
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        ports:
        - containerPort: 8000
        - containerPort: 9000
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: erpnext
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 5m
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(
            nginx_ingress_controller_requests{service="{{args.service-name}}",status!~"5.*"}[2m]
          )) /
          sum(rate(
            nginx_ingress_controller_requests{service="{{args.service-name}}"}[2m]
          ))
EOF

kubectl apply -f erpnext-rollout.yaml
```

### 3. Automated Scaling Based on Custom Metrics
```bash
# Create Lambda function for custom scaling logic
cat > custom-scaler.py <<'EOF'
import boto3
import json
import os

def lambda_handler(event, context):
    cloudwatch = boto3.client('cloudwatch')
    ecs = boto3.client('ecs')
    
    cluster_name = os.environ['CLUSTER_NAME']
    service_name = os.environ['SERVICE_NAME']
    
    # Get queue depth from CloudWatch
    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/MemoryDB',
        MetricName='CommandLatency',
        Dimensions=[
            {
                'Name': 'ClusterName',
                'Value': 'erpnext-redis'
            },
            {
                'Name': 'Command',
                'Value': 'llen'
            }
        ],
        StartTime=datetime.utcnow() - timedelta(minutes=5),
        EndTime=datetime.utcnow(),
        Period=300,
        Statistics=['Average']
    )
    
    if response['Datapoints']:
        avg_latency = response['Datapoints'][-1]['Average']
        
        # Scale based on latency
        if avg_latency > 100:  # milliseconds
            target_count = min(10, int(avg_latency / 50))
        else:
            target_count = 2
        
        # Update ECS service
        ecs.update_service(
            cluster=cluster_name,
            service=service_name,
            desiredCount=target_count
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Scaled {service_name} to {target_count} tasks')
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps('No scaling action needed')
    }
EOF

# Deploy custom scaler
zip custom-scaler.zip custom-scaler.py

aws lambda create-function \
    --function-name erpnext-custom-scaler \
    --runtime python3.9 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ERPNextCustomScalerRole \
    --handler custom-scaler.lambda_handler \
    --zip-file fileb://custom-scaler.zip \
    --environment Variables='{CLUSTER_NAME=erpnext-cluster,SERVICE_NAME=erpnext-worker}' \
    --timeout 60

# Schedule every 5 minutes
aws events put-rule \
    --name erpnext-custom-scaling \
    --schedule-expression "rate(5 minutes)" \
    --state ENABLED

aws events put-targets \
    --rule erpnext-custom-scaling \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:$(aws sts get-caller-identity --query Account --output text):function:erpnext-custom-scaler"
```

## 🔍 Compliance and Governance

### 1. AWS Config for Compliance Monitoring
```bash
# Enable AWS Config
aws configservice put-configuration-recorder \
    --configuration-recorder name=default,roleARN=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/aws-config-role \
    --recording-group allSupported=true,includeGlobalResourceTypes=true

aws configservice put-delivery-channel \
    --delivery-channel name=default,s3BucketName=config-bucket-$(aws sts get-caller-identity --query Account --output text)

# Start configuration recorder
aws configservice start-configuration-recorder --configuration-recorder-name default

# Add compliance rules
aws configservice put-config-rule \
    --config-rule '{
        "ConfigRuleName": "rds-encryption-enabled",
        "Source": {
            "Owner": "AWS",
            "SourceIdentifier": "RDS_STORAGE_ENCRYPTED"
        }
    }'

aws configservice put-config-rule \
    --config-rule '{
        "ConfigRuleName": "efs-encrypted",
        "Source": {
            "Owner": "AWS",
            "SourceIdentifier": "EFS_ENCRYPTED_CHECK"
        }
    }'
```

### 2. Security Hub for Centralized Security Findings
```bash
# Enable Security Hub
aws securityhub enable-security-hub \
    --enable-default-standards

# Enable specific standards
aws securityhub batch-enable-standards \
    --standards-subscription-requests StandardsArn=arn:aws:securityhub:us-east-1::standard/aws-foundational-security-standard/v/1.0.0,StandardsArn=arn:aws:securityhub:us-east-1::standard/cis-aws-foundations-benchmark/v/1.2.0

# Create custom insights
aws securityhub create-insight \
    --name "ERPNext High Severity Findings" \
    --filters '{
        "ProductArn": [{"Value": "arn:aws:securityhub:us-east-1::product/aws/securityhub", "Comparison": "EQUALS"}],
        "SeverityLabel": [{"Value": "HIGH", "Comparison": "EQUALS"}, {"Value": "CRITICAL", "Comparison": "EQUALS"}],
        "ResourceTags": [{"Key": "Application", "Value": "ERPNext", "Comparison": "EQUALS"}]
    }' \
    --group-by-attribute "ResourceId"
```

### 3. AWS Systems Manager for Patch Management
```bash
# Create patch baseline for ECS instances
aws ssm create-patch-baseline \
    --name "ERPNext-Amazon-Linux-Baseline" \
    --operating-system AMAZON_LINUX_2 \
    --approval-rules '{
        "PatchRules": [
            {
                "PatchFilterGroup": {
                    "PatchFilters": [
                        {
                            "Key": "CLASSIFICATION",
                            "Values": ["Security", "Bugfix", "Critical"]
                        },
                        {
                            "Key": "SEVERITY",
                            "Values": ["Critical", "Important"]
                        }
                    ]
                },
                "ApproveAfterDays": 0,
                "EnableNonSecurity": false
            }
        ]
    }' \
    --description "Patch baseline for ERPNext infrastructure"

# Create maintenance window
aws ssm create-maintenance-window \
    --name "ERPNext-Maintenance-Window" \
    --schedule "cron(0 2 ? * SUN *)" \
    --duration 4 \
    --cutoff 1 \
    --allow-unassociated-targets \
    --description "Weekly maintenance window for ERPNext infrastructure"
```

## 📈 Advanced Performance Monitoring

### 1. Custom CloudWatch Metrics for Business KPIs
```bash
# Create custom metric for ERPNext-specific metrics
aws logs put-metric-filter \
    --log-group-name "/aws/ecs/erpnext-backend" \
    --filter-name "ERPNext-User-Logins" \
    --filter-pattern "[timestamp, request_id, level=\"INFO\", message=\"User*logged*in*\"]" \
    --metric-transformations \
        metricName=UserLogins,metricNamespace=ERPNext/Business,metricValue=1,defaultValue=0

aws logs put-metric-filter \
    --log-group-name "/aws/ecs/erpnext-backend" \
    --filter-name "ERPNext-Sales-Orders" \
    --filter-pattern "[timestamp, request_id, level=\"INFO\", message=\"*Sales Order*created*\"]" \
    --metric-transformations \
        metricName=SalesOrdersCreated,metricNamespace=ERPNext/Business,metricValue=1,defaultValue=0

aws logs put-metric-filter \
    --log-group-name "/aws/ecs/erpnext-backend" \
    --filter-name "ERPNext-Payment-Errors" \
    --filter-pattern "[timestamp, request_id, level=\"ERROR\", message=\"*payment*failed*\"]" \
    --metric-transformations \
        metricName=PaymentErrors,metricNamespace=ERPNext/Business,metricValue=1,defaultValue=0
```

### 2. Integration with Prometheus and Grafana (for EKS)
```bash
# Install kube-prometheus-stack using Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --values - <<EOF
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ebs-gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
  ingress:
    enabled: true
    hosts:
    - prometheus.yourdomain.com

grafana:
  adminPassword: YourSecureGrafanaPassword
  persistence:
    enabled: true
    storageClassName: ebs-gp3
    size: 10Gi
  ingress:
    enabled: true
    hosts:
    - grafana.yourdomain.com

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: ebs-gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
EOF

# Create ServiceMonitor for ERPNext metrics
cat > erpnext-servicemonitor.yaml <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: erpnext-backend
  namespace: monitoring
  labels:
    app: erpnext-backend
spec:
  selector:
    matchLabels:
      app: erpnext-backend
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
EOF

kubectl apply -f erpnext-servicemonitor.yaml
```

## 🧹 Maintenance and Lifecycle Management

### 1. Automated Security Updates
```bash
# Create Lambda function for automated security updates
cat > security-updater.py <<'EOF'
import boto3
import json

def lambda_handler(event, context):
    ecs = boto3.client('ecs')
    ecr = boto3.client('ecr')
    
    # Get latest image from ECR
    response = ecr.describe_images(
        repositoryName='erpnext/backend',
        imageIds=[{'imageTag': 'latest-security'}]
    )
    
    if response['imageDetails']:
        latest_image = f"{response['imageDetails'][0]['registryId']}.dkr.ecr.us-east-1.amazonaws.com/erpnext/backend:latest-security"
        
        # Update ECS service
        ecs.update_service(
            cluster='erpnext-cluster',
            service='erpnext-backend',
            forceNewDeployment=True,
            taskDefinition='erpnext-backend:LATEST'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('Security update deployed successfully')
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps('No security updates available')
    }
EOF

# Schedule weekly security updates
aws events put-rule \
    --name erpnext-security-updates \
    --schedule-expression "cron(0 4 ? * MON *)" \
    --description "Weekly security updates for ERPNext" \
    --state ENABLED
```

### 2. Resource Cleanup and Cost Optimization
```bash
# Create cleanup Lambda function
cat > resource-cleanup.py <<'EOF'
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    rds = boto3.client('rds')
    logs = boto3.client('logs')
    s3 = boto3.client('s3')
    
    cleanup_results = []
    
    # Clean up old RDS snapshots (keep last 30)
    snapshots = rds.describe_db_snapshots(
        DBInstanceIdentifier='erpnext-db',
        SnapshotType='manual'
    )
    
    sorted_snapshots = sorted(snapshots['DBSnapshots'], 
                            key=lambda x: x['SnapshotCreateTime'])
    
    if len(sorted_snapshots) > 30:
        for snapshot in sorted_snapshots[:-30]:
            rds.delete_db_snapshot(
                DBSnapshotIdentifier=snapshot['DBSnapshotIdentifier']
            )
            cleanup_results.append(f"Deleted snapshot: {snapshot['DBSnapshotIdentifier']}")
    
    # Clean up old CloudWatch logs (older than 30 days)
    cutoff_date = datetime.now() - timedelta(days=30)
    
    log_groups = logs.describe_log_groups(
        logGroupNamePrefix='/aws/ecs/erpnext'
    )
    
    for log_group in log_groups['logGroups']:
        logs.put_retention_policy(
            logGroupName=log_group['logGroupName'],
            retentionInDays=30
        )
        cleanup_results.append(f"Set retention for: {log_group['logGroupName']}")
    
    # Clean up old S3 backup objects (older than 90 days)
    bucket_name = f"erpnext-backups-{boto3.client('sts').get_caller_identity()['Account']}"
    
    response = s3.list_objects_v2(
        Bucket=bucket_name,
        Prefix='backups/'
    )
    
    for obj in response.get('Contents', []):
        if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
            s3.delete_object(
                Bucket=bucket_name,
                Key=obj['Key']
            )
            cleanup_results.append(f"Deleted S3 object: {obj['Key']}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Cleanup completed',
            'results': cleanup_results
        })
    }
EOF

# Schedule monthly cleanup
aws events put-rule \
    --name erpnext-monthly-cleanup \
    --schedule-expression "cron(0 6 1 * ? *)" \
    --description "Monthly resource cleanup for ERPNext" \
    --state ENABLED
```

This production setup guide provides comprehensive coverage of security hardening, advanced monitoring, disaster recovery, performance optimization, and operational procedures for ERPNext running on AWS managed services. The configuration supports both ECS and EKS deployments with enterprise-grade reliability and security.

## ➡️ Next Steps

1. **Security Audit**: Conduct regular security assessments using AWS Security Hub
2. **Performance Baseline**: Establish performance benchmarks using CloudWatch and custom metrics
3. **Disaster Recovery Testing**: Schedule and automate regular DR drills
4. **Cost Optimization**: Monthly cost reviews using AWS Cost Explorer and Trusted Advisor
5. **Compliance Monitoring**: Regular compliance checks using AWS Config and Security Hub
6. **Documentation Updates**: Keep operational runbooks current with infrastructure changes

---

**⚠️ Important**: Regular reviews and updates of these configurations are essential for maintaining security, performance, and cost-effectiveness in production environments. Monitor AWS Service Health Dashboard for service updates and security advisories.