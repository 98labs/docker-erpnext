# ERPNext GKE Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying ERPNext on Google Kubernetes Engine (GKE). It assumes you have completed the prerequisites in `00-prerequisites.md`.

## 🏗️ GKE Cluster Setup

### 1. Create GKE Cluster

```bash
# Create GKE cluster with recommended configuration
gcloud container clusters create erpnext-cluster \
    --zone=us-central1-a \
    --num-nodes=3 \
    --node-locations=us-central1-a,us-central1-b,us-central1-c \
    --machine-type=e2-standard-4 \
    --disk-type=pd-ssd \
    --disk-size=50GB \
    --enable-autoscaling \
    --min-nodes=2 \
    --max-nodes=10 \
    --enable-autorepair \
    --enable-autoupgrade \
    --maintenance-window-start=2023-01-01T09:00:00Z \
    --maintenance-window-end=2023-01-01T17:00:00Z \
    --maintenance-window-recurrence="FREQ=WEEKLY;BYDAY=SA,SU" \
    --enable-network-policy \
    --enable-ip-alias \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --addons=HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS \
    --workload-pool=erpnext-production.svc.id.goog

# Get cluster credentials
gcloud container clusters get-credentials erpnext-cluster --zone=us-central1-a
```

### 2. Verify Cluster Setup

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes -o wide

# Verify node readiness
kubectl get nodes
kubectl top nodes
```

## 🔐 Workload Identity Setup

### 1. Enable Workload Identity (if not done during cluster creation)

```bash
# Enable Workload Identity on existing cluster
gcloud container clusters update erpnext-cluster \
    --zone=us-central1-a \
    --workload-pool=erpnext-production.svc.id.goog
```

### 2. Create Kubernetes Service Account

```bash
# Create namespace
kubectl create namespace erpnext

# Create Kubernetes service account
kubectl create serviceaccount erpnext-ksa --namespace=erpnext

# Bind Google service account to Kubernetes service account
gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:erpnext-production.svc.id.goog[erpnext/erpnext-ksa]" \
    erpnext-gke@erpnext-production.iam.gserviceaccount.com

# Annotate Kubernetes service account
kubectl annotate serviceaccount erpnext-ksa \
    --namespace=erpnext \
    iam.gke.io/gcp-service-account=erpnext-gke@erpnext-production.iam.gserviceaccount.com
```

## 💾 Storage Setup

### 1. Create Storage Classes

```bash
# Create storage class for fast SSD storage
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd-retain
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

# Create storage class for standard storage
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-retain
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
```

### 2. Create Persistent Volume Claims

```bash
# Create PVC for ERPNext sites
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-sites-pvc
  namespace: erpnext
spec:
  storageClassName: ssd-retain
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF

# Create PVC for ERPNext assets
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-assets-pvc
  namespace: erpnext
spec:
  storageClassName: ssd-retain
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
EOF

# Create PVC for MariaDB data (if using in-cluster DB)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-data-pvc
  namespace: erpnext
spec:
  storageClassName: ssd-retain
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
```

## 🔑 Secrets Management

### 1. Create Kubernetes Secrets from GCP Secret Manager

```bash
# Create secret for ERPNext admin password
kubectl create secret generic erpnext-admin-secret \
    --namespace=erpnext \
    --from-literal=password="$(gcloud secrets versions access latest --secret=erpnext-admin-password)"

# Create secret for database password
kubectl create secret generic erpnext-db-secret \
    --namespace=erpnext \
    --from-literal=password="$(gcloud secrets versions access latest --secret=erpnext-db-password)"

# Create secret for API credentials
kubectl create secret generic erpnext-api-secret \
    --namespace=erpnext \
    --from-literal=api-key="$(gcloud secrets versions access latest --secret=erpnext-api-key)" \
    --from-literal=api-secret="$(gcloud secrets versions access latest --secret=erpnext-api-secret)"
```

### 2. Create ConfigMap for ERPNext Configuration

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-config
  namespace: erpnext
data:
  APP_VERSION: "v14"
  APP_URL: "erpnext.yourdomain.com"
  APP_USER: "Administrator"
  APP_DB_PARAM: "db"
  DEVELOPER_MODE: "0"
  ENABLE_SCHEDULER: "1"
  SOCKETIO_PORT: "9000"
  REDIS_CACHE_URL: "redis://redis:6379/0"
  REDIS_QUEUE_URL: "redis://redis:6379/1"
  REDIS_SOCKETIO_URL: "redis://redis:6379/2"
  DB_HOST: "mariadb"
  DB_PORT: "3306"
EOF
```

## 🐳 Deploy ERPNext Services

### 1. Deploy Redis

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command:
          - redis-server
          - --appendonly
          - "yes"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: erpnext
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF
```

### 2. Deploy MariaDB

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.6
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: MYSQL_DATABASE
          value: "erpnext"
        - name: MYSQL_USER
          value: "erpnext"
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: mariadb-data
        persistentVolumeClaim:
          claimName: mariadb-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: erpnext
spec:
  selector:
    app: mariadb
  ports:
  - port: 3306
    targetPort: 3306
EOF
```

### 3. Deploy ERPNext Backend

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend
  namespace: erpnext
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      serviceAccountName: erpnext-ksa
      initContainers:
      - name: wait-for-db
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo 'Waiting for database...'
          until nc -z mariadb 3306; do
            echo 'Waiting for database to be ready...'
            sleep 5
          done
          echo 'Database is ready!'
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        ports:
        - containerPort: 8000
        - containerPort: 9000
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        - name: assets-data
          mountPath: /home/frappe/frappe-bench/sites/assets
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
      - name: assets-data
        persistentVolumeClaim:
          claimName: erpnext-assets-pvc
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
```

### 4. Deploy ERPNext Frontend (Nginx)

```bash
kubectl apply -f - <<EOF
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
      containers:
      - name: erpnext-frontend
        image: frappe/erpnext-nginx:v14
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
          readOnly: true
        - name: assets-data
          mountPath: /home/frappe/frappe-bench/sites/assets
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
      - name: assets-data
        persistentVolumeClaim:
          claimName: erpnext-assets-pvc
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
```

### 5. Deploy Queue Workers

```bash
kubectl apply -f - <<EOF
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
      serviceAccountName: erpnext-ksa
      containers:
      - name: queue-worker
        image: frappe/erpnext-worker:v14
        command:
        - bench
        - worker
        - --queue
        - default
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-queue-long
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: erpnext-queue-long
  template:
    metadata:
      labels:
        app: erpnext-queue-long
    spec:
      serviceAccountName: erpnext-ksa
      containers:
      - name: queue-worker
        image: frappe/erpnext-worker:v14
        command:
        - bench
        - worker
        - --queue
        - long
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
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
      serviceAccountName: erpnext-ksa
      containers:
      - name: scheduler
        image: frappe/erpnext-worker:v14
        command:
        - bench
        - schedule
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
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
EOF
```

## 🌐 Ingress and Load Balancer Setup

### 1. Install Nginx Ingress Controller

```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

### 2. Create Ingress Resource

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: erpnext-ingress
  namespace: erpnext
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - erpnext.yourdomain.com
    secretName: erpnext-tls
  rules:
  - host: erpnext.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: erpnext-frontend
            port:
              number: 8080
      - path: /socket.io/
        pathType: Prefix
        backend:
          service:
            name: erpnext-backend
            port:
              number: 9000
EOF
```

## 📜 SSL Certificate Management

### 1. Install cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
```

### 2. Create ClusterIssuer for Let's Encrypt

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## 🚀 Initialize ERPNext Site

### 1. Create ERPNext Site Job

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: erpnext-create-site
  namespace: erpnext
spec:
  template:
    spec:
      serviceAccountName: erpnext-ksa
      restartPolicy: Never
      initContainers:
      - name: wait-for-services
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo 'Waiting for database and redis...'
          until nc -z mariadb 3306 && nc -z redis 6379; do
            echo 'Waiting for services...'
            sleep 5
          done
          echo 'Services are ready!'
      containers:
      - name: create-site
        image: frappe/erpnext-worker:v14
        command:
        - bash
        - -c
        - |
          bench new-site frontend \
            --admin-password "\$ADMIN_PASSWORD" \
            --mariadb-root-password "\$DB_PASSWORD" \
            --install-app erpnext \
            --set-default
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
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
EOF
```

### 2. Monitor Site Creation

```bash
# Check job status
kubectl get jobs -n erpnext

# View job logs
kubectl logs -f job/erpnext-create-site -n erpnext

# Check if site was created successfully
kubectl exec -it deployment/erpnext-backend -n erpnext -- bench --site frontend list-apps
```

## 📊 Monitoring and Observability

### 1. Deploy Horizontal Pod Autoscaler

```bash
# HPA for backend pods
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: erpnext-backend-hpa
  namespace: erpnext
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erpnext-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# HPA for frontend pods
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: erpnext-frontend-hpa
  namespace: erpnext
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erpnext-frontend
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF
```

### 2. Create ServiceMonitor for Prometheus (Optional)

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: erpnext-monitor
  namespace: erpnext
  labels:
    app: erpnext
spec:
  selector:
    matchLabels:
      app: erpnext-backend
  endpoints:
  - port: http
    path: /api/method/ping
    interval: 30s
EOF
```

## 🔍 Verification and Testing

### 1. Check All Deployments

```bash
# Check deployment status
kubectl get deployments -n erpnext
kubectl get pods -n erpnext -o wide
kubectl get services -n erpnext

# Check ingress
kubectl get ingress -n erpnext
kubectl describe ingress erpnext-ingress -n erpnext
```

### 2. Test ERPNext Application

```bash
# Get the external IP
kubectl get ingress erpnext-ingress -n erpnext

# Test API endpoint (replace with your domain)
curl -k https://erpnext.yourdomain.com/api/method/ping

# Test login page
curl -k https://erpnext.yourdomain.com/login
```

### 3. Access ERPNext Dashboard

1. Open browser and navigate to: `https://erpnext.yourdomain.com`
2. Login with:
   - Username: `Administrator`
   - Password: (from `erpnext-admin-secret`)

## 🛠️ Troubleshooting

### 1. Check Pod Logs

```bash
# Backend logs
kubectl logs -f deployment/erpnext-backend -n erpnext

# Frontend logs
kubectl logs -f deployment/erpnext-frontend -n erpnext

# Database logs
kubectl logs -f deployment/mariadb -n erpnext

# Queue worker logs
kubectl logs -f deployment/erpnext-queue-default -n erpnext
```

### 2. Debug Database Connection

```bash
# Test database connectivity from backend pod
kubectl exec -it deployment/erpnext-backend -n erpnext -- bash
# Inside the pod:
mysql -h mariadb -u erpnext -p erpnext
```

### 3. Check Persistent Volume Claims

```bash
# Check PVC status
kubectl get pvc -n erpnext

# Check persistent volumes
kubectl get pv
```

### 4. Common Issues and Solutions

#### Site Creation Failed
```bash
# Delete failed job and retry
kubectl delete job erpnext-create-site -n erpnext

# Check database is accessible
kubectl exec -it deployment/mariadb -n erpnext -- mysql -u root -p
```

#### SSL Certificate Issues
```bash
# Check certificate status
kubectl get certificate -n erpnext
kubectl describe certificate erpnext-tls -n erpnext

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

#### Ingress Not Working
```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify ingress configuration
kubectl describe ingress erpnext-ingress -n erpnext
```

## 📈 Scaling and Performance

### 1. Scale Deployments

```bash
# Scale backend pods
kubectl scale deployment erpnext-backend --replicas=5 -n erpnext

# Scale queue workers
kubectl scale deployment erpnext-queue-default --replicas=3 -n erpnext
```

### 2. Monitor Resource Usage

```bash
# Check resource usage
kubectl top pods -n erpnext
kubectl top nodes

# Check HPA status
kubectl get hpa -n erpnext
kubectl describe hpa erpnext-backend-hpa -n erpnext
```

## 🔐 Security Considerations

### 1. Network Policies (Optional but Recommended)

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: erpnext-network-policy
  namespace: erpnext
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - namespaceSelector:
        matchLabels:
          name: erpnext
  egress:
  - {}
EOF
```

### 2. Pod Security Standards

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: erpnext
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF
```

## 🧹 Cleanup

### 1. Delete ERPNext Deployment

```bash
# Delete all resources in erpnext namespace
kubectl delete namespace erpnext

# Delete persistent volumes (if needed)
kubectl delete pv $(kubectl get pv -o jsonpath='{.items[?(@.spec.claimRef.namespace=="erpnext")].metadata.name}')

# Delete cluster (if needed)
gcloud container clusters delete erpnext-cluster --zone=us-central1-a
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Documentation](https://frappeframework.com/docs)

## ➡️ Next Steps

1. **Production Hardening**: Follow `03-production-setup.md`
2. **Backup Strategy**: Implement backup procedures
3. **Monitoring Setup**: Configure detailed monitoring and alerting
4. **Performance Tuning**: Optimize based on your workload

---

**⚠️ Important**: This deployment creates resources that incur costs. Monitor your GCP billing and optimize resource allocation based on your actual usage patterns.