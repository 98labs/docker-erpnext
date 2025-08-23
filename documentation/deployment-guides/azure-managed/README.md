# ERPNext Azure Deployment with Managed Services

## Overview

This directory contains comprehensive guides and resources for deploying ERPNext on Microsoft Azure using **managed database services**: Azure Database for MySQL/PostgreSQL and Azure Cache for Redis. This approach provides better reliability, security, and operational efficiency compared to self-hosted databases.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Microsoft Azure                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │ Container       │    │      AKS        │                   │
│  │ Instances       │    │  (Kubernetes)   │                   │
│  │ (Serverless)    │    │                 │                   │
│  │                 │    │ ┌─────────────┐ │                   │
│  │ ┌─────────────┐ │    │ │   Pods      │ │                   │
│  │ │  Frontend   │ │    │ │ - Frontend  │ │                   │
│  │ │  Backend    │ │    │ │ - Backend   │ │                   │
│  │ │  Workers    │ │    │ │ - Workers   │ │                   │
│  │ └─────────────┘ │    │ └─────────────┘ │                   │
│  └─────────────────┘    └─────────────────┘                   │
│                                │                               │
│  ┌─────────────────────────────┼─────────────────────────────┐ │
│  │           Managed Services  │                             │ │
│  │                            │                             │ │
│  │  ┌──────────────┐    ┌─────────────┐    ┌──────────────┐ │ │
│  │  │ Azure DB for │    │ Azure Cache │    │Azure Storage │ │ │
│  │  │ PostgreSQL   │    │  for Redis  │    │   (Blobs)    │ │ │
│  │  └──────────────┘    └─────────────┘    └──────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
azure-managed/
├── README.md                                    # This file
├── 00-prerequisites-managed.md                  # Prerequisites for managed services
├── 01-aks-managed-deployment.md                 # AKS with managed databases
├── 02-container-instances-deployment.md         # Container Instances deployment
├── 03-production-managed-setup.md               # Production hardening
├── kubernetes-manifests/                        # K8s manifests for managed services
│   ├── namespace.yaml                           # Namespace with resource quotas
│   ├── storage.yaml                             # Application file storage
│   ├── configmap.yaml                           # Config for managed services
│   ├── secrets.yaml                             # Key Vault integration
│   ├── erpnext-backend.yaml                     # Backend deployment
│   ├── erpnext-frontend.yaml                    # Frontend deployment
│   ├── erpnext-workers.yaml                     # Workers deployment
│   ├── ingress.yaml                             # Application Gateway Ingress
│   └── jobs.yaml                                # Site creation and backup jobs
└── scripts/                                     # Automation scripts
    ├── deploy-managed.sh                        # AKS deployment script
    └── container-instances-deploy.sh            # Container Instances script
```

## 🚀 Quick Start

### Option 1: AKS with Managed Services (Recommended for Production)

```bash
# 1. Complete prerequisites
cd azure-managed/
# Follow 00-prerequisites-managed.md

# 2. Deploy to AKS
cd scripts/
export RESOURCE_GROUP="erpnext-rg"
export DOMAIN="erpnext.yourdomain.com"
export EMAIL="admin@yourdomain.com"
./deploy-managed.sh deploy
```

### Option 2: Azure Container Instances Deployment

```bash
# 1. Complete prerequisites
cd azure-managed/
# Follow 00-prerequisites-managed.md

# 2. Deploy to Container Instances
cd scripts/
export RESOURCE_GROUP="erpnext-rg"
export DOMAIN="erpnext.yourdomain.com"
./container-instances-deploy.sh deploy
```

## 🎯 Key Benefits of Managed Services

### 🛡️ Enhanced Reliability
- **99.99% SLA** for Azure Database and Azure Cache
- **Automatic failover** and disaster recovery
- **Point-in-time restore** for databases (up to 35 days)
- **Automated backups** with geo-redundant storage

### 🔧 Operational Efficiency
- **Zero database administration** overhead
- **Automatic security patches** and updates
- **Performance recommendations** via Azure Advisor
- **Built-in monitoring** with Azure Monitor

### 🔒 Enterprise Security
- **Private endpoints** within VNet
- **Encryption at rest and in transit** by default
- **Azure AD integration** for authentication
- **Audit logging** and threat detection

### 💰 Cost Optimization
- **Reserved capacity** discounts (up to 65% savings)
- **Automatic scaling** for compute and storage
- **Serverless options** for variable workloads
- **Cost management** recommendations

## 📊 Deployment Options Comparison

| Feature | AKS + Managed DB | Container Instances + Managed DB | Self-Hosted DB |
|---------|------------------|----------------------------------|-----------------|
| **Scalability** | Manual/Auto HPA | Manual (1-100 instances) | Manual |
| **Operational Overhead** | Medium | Very Low | High |
| **Database Reliability** | 99.99% SLA | 99.99% SLA | Depends on setup |
| **Cost (Small)** | ~$400/month | ~$180/month | ~$280/month |
| **Cost (Large)** | ~$750/month | ~$380/month | ~$550/month |
| **Cold Start** | None | 5-10 seconds | None |
| **Customization** | High | Medium | Very High |
| **Multi-tenancy** | Supported | Limited | Supported |

## 🛠️ Managed Services Configuration

### Azure Database for PostgreSQL
- **Tiers**: Basic, General Purpose, Memory Optimized
- **Compute**: 1-64 vCores, Burstable options available
- **Storage**: 5GB to 16TB, automatic growth
- **Backup**: Automated daily backups with 7-35 day retention
- **High Availability**: Zone redundant deployment
- **Security**: Private endpoints, Azure AD auth, TLS 1.2+

### Azure Cache for Redis
- **Tiers**: Basic (1GB-53GB), Standard (250MB-53GB), Premium (6GB-1.2TB)
- **Features**: Persistence, clustering, geo-replication
- **Performance**: Up to 2,000,000 requests/second
- **Monitoring**: Azure Monitor integration

### Additional Services
- **Azure Storage**: Blob storage for files and static assets
- **Azure Key Vault**: Secure credential management
- **Virtual Network**: Private networking with service endpoints
- **Azure Logic Apps**: Workflow automation
- **Azure Functions**: Serverless compute for background jobs

## 🔧 Advanced Features

### Auto-scaling Configuration
- **AKS**: Horizontal Pod Autoscaler and Cluster Autoscaler
- **Container Instances**: Manual scaling with container groups
- **Database**: Automatic storage scaling, manual compute scaling
- **Redis**: Manual scaling with zero downtime

### Security Hardening
- **Network isolation** with VNet and NSGs
- **Managed Identity** for secure Azure API access
- **Key Vault integration** for secrets management
- **Network policies** for pod-to-pod communication
- **Azure Policy** for compliance enforcement

### Monitoring & Observability
- **Azure Monitor** integration for logs and metrics
- **Application Insights** for application performance
- **Log Analytics** workspace for centralized logging
- **Azure Dashboards** for visualization
- **Alert rules** for proactive monitoring

### Backup & Disaster Recovery
- **Database**: Automated backups with geo-redundancy
- **Application files**: Automated backup to Azure Storage
- **Cross-region replication** for disaster recovery
- **Azure Site Recovery** for full DR solution

## 💰 Cost Estimation & Optimization

### Typical Monthly Costs (East US)

#### Small Deployment (< 50 users)
```
Azure Database (B_Gen5_2): $73
Azure Cache Redis (C1): $61
Container Instances (2 vCPU): $73
Azure Storage (50GB): $1
Application Gateway: $18
Total: ~$226/month
```

#### Medium Deployment (50-200 users)
```
Azure Database (GP_Gen5_4): $292
Azure Cache Redis (C3): $244
AKS (3 D4s_v3 nodes): $384
Azure Storage (200GB): $4
Application Gateway: $18
Total: ~$942/month
```

#### Large Deployment (200+ users)
```
Azure Database (GP_Gen5_8): $584
Azure Cache Redis (P1): $443
AKS (6 D4s_v3 nodes): $768
Azure Storage (500GB): $10
Application Gateway: $18
Total: ~$1,823/month
```

### Cost Optimization Strategies
1. **Use reserved instances** (up to 65% savings)
2. **Right-size resources** based on monitoring data
3. **Use spot instances** for non-critical workloads
4. **Implement lifecycle management** for blob storage
5. **Use Azure Hybrid Benefit** if you have existing licenses

## 🚨 Migration Path from Self-Hosted

### Phase 1: Assessment (Week 1)
- [ ] Audit current database size and performance
- [ ] Identify custom configurations and extensions
- [ ] Plan migration windows and rollback procedures
- [ ] Set up managed services in parallel

### Phase 2: Data Migration (Week 2)
- [ ] Export data from existing MySQL/Redis
- [ ] Use Azure Database Migration Service
- [ ] Validate data integrity and performance
- [ ] Update connection strings and test

### Phase 3: Application Migration (Week 3)
- [ ] Deploy ERPNext with managed services
- [ ] Migrate file storage to Azure Storage
- [ ] Update backup procedures
- [ ] Conduct full testing

### Phase 4: Cutover and Optimization (Week 4)
- [ ] DNS cutover to new deployment
- [ ] Monitor performance and costs
- [ ] Optimize resource allocation
- [ ] Decommission old infrastructure

## 🔍 Troubleshooting Common Issues

### Database Connection Issues
```bash
# Test connectivity from AKS
kubectl run pg-test --rm -i --tty --image=postgres:13 -- psql -h your-db.postgres.database.azure.com -U erpnext@your-db -d erpnext

# Check connection from Container Instances
az container exec --resource-group erpnext-rg --name erpnext-backend --exec-command "psql -h your-db.postgres.database.azure.com -U erpnext@your-db -d erpnext"
```

### Redis Connection Issues
```bash
# Test Redis connectivity
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h your-cache.redis.cache.windows.net -a your-access-key ping

# Check Redis metrics
az redis show --name your-cache --resource-group erpnext-rg
```

### Performance Issues
```bash
# Check database performance
az postgres server show --resource-group erpnext-rg --name your-db

# Monitor Redis memory usage
az redis show --name your-cache --resource-group erpnext-rg --query "redisConfiguration"
```

## 📚 Additional Resources

### Azure Documentation
- [Azure Database for PostgreSQL Best Practices](https://docs.microsoft.com/azure/postgresql/concepts-best-practices)
- [Azure Cache for Redis Best Practices](https://docs.microsoft.com/azure/azure-cache-for-redis/cache-best-practices)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [Container Instances Overview](https://docs.microsoft.com/azure/container-instances/container-instances-overview)

### ERPNext Specific
- [ERPNext Database Configuration](https://docs.erpnext.com/docs/user/manual/en/setting-up/database-setup)
- [Performance Optimization](https://docs.erpnext.com/docs/user/manual/en/setting-up/performance)
- [Backup Strategies](https://docs.erpnext.com/docs/user/manual/en/setting-up/backup)

### Monitoring & Operations
- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Application Insights](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Log Analytics](https://docs.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)

## 🎯 Decision Matrix

### Choose AKS + Managed Services if:
- ✅ Need full control over application deployment
- ✅ Require complex networking or multi-tenancy
- ✅ Have existing Kubernetes expertise
- ✅ Need consistent performance with no cold starts
- ✅ Plan to run multiple applications in same cluster

### Choose Container Instances + Managed Services if:
- ✅ Want minimal operational overhead
- ✅ Have predictable traffic patterns
- ✅ Need simple deployment model
- ✅ Want to minimize costs for smaller deployments
- ✅ Prefer serverless-like simplicity

## 📞 Support & Contributing

### Getting Help
- **Documentation Issues**: Create issues in the repository
- **Deployment Support**: Follow troubleshooting guides
- **Performance Issues**: Check Azure Monitor dashboards
- **Cost Optimization**: Use Azure Cost Management

### Contributing
- **Documentation improvements**: Submit pull requests
- **Script enhancements**: Share automation improvements
- **Best practices**: Contribute lessons learned
- **Cost optimizations**: Share optimization strategies

---

**⚠️ Important Notes**:
- Managed services incur continuous costs even when not in use
- Always test deployments in staging before production
- Monitor costs and usage regularly with Azure Cost Management
- Keep credentials secure in Azure Key Vault
- Follow Azure security best practices

**🎯 Recommendation**: For most production deployments, AKS with managed services provides the best balance of control, reliability, and operational efficiency.