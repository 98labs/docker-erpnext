# ERPNext Google Cloud Deployment with Managed Services

## Overview

This directory contains comprehensive guides and resources for deploying ERPNext on Google Cloud Platform (GCP) using **managed database services**: Cloud SQL for MySQL and Memorystore for Redis. This approach provides better reliability, security, and operational efficiency compared to self-hosted databases.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud Platform                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │   Cloud Run     │    │      GKE        │                   │
│  │   (Serverless)  │    │  (Kubernetes)   │                   │
│  │                 │    │                 │                   │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │                   │
│  │ │  Frontend   │ │    │ │   Pods      │ │                   │
│  │ │  Backend    │ │    │ │ - Frontend  │ │                   │
│  │ │  Workers    │ │    │ │ - Backend   │ │                   │
│  │ └─────────────┘ │    │ │ - Workers   │ │                   │
│  └─────────────────┘    │ └─────────────┘ │                   │
│                         └─────────────────┘                   │
│                                │                               │
│  ┌─────────────────────────────┼─────────────────────────────┐ │
│  │           Managed Services  │                             │ │
│  │                            │                             │ │
│  │  ┌──────────────┐    ┌─────────────┐    ┌──────────────┐ │ │
│  │  │  Cloud SQL   │    │ Memorystore │    │Cloud Storage │ │ │
│  │  │   (MySQL)    │    │   (Redis)   │    │   (Files)    │ │ │
│  │  └──────────────┘    └─────────────┘    └──────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
gcp-managed/
├── README.md                                    # This file
├── 00-prerequisites-managed.md                  # Prerequisites for managed services
├── 01-gke-managed-deployment.md                 # GKE with managed databases
├── 02-cloud-run-deployment.md                   # Cloud Run serverless deployment
├── 03-production-managed-setup.md               # Production hardening
├── kubernetes-manifests/                        # K8s manifests for managed services
│   ├── namespace.yaml                           # Namespace with reduced quotas
│   ├── storage.yaml                             # Only application file storage
│   ├── configmap.yaml                           # Config for managed services
│   ├── secrets.yaml                             # External Secrets integration
│   ├── erpnext-backend.yaml                     # Backend with Cloud SQL proxy
│   ├── erpnext-frontend.yaml                    # Optimized frontend
│   ├── erpnext-workers.yaml                     # Workers with managed DB
│   ├── ingress.yaml                             # Enhanced ingress config
│   └── jobs.yaml                                # Site creation and backup jobs
└── scripts/                                     # Automation scripts
    ├── deploy-managed.sh                        # GKE deployment script
    └── cloud-run-deploy.sh                      # Cloud Run deployment script
```

## 🚀 Quick Start

### Option 1: GKE with Managed Services (Recommended for Production)

```bash
# 1. Complete prerequisites
cd gcp-managed/
# Follow 00-prerequisites-managed.md

# 2. Deploy to GKE
cd scripts/
export PROJECT_ID="your-gcp-project"
export DOMAIN="erpnext.yourdomain.com"
export EMAIL="admin@yourdomain.com"
./deploy-managed.sh deploy
```

### Option 2: Cloud Run Serverless Deployment

```bash
# 1. Complete prerequisites
cd gcp-managed/
# Follow 00-prerequisites-managed.md

# 2. Deploy to Cloud Run
cd scripts/
export PROJECT_ID="your-gcp-project"
export DOMAIN="erpnext.yourdomain.com"
./cloud-run-deploy.sh deploy
```

## 🎯 Key Benefits of Managed Services

### 🛡️ Enhanced Reliability
- **99.95% SLA** for Cloud SQL and Memorystore
- **Automatic failover** and disaster recovery
- **Point-in-time recovery** for databases
- **Automated backups** with cross-region replication

### 🔧 Operational Efficiency
- **Zero database administration** overhead
- **Automatic security patches** and updates
- **Performance insights** and optimization recommendations
- **Built-in monitoring** and alerting

### 🔒 Enterprise Security
- **Private IP connectivity** within VPC
- **Encryption at rest and in transit** by default
- **IAM integration** for access control
- **Audit logging** for compliance

### 💰 Cost Optimization
- **Pay-as-you-scale** pricing model
- **Automatic storage scaling** without downtime
- **Right-sizing recommendations** based on usage
- **No over-provisioning** of database resources

## 📊 Deployment Options Comparison

| Feature | GKE + Managed DB | Cloud Run + Managed DB | Self-Hosted DB |
|---------|------------------|------------------------|-----------------|
| **Scalability** | Manual/Auto HPA | Automatic (0-1000+) | Manual |
| **Operational Overhead** | Medium | Very Low | High |
| **Database Reliability** | 99.95% SLA | 99.95% SLA | Depends on setup |
| **Cost (Small)** | ~$450/month | ~$200/month | ~$300/month |
| **Cost (Large)** | ~$800/month | ~$400/month | ~$600/month |
| **Cold Start** | None | 1-3 seconds | None |
| **Customization** | High | Medium | Very High |
| **Multi-tenancy** | Supported | Limited | Supported |

## 🛠️ Managed Services Configuration

### Cloud SQL (MySQL)
- **Instance Types**: db-n1-standard-2 to db-n1-standard-96
- **Storage**: 10GB to 64TB, automatic scaling
- **Backup**: Automated daily backups with 7-day retention
- **High Availability**: Regional persistent disks with automatic failover
- **Security**: Private IP, SSL/TLS encryption, IAM database authentication

### Memorystore (Redis)
- **Tiers**: Basic (1-5GB) or Standard (1-300GB) with HA
- **Features**: Persistence, AUTH, in-transit encryption
- **Performance**: Up to 12 Gbps network throughput
- **Monitoring**: Built-in metrics and alerting

### Additional Services
- **Cloud Storage**: File uploads and static assets
- **Secret Manager**: Secure credential management
- **VPC Access Connector**: Secure serverless-to-VPC communication
- **Cloud Tasks**: Background job processing (Cloud Run)
- **Cloud Scheduler**: Cron jobs and scheduled tasks

## 🔧 Advanced Features

### Auto-scaling Configuration
- **GKE**: Horizontal Pod Autoscaler based on CPU/memory
- **Cloud Run**: Automatic scaling from 0 to 1000+ instances
- **Database**: Automatic storage scaling, manual compute scaling
- **Redis**: Manual scaling with zero-downtime

### Security Hardening
- **Network isolation** with private subnets
- **Workload Identity** for secure GCP API access
- **External Secrets Operator** for credential management
- **Network policies** for pod-to-pod communication
- **Binary Authorization** for container security

### Monitoring & Observability
- **Stackdriver integration** for logs and metrics
- **Custom dashboards** for ERPNext-specific metrics
- **SLO/SLI monitoring** with alerting
- **Distributed tracing** with Cloud Trace
- **Error reporting** with automatic grouping

### Backup & Disaster Recovery
- **Cloud SQL**: Automated backups with point-in-time recovery
- **Application files**: Automated backup to Cloud Storage
- **Cross-region replication** for disaster recovery
- **Automated DR testing** with validation

## 💰 Cost Estimation & Optimization

### Typical Monthly Costs (US-Central1)

#### Small Deployment (< 50 users)
```
Cloud SQL (db-n1-standard-1): $50
Memorystore Redis (1GB): $37
Cloud Run (avg 2 instances): $60
Cloud Storage (50GB): $1
Load Balancer: $18
Total: ~$166/month
```

#### Medium Deployment (50-200 users)
```
Cloud SQL (db-n1-standard-2): $278
Memorystore Redis (5GB): $185
GKE (3 e2-standard-4 nodes): $420
Cloud Storage (200GB): $4
Load Balancer: $18
Total: ~$905/month
```

#### Large Deployment (200+ users)
```
Cloud SQL (db-n1-standard-4): $556
Memorystore Redis (10GB): $370
GKE (6 e2-standard-4 nodes): $840
Cloud Storage (500GB): $10
Load Balancer: $18
Total: ~$1,794/month
```

### Cost Optimization Strategies
1. **Use committed use discounts** (up to 57% savings)
2. **Right-size instances** based on monitoring data
3. **Use preemptible nodes** for non-critical workloads
4. **Implement storage lifecycle policies** for Cloud Storage
5. **Scale down during off-hours** with automation

## 🚨 Migration Path from Self-Hosted

### Phase 1: Assessment (Week 1)
- [ ] Audit current database size and performance
- [ ] Identify custom configurations and extensions
- [ ] Plan migration windows and rollback procedures
- [ ] Set up managed services in parallel

### Phase 2: Data Migration (Week 2)
- [ ] Export data from existing MySQL/Redis
- [ ] Import to Cloud SQL/Memorystore
- [ ] Validate data integrity and performance
- [ ] Update connection strings and test

### Phase 3: Application Migration (Week 3)
- [ ] Deploy ERPNext with managed services
- [ ] Migrate file storage to Cloud Storage
- [ ] Update backup procedures
- [ ] Conduct full testing

### Phase 4: Cutover and Optimization (Week 4)
- [ ] DNS cutover to new deployment
- [ ] Monitor performance and costs
- [ ] Optimize resource allocation
- [ ] Decommission old infrastructure

## 🔍 Troubleshooting Common Issues

### Cloud SQL Connection Issues
```bash
# Test connectivity from GKE
kubectl run mysql-test --rm -i --tty --image=mysql:8.0 -- mysql -h PRIVATE_IP -u erpnext -p

# Check Cloud SQL Proxy logs
kubectl logs deployment/erpnext-backend -c cloud-sql-proxy
```

### Redis Connection Issues
```bash
# Test Redis connectivity
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h REDIS_IP ping

# Check AUTH configuration
gcloud redis instances describe erpnext-redis --region=us-central1
```

### Performance Issues
```bash
# Check database performance
gcloud sql operations list --instance=erpnext-db

# Monitor Redis memory usage
gcloud redis instances describe erpnext-redis --region=us-central1 --format="value(memorySizeGb,redisMemoryUsage)"
```

## 📚 Additional Resources

### Google Cloud Documentation
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/mysql/best-practices)
- [Memorystore Best Practices](https://cloud.google.com/memorystore/docs/redis/memory-management-best-practices)
- [Cloud Run Best Practices](https://cloud.google.com/run/docs/best-practices)
- [GKE Networking Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices/networking)

### ERPNext Specific
- [ERPNext Database Configuration](https://docs.erpnext.com/docs/user/manual/en/setting-up/database-setup)
- [Performance Optimization](https://docs.erpnext.com/docs/user/manual/en/setting-up/performance)
- [Backup Strategies](https://docs.erpnext.com/docs/user/manual/en/setting-up/backup)

### Monitoring & Operations
- [SRE Best Practices](https://sre.google/books/)
- [Prometheus Monitoring](https://prometheus.io/docs/practices/naming/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

## 🎯 Decision Matrix

### Choose GKE + Managed Services if:
- ✅ Need full control over application deployment
- ✅ Require complex networking or multi-tenancy
- ✅ Have existing Kubernetes expertise
- ✅ Need consistent performance with no cold starts
- ✅ Plan to run multiple applications in same cluster

### Choose Cloud Run + Managed Services if:
- ✅ Want minimal operational overhead
- ✅ Have variable or unpredictable traffic
- ✅ Need rapid scaling capabilities
- ✅ Want to minimize costs for smaller deployments
- ✅ Prefer serverless architecture

## 📞 Support & Contributing

### Getting Help
- **Documentation Issues**: Create issues in the repository
- **Deployment Support**: Follow troubleshooting guides
- **Performance Issues**: Check monitoring dashboards
- **Cost Optimization**: Use GCP billing reports and recommendations

### Contributing
- **Documentation improvements**: Submit pull requests
- **Script enhancements**: Share automation improvements
- **Best practices**: Contribute lessons learned
- **Cost optimizations**: Share optimization strategies

---

**⚠️ Important Notes**:
- Managed services incur continuous costs even when not in use
- Always test deployments in staging before production
- Monitor costs and usage regularly
- Keep credentials secure and rotate regularly
- Follow GCP security best practices

**🎯 Recommendation**: For most production deployments, GKE with managed services provides the best balance of control, reliability, and operational efficiency.