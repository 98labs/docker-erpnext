# ERPNext Google Cloud Deployment Guide

## Overview

This directory contains comprehensive guides and resources for deploying ERPNext on Google Cloud Platform (GCP) using Google Kubernetes Engine (GKE).

## 📁 Directory Structure

```
gcp/
├── README.md                           # This file
├── 01-gke-deployment.md                # Complete GKE deployment guide
├── 02-cloud-run-analysis.md            # Cloud Run feasibility analysis
├── 03-production-setup.md              # Production hardening guide
├── kubernetes-manifests/               # Kubernetes YAML manifests
│   ├── namespace.yaml                  # Namespace and resource quotas
│   ├── storage.yaml                    # Storage classes and PVCs
│   ├── configmap.yaml                  # Configuration maps
│   ├── redis.yaml                      # Redis deployment
│   ├── mariadb.yaml                    # MariaDB deployment
│   ├── erpnext-backend.yaml           # ERPNext backend services
│   ├── erpnext-frontend.yaml          # ERPNext frontend (Nginx)
│   ├── erpnext-workers.yaml           # Queue workers and scheduler
│   ├── ingress.yaml                    # Ingress and SSL configuration
│   └── jobs.yaml                       # Site creation and backup jobs
└── scripts/                            # Automation scripts
    ├── deploy.sh                       # Automated deployment script
    └── backup-restore.sh               # Backup and restore utilities
```

## 🚀 Quick Start

### Prerequisites

Before starting, ensure you have completed the setup in `../00-prerequisites.md`.

### 1. Automated Deployment

The easiest way to deploy ERPNext on GKE:

```bash
cd scripts/
export PROJECT_ID="your-gcp-project"
export DOMAIN="erpnext.yourdomain.com"
export EMAIL="admin@yourdomain.com"
./deploy.sh deploy
```

### 2. Manual Deployment

For more control, follow the step-by-step guide in `01-gke-deployment.md`.

### 3. Production Setup

After basic deployment, harden your installation using `03-production-setup.md`.

## 📖 Documentation Guide

### For First-Time Deployments

1. **Start with Prerequisites**: Read `../00-prerequisites.md`
2. **Choose Your Path**: 
   - **Quick Setup**: Use the automated deployment script
   - **Detailed Setup**: Follow `01-gke-deployment.md` step by step
3. **Production Ready**: Apply configurations from `03-production-setup.md`

### For Production Deployments

1. **Security First**: Implement all security measures from `03-production-setup.md`
2. **Monitoring**: Set up comprehensive monitoring and alerting
3. **Backup Strategy**: Configure automated backups using the provided scripts
4. **Performance Tuning**: Optimize based on your workload

### For Cloud Run Consideration

- **Analysis**: Review `02-cloud-run-analysis.md` for Cloud Run vs GKE comparison
- **Recommendation**: Most production workloads should use GKE

## 🛠️ Key Features

### Security Hardening
- Private GKE clusters
- Network policies
- Pod security standards
- RBAC configuration
- Secrets management with External Secrets Operator

### High Availability
- Multi-zone node pools
- Pod anti-affinity rules
- Horizontal Pod Autoscaling
- Pod Disruption Budgets
- Health checks and probes

### Monitoring & Observability
- Prometheus and Grafana integration
- Custom ERPNext dashboards
- Alerting rules
- Log aggregation

### Backup & Recovery
- Automated database backups
- Site files backup
- Point-in-time recovery
- Cross-region backup storage

### Performance Optimization
- Resource requests and limits
- Vertical Pod Autoscaling
- Persistent SSD storage
- Nginx optimization

## 📊 Cost Estimation

### Typical Production Setup
- **GKE Cluster**: ~$562/month
  - 3 × e2-standard-4 nodes: ~$420/month
  - Cluster management: $72.50/month
  - Storage and networking: ~$70/month

### Cost Optimization Tips
1. **Use Preemptible Nodes**: 60-80% cost savings for non-critical workloads
2. **Right-size Resources**: Start small and scale based on usage
3. **Use Regional Persistent Disks**: Better availability with minimal cost increase
4. **Enable Cluster Autoscaling**: Scale down during low-usage periods

## 🔧 Customization

### Environment Variables
All scripts support environment variable customization:

```bash
# Deployment configuration
export PROJECT_ID="your-project"
export CLUSTER_NAME="erpnext-prod"
export ZONE="us-central1-a"
export DOMAIN="erp.company.com"
export EMAIL="admin@company.com"

# Resource configuration
export NAMESPACE="erpnext"
export BACKUP_BUCKET="company-erpnext-backups"
```

### Kubernetes Manifests
Modify the YAML files in `kubernetes-manifests/` to:
- Adjust resource allocations
- Change storage sizes
- Modify security policies
- Add custom configurations

## 🚨 Troubleshooting

### Common Issues

1. **Pod Startup Failures**
   ```bash
   kubectl logs -f deployment/erpnext-backend -n erpnext
   kubectl describe pod <pod-name> -n erpnext
   ```

2. **Database Connection Issues**
   ```bash
   kubectl exec -it deployment/erpnext-backend -n erpnext -- mysql -h mariadb -u erpnext -p
   ```

3. **SSL Certificate Problems**
   ```bash
   kubectl get certificate -n erpnext
   kubectl describe certificate erpnext-tls -n erpnext
   ```

4. **Storage Issues**
   ```bash
   kubectl get pvc -n erpnext
   kubectl get pv
   ```

### Getting Help

- Check deployment status: `./scripts/deploy.sh status`
- View backup status: `./scripts/backup-restore.sh status`
- Monitor logs: `kubectl logs -f deployment/erpnext-backend -n erpnext`

## 🔄 Upgrade Process

### ERPNext Version Upgrades

1. **Backup Current Installation**
   ```bash
   ./scripts/backup-restore.sh backup full
   ```

2. **Update Image Tags**
   Edit `kubernetes-manifests/erpnext-*.yaml` files to use new version

3. **Apply Migrations**
   ```bash
   kubectl apply -f kubernetes-manifests/jobs.yaml
   ```

4. **Rolling Update**
   ```bash
   kubectl set image deployment/erpnext-backend erpnext-backend=frappe/erpnext-worker:v15 -n erpnext
   ```

### Kubernetes Upgrades

Follow GKE's automatic upgrade schedule or manually upgrade:
```bash
gcloud container clusters upgrade erpnext-cluster --zone=us-central1-a
```

## 🛡️ Security Considerations

### Network Security
- Private clusters with authorized networks
- Network policies restricting pod-to-pod communication
- Web Application Firewall (Cloud Armor)

### Access Control
- RBAC with minimal permissions
- Workload Identity for GCP service access
- Regular access reviews

### Data Protection
- Encryption at rest and in transit
- Regular security scans
- Backup encryption
- Secrets rotation

## 📈 Performance Monitoring

### Key Metrics to Monitor
- Response time (target: <2s for 95% of requests)
- CPU and memory usage
- Database performance
- Queue processing time
- Storage utilization

### Scaling Triggers
- CPU > 70% for 5 minutes → scale up
- Memory > 80% for 5 minutes → scale up
- Queue depth > 100 jobs → scale workers

## 🔗 Additional Resources

- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Docs](https://frappeframework.com/docs)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)

---

**Need Help?** 
- Check the troubleshooting sections in each guide
- Review common issues in `03-production-setup.md`
- Use the provided scripts for automated operations