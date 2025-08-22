# ERPNext AWS Deployment with Managed Services

## Overview

This directory contains comprehensive guides and resources for deploying ERPNext on Amazon Web Services (AWS) using **managed database services**: Amazon RDS for MySQL and Amazon MemoryDB for Redis. This approach provides better reliability, security, and operational efficiency compared to self-hosted databases.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Amazon Web Services                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │   Amazon ECS    │    │   Amazon EKS    │                   │
│  │   (Fargate)     │    │  (Kubernetes)   │                   │
│  │                 │    │                 │                   │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │                   │
│  │ │  Frontend   │ │    │ │    Pods     │ │                   │
│  │ │  Backend    │ │    │ │ - Frontend  │ │                   │
│  │ │  Workers    │ │    │ │ - Backend   │ │                   │
│  │ │  Scheduler  │ │    │ │ - Workers   │ │                   │
│  │ └─────────────┘ │    │ │ - Scheduler │ │                   │
│  └─────────────────┘    │ └─────────────┘ │                   │
│                         └─────────────────┘                   │
│                                │                               │
│  ┌─────────────────────────────┼─────────────────────────────┐ │
│  │           Managed Services  │                             │ │
│  │                            │                             │ │
│  │  ┌──────────────┐    ┌─────────────┐    ┌──────────────┐ │ │
│  │  │  Amazon RDS  │    │ MemoryDB    │    │   Amazon S3  │ │ │
│  │  │   (MySQL)    │    │  (Redis)    │    │   (Files)    │ │ │
│  │  └──────────────┘    └─────────────┘    └──────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
aws-managed/
├── README.md                                    # This file
├── 00-prerequisites-managed.md                  # Prerequisites for managed services
├── 01-ecs-managed-deployment.md                 # ECS with managed databases
├── 02-eks-managed-deployment.md                 # EKS with managed databases
├── 03-production-managed-setup.md               # Production hardening
├── kubernetes-manifests/                        # K8s manifests for managed services
│   ├── namespace.yaml                           # Namespace with security policies
│   ├── storage.yaml                             # EFS and EBS storage classes
│   ├── configmap.yaml                           # Config for managed services
│   ├── secrets.yaml                             # External Secrets integration
│   ├── erpnext-backend.yaml                     # Backend with RDS connection
│   ├── erpnext-frontend.yaml                    # Optimized frontend
│   ├── erpnext-workers.yaml                     # Workers with managed DB
│   ├── ingress.yaml                             # ALB ingress controller
│   └── jobs.yaml                                # Site creation and backup jobs
└── scripts/                                     # Automation scripts
    ├── deploy-ecs.sh                            # ECS deployment script
    └── deploy-eks.sh                            # EKS deployment script
```

## 🚀 Quick Start

### Option 1: Amazon ECS with Fargate (Recommended for Simplicity)

```bash
# 1. Complete prerequisites
cd aws-managed/
# Follow 00-prerequisites-managed.md

# 2. Deploy to ECS
cd scripts/
export AWS_REGION="us-east-1"
export PROJECT_NAME="erpnext"
export DOMAIN_NAME="erpnext.yourdomain.com"
./deploy-ecs.sh --project-name $PROJECT_NAME --domain $DOMAIN_NAME
```

### Option 2: Amazon EKS (Recommended for Production)

```bash
# 1. Complete prerequisites
cd aws-managed/
# Follow 00-prerequisites-managed.md

# 2. Deploy to EKS
cd scripts/
export AWS_REGION="us-east-1"
export PROJECT_NAME="erpnext"
export DOMAIN_NAME="erpnext.yourdomain.com"
./deploy-eks.sh --project-name $PROJECT_NAME --domain $DOMAIN_NAME
```

## 🎯 Key Benefits of AWS Managed Services

### 🛡️ Enhanced Reliability
- **99.95% SLA** for RDS and MemoryDB
- **Multi-AZ deployment** with automatic failover
- **Point-in-time recovery** for databases
- **Automated backups** with cross-region replication

### 🔧 Operational Efficiency
- **Zero database administration** overhead
- **Automatic security patches** and updates
- **Performance insights** and optimization recommendations
- **Built-in monitoring** with CloudWatch

### 🔒 Enterprise Security
- **VPC isolation** with private subnets
- **Encryption at rest and in transit** by default
- **IAM integration** for access control
- **AWS WAF** for application protection

### 💰 Cost Optimization
- **Pay-as-you-scale** pricing model
- **Reserved Instance discounts** available
- **Automatic storage scaling** without downtime
- **Spot instances** for non-critical workloads

## 📊 Deployment Options Comparison

| Feature | ECS + Managed DB | EKS + Managed DB | Self-Hosted DB |
|---------|------------------|------------------|-----------------|
| **Scalability** | Auto (Fargate) | Manual/Auto HPA | Manual |
| **Operational Overhead** | Low | Medium | High |
| **Database Reliability** | 99.95% SLA | 99.95% SLA | Depends on setup |
| **Cost (Small)** | ~$250/month | ~$350/month | ~$200/month |
| **Cost (Large)** | ~$500/month | ~$700/month | ~$450/month |
| **Cold Start** | 1-2 seconds | None | None |
| **Customization** | Medium | High | Very High |
| **Kubernetes Native** | No | Yes | Yes |
| **Multi-tenancy** | Limited | Supported | Supported |

## 🛠️ Managed Services Configuration

### Amazon RDS (MySQL)
- **Instance Types**: db.t3.micro to db.r5.24xlarge
- **Storage**: 20GB to 64TB, automatic scaling
- **Backup**: Automated daily backups with 35-day retention
- **High Availability**: Multi-AZ deployment with automatic failover
- **Security**: VPC isolation, encryption, IAM database authentication

### Amazon MemoryDB for Redis
- **Node Types**: db.t4g.micro to db.r6g.16xlarge
- **Features**: Redis 6.x compatibility, persistence, clustering
- **Performance**: Up to 100+ million requests per second
- **Monitoring**: Built-in CloudWatch metrics and alerts

### Additional AWS Services
- **Amazon S3**: File storage and backups
- **AWS Secrets Manager**: Secure credential management
- **AWS Systems Manager**: Parameter Store for configuration
- **Amazon EFS**: Shared file storage for EKS
- **AWS Lambda**: Automation and maintenance tasks
- **Amazon EventBridge**: Scheduled tasks and triggers

## 🔧 Advanced Features

### Auto-scaling Configuration
- **ECS**: Service auto scaling based on CPU/memory
- **EKS**: Horizontal Pod Autoscaler + Cluster Autoscaler
- **Database**: Automatic storage scaling, manual compute scaling
- **Redis**: Manual scaling with zero-downtime

### Security Hardening
- **Network isolation** with private subnets and security groups
- **IAM roles** for service accounts (IRSA for EKS)
- **AWS WAF** for application-layer protection
- **VPC Flow Logs** for network monitoring
- **AWS Config** for compliance monitoring

### Monitoring & Observability
- **CloudWatch** for metrics, logs, and alerts
- **AWS X-Ray** for distributed tracing
- **Custom dashboards** for ERPNext-specific metrics
- **Performance Insights** for database monitoring
- **Container Insights** for ECS/EKS monitoring

### Backup & Disaster Recovery
- **RDS**: Automated backups with point-in-time recovery
- **Application files**: Automated backup to S3
- **Cross-region replication** for disaster recovery
- **Automated DR testing** with validation
- **Lambda-based backup automation**

## 💰 Cost Estimation & Optimization

### Typical Monthly Costs (US-East-1)

#### Small Deployment (< 50 users) - ECS
```
RDS (db.t3.medium): $67
MemoryDB (1 node): $45
ECS Fargate (2 tasks): $30
ALB: $22
EFS: $3
NAT Gateway: $45
Total: ~$212/month
```

#### Medium Deployment (50-200 users) - EKS
```
RDS (db.r5.large): $150
MemoryDB (2 nodes): $90
EKS Control Plane: $73
EC2 (3 t3.medium): $100
ALB: $22
EFS: $10
NAT Gateway: $45
Total: ~$490/month
```

#### Large Deployment (200+ users) - EKS
```
RDS (db.r5.xlarge): $300
MemoryDB (3 nodes): $135
EKS Control Plane: $73
EC2 (6 t3.large): $300
ALB: $22
EFS: $25
NAT Gateway: $90
Total: ~$945/month
```

### Cost Optimization Strategies
1. **Use Reserved Instances** (up to 75% savings for predictable workloads)
2. **Implement Spot Instances** for non-critical worker nodes
3. **Right-size instances** based on CloudWatch metrics
4. **Use S3 Intelligent Tiering** for file storage
5. **Schedule scaling** during off-hours

## 🚨 Migration Path from Self-Hosted

### Phase 1: Assessment and Planning (Week 1)
- [ ] Audit current infrastructure and data size
- [ ] Identify custom configurations and dependencies
- [ ] Plan migration windows and rollback procedures
- [ ] Set up AWS managed services in parallel

### Phase 2: Infrastructure Setup (Week 2)
- [ ] Deploy VPC, subnets, and security groups
- [ ] Create RDS and MemoryDB instances
- [ ] Set up ECS/EKS cluster and supporting services
- [ ] Configure monitoring and alerting

### Phase 3: Data Migration (Week 3)
- [ ] Export data from existing MySQL/Redis
- [ ] Import to RDS/MemoryDB with validation
- [ ] Migrate file storage to S3/EFS
- [ ] Update connection strings and test thoroughly

### Phase 4: Application Migration (Week 4)
- [ ] Deploy ERPNext with managed services
- [ ] Conduct comprehensive testing
- [ ] DNS cutover to new deployment
- [ ] Monitor performance and optimize

### Phase 5: Optimization and Cleanup (Week 5)
- [ ] Optimize resource allocation based on metrics
- [ ] Implement cost optimization measures
- [ ] Decommission old infrastructure
- [ ] Update backup and DR procedures

## 🔍 Troubleshooting Common Issues

### RDS Connection Issues
```bash
# Test connectivity from ECS/EKS
# For ECS
aws ecs run-task --cluster erpnext-cluster \
    --task-definition erpnext-backend \
    --overrides '{"containerOverrides":[{"name":"erpnext-backend","command":["mysql","-h","RDS_ENDPOINT","-u","admin","-p"]}]}'

# For EKS
kubectl run mysql-test --rm -i --tty --image=mysql:8.0 -- mysql -h RDS_ENDPOINT -u admin -p
```

### MemoryDB Connection Issues
```bash
# Test Redis connectivity
# For EKS
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h REDIS_ENDPOINT ping

# Check AUTH configuration
aws memorydb describe-clusters --cluster-name erpnext-redis --region us-east-1
```

### Performance Issues
```bash
# Check RDS performance
aws rds describe-db-instances --db-instance-identifier erpnext-db
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization

# Monitor MemoryDB metrics
aws cloudwatch get-metric-statistics --namespace AWS/MemoryDB --metric-name CPUUtilization
```

### Cost Issues
```bash
# Analyze costs with AWS CLI
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity MONTHLY --metrics BlendedCost

# Get cost recommendations
aws support describe-trusted-advisor-checks --language en
```

## 📚 Additional Resources

### AWS Documentation
- [Amazon RDS User Guide](https://docs.aws.amazon.com/rds/)
- [Amazon MemoryDB User Guide](https://docs.aws.amazon.com/memorydb/)
- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/ecs/)
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### ERPNext Specific
- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Documentation](https://frappeframework.com/docs)
- [ERPNext GitHub Repository](https://github.com/frappe/erpnext)

### AWS Tools and SDKs
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [eksctl Documentation](https://eksctl.io/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)

### Monitoring & Operations
- [AWS CloudWatch User Guide](https://docs.aws.amazon.com/cloudwatch/)
- [AWS X-Ray Developer Guide](https://docs.aws.amazon.com/xray/)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)

## 🎯 Decision Matrix

### Choose ECS + Managed Services if:
- ✅ Want minimal operational overhead
- ✅ Team has limited Kubernetes experience
- ✅ Need rapid deployment and scaling
- ✅ Prefer AWS-native container orchestration
- ✅ Want to minimize infrastructure complexity

### Choose EKS + Managed Services if:
- ✅ Need advanced Kubernetes features
- ✅ Plan to run multiple applications
- ✅ Require fine-grained control over scheduling
- ✅ Have existing Kubernetes expertise
- ✅ Need advanced networking capabilities
- ✅ Want cloud-agnostic deployment patterns

## 📞 Support & Contributing

### Getting Help
- **Documentation Issues**: Create issues in the repository
- **AWS Support**: Use AWS Support Center for service issues
- **Community**: ERPNext Community Forum and GitHub Discussions
- **Professional Services**: AWS Professional Services for complex deployments

### Contributing
- **Documentation improvements**: Submit pull requests
- **Script enhancements**: Share automation improvements
- **Best practices**: Contribute lessons learned from production deployments
- **Cost optimizations**: Share optimization strategies and findings

### Feedback
We welcome feedback on these deployment guides. Please open an issue or submit a pull request with:
- Improvements to documentation clarity
- Additional troubleshooting scenarios
- Cost optimization techniques
- Security enhancements
- Performance optimization tips

## ⚡ Quick Commands Reference

### ECS Operations
```bash
# Check service status
aws ecs describe-services --cluster erpnext-cluster --services erpnext-backend

# View task logs
aws logs get-log-events --log-group-name /aws/ecs/erpnext-backend

# Scale service
aws ecs update-service --cluster erpnext-cluster --service erpnext-backend --desired-count 5
```

### EKS Operations
```bash
# Check pod status
kubectl get pods -n erpnext

# View logs
kubectl logs -f deployment/erpnext-backend -n erpnext

# Scale deployment
kubectl scale deployment erpnext-backend --replicas=5 -n erpnext
```

### Database Operations
```bash
# Create RDS snapshot
aws rds create-db-snapshot --db-instance-identifier erpnext-db --db-snapshot-identifier manual-backup-$(date +%Y%m%d)

# Monitor MemoryDB
aws memorydb describe-clusters --cluster-name erpnext-redis
```

---

**⚠️ Important Notes**:
- Managed services incur continuous costs even when applications are idle
- Always test deployments thoroughly in staging before production
- Monitor costs regularly using AWS Cost Explorer
- Keep credentials secure and rotate regularly
- Follow AWS security best practices and compliance requirements
- Review and update security groups and IAM policies regularly

**🎯 Recommendation**: For most production deployments, EKS with managed services provides the best balance of control, reliability, and operational efficiency, while ECS offers simplicity for teams new to container orchestration.

**🔄 Maintenance**: These guides are actively maintained. Check for updates regularly and ensure your AWS CLI, kubectl, and other tools are up to date.