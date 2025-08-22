# ERPNext GKE Deployment with Managed Database Services

## Overview

This guide provides step-by-step instructions for deploying ERPNext on Google Kubernetes Engine (GKE) using Cloud SQL for MySQL and Memorystore for Redis. This approach offers better reliability, security, and manageability compared to self-hosted databases.

## 🏗️ GKE Cluster Setup

### 1. Create GKE Cluster with VPC Integration

```bash
# Create GKE cluster in the custom VPC
gcloud container clusters create erpnext-managed-cluster \
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
    --network=erpnext-vpc \
    --subnetwork=erpnext-subnet \
    --enable-private-nodes \
    --master-ipv4-cidr-block=172.16.0.0/28 \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --addons=HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS \
    --workload-pool=erpnext-production.svc.id.goog \
    --enable-shielded-nodes

# Get cluster credentials
gcloud container clusters get-credentials erpnext-managed-cluster --zone=us-central1-a
```

### 2. Install Cloud SQL Proxy Operator (Recommended)

```bash
# Install Cloud SQL Proxy Operator for secure database connections
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/cloud-sql-proxy-operator/main/deploy/cloud-sql-proxy-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available deployment/cloud-sql-proxy-operator -n cloud-sql-proxy-operator-system --timeout=300s
```

### 3. Verify Cluster Setup

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes -o wide

# Verify node readiness
kubectl get nodes
kubectl top nodes
```

## 🔐 Workload Identity Setup

### 1. Configure Workload Identity

```bash
# Create Kubernetes service account
kubectl create namespace erpnext
kubectl create serviceaccount erpnext-ksa --namespace=erpnext

# Bind Google service account to Kubernetes service account
gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:erpnext-production.svc.id.goog[erpnext/erpnext-ksa]" \
    erpnext-managed@erpnext-production.iam.gserviceaccount.com

# Annotate Kubernetes service account
kubectl annotate serviceaccount erpnext-ksa \
    --namespace=erpnext \
    iam.gke.io/gcp-service-account=erpnext-managed@erpnext-production.iam.gserviceaccount.com
```

## 💾 Storage Setup (Files Only)

### 1. Create Storage Classes

```bash
# Create storage class for ERPNext files
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
```

### 2. Create Persistent Volume Claims

```bash
# Create PVC for ERPNext sites (no database PVC needed)
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
---
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
```

## 🔑 Database Connection Setup

### 1. Create Cloud SQL Proxy Instance

```bash
# Create Cloud SQL Proxy for secure database connection
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudsql-proxy-config
  namespace: erpnext
data:
  connection-name: "erpnext-production:us-central1:erpnext-db"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudsql-proxy
  namespace: erpnext
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudsql-proxy
  template:
    metadata:
      labels:
        app: cloudsql-proxy
    spec:
      serviceAccountName: erpnext-ksa
      containers:
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.35.4-alpine
        command:
        - "/cloud_sql_proxy"
        - "-instances=erpnext-production:us-central1:erpnext-db=tcp:0.0.0.0:3306"
        - "-credential_file=/var/secrets/google/key.json"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: cloudsql-instance-credentials
          mountPath: /var/secrets/google
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          tcpSocket:
            port: 3306
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 3306
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: cloudsql-instance-credentials
        secret:
          secretName: cloudsql-instance-credentials
---
apiVersion: v1
kind: Service
metadata:
  name: cloudsql-proxy
  namespace: erpnext
spec:
  selector:
    app: cloudsql-proxy
  ports:
  - port: 3306
    targetPort: 3306
EOF
```

### 2. Alternative: Cloud SQL Auth Proxy Sidecar Pattern

```bash
# For production, use sidecar pattern with each deployment
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-managed-config
  namespace: erpnext
data:
  APP_VERSION: "v14"
  APP_URL: "erpnext.yourdomain.com"
  APP_USER: "Administrator"
  APP_DB_PARAM: "db"
  DEVELOPER_MODE: "0"
  ENABLE_SCHEDULER: "1"
  SOCKETIO_PORT: "9000"
  # Managed Redis connection
  REDIS_CACHE_URL: "redis://REDIS_HOST:6379/0"
  REDIS_QUEUE_URL: "redis://REDIS_HOST:6379/1"
  REDIS_SOCKETIO_URL: "redis://REDIS_HOST:6379/2"
  # Cloud SQL connection via proxy
  DB_HOST: "127.0.0.1"
  DB_PORT: "3306"
  DB_NAME: "erpnext"
  DB_USER: "erpnext"
  # Connection settings for Cloud SQL
  DB_TIMEOUT: "60"
  DB_CHARSET: "utf8mb4"
EOF
```

### 3. Get Redis Host IP

```bash
# Get Redis host IP and update ConfigMap
REDIS_HOST=$(gcloud redis instances describe erpnext-redis --region=us-central1 --format="value(host)")

# Update ConfigMap with Redis host
kubectl patch configmap erpnext-managed-config -n erpnext \
  --type merge -p "{\"data\":{\"REDIS_CACHE_URL\":\"redis://${REDIS_HOST}:6379/0\",\"REDIS_QUEUE_URL\":\"redis://${REDIS_HOST}:6379/1\",\"REDIS_SOCKETIO_URL\":\"redis://${REDIS_HOST}:6379/2\"}}"
```

## 🔑 Secrets Management

### 1. Create Database Connection Secrets

```bash
# Create secret for Cloud SQL service account key
kubectl create secret generic cloudsql-instance-credentials \
    --namespace=erpnext \
    --from-file=key.json=$HOME/erpnext-managed-key.json

# Create secret for database credentials
kubectl create secret generic erpnext-db-secret \
    --namespace=erpnext \
    --from-literal=password="$(gcloud secrets versions access latest --secret=erpnext-db-password)"

# Create secret for ERPNext admin credentials
kubectl create secret generic erpnext-admin-secret \
    --namespace=erpnext \
    --from-literal=password="$(gcloud secrets versions access latest --secret=erpnext-admin-password)"

# Create secret for API credentials
kubectl create secret generic erpnext-api-secret \
    --namespace=erpnext \
    --from-literal=api-key="$(gcloud secrets versions access latest --secret=erpnext-api-key)" \
    --from-literal=api-secret="$(gcloud secrets versions access latest --secret=erpnext-api-secret)"
```

## 🐳 Deploy ERPNext Services

### 1. Deploy ERPNext Backend with Cloud SQL Sidecar

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend
  namespace: erpnext
  labels:
    app: erpnext-backend
    component: backend
    environment: production
    version: v14
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
        component: backend
        environment: production
        version: v14
    spec:
      serviceAccountName: erpnext-ksa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      initContainers:
      - name: wait-for-services
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo 'Waiting for database proxy...'
          until nc -z 127.0.0.1 3306; do
            echo 'Waiting for database...'
            sleep 5
          done
          echo 'Database is ready!'
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        envFrom:
        - configMapRef:
            name: erpnext-managed-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 9000
          name: socketio
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
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.35.4-alpine
        command:
        - "/cloud_sql_proxy"
        - "-instances=erpnext-production:us-central1:erpnext-db=tcp:127.0.0.1:3306"
        securityContext:
          runAsNonRoot: true
          runAsUser: 2  # non-root user in cloud-sql-proxy image
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
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

### 2. Deploy ERPNext Frontend

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-frontend
  namespace: erpnext
  labels:
    app: erpnext-frontend
    component: frontend
    environment: production
    version: v14
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: erpnext-frontend
  template:
    metadata:
      labels:
        app: erpnext-frontend
        component: frontend
        environment: production
        version: v14
    spec:
      containers:
      - name: erpnext-frontend
        image: frappe/erpnext-nginx:v14
        ports:
        - containerPort: 8080
          name: http
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

### 3. Deploy Queue Workers

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
            name: erpnext-managed-config
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
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.35.4-alpine
        command:
        - "/cloud_sql_proxy"
        - "-instances=erpnext-production:us-central1:erpnext-db=tcp:127.0.0.1:3306"
        securityContext:
          runAsNonRoot: true
          runAsUser: 2
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
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
            name: erpnext-managed-config
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
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.35.4-alpine
        command:
        - "/cloud_sql_proxy"
        - "-instances=erpnext-production:us-central1:erpnext-db=tcp:127.0.0.1:3306"
        securityContext:
          runAsNonRoot: true
          runAsUser: 2
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      nodeSelector:
        cloud.google.com/gke-preemptible: "false"
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

### 2. Install cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
```

### 3. Create Ingress Resource

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
      - path: /socket.io/
        pathType: Prefix
        backend:
          service:
            name: erpnext-backend
            port:
              number: 9000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: erpnext-frontend
            port:
              number: 8080
---
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
  backoffLimit: 3
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
          echo 'Waiting for database proxy...'
          until nc -z 127.0.0.1 3306; do
            echo 'Waiting for database...'
            sleep 5
          done
          echo 'Database is ready!'
          # Additional wait for database to be fully ready
          sleep 30
      containers:
      - name: create-site
        image: frappe/erpnext-worker:v14
        command:
        - bash
        - -c
        - |
          set -e
          echo "Starting ERPNext site creation..."
          
          # Check if site already exists
          if [ -d "/home/frappe/frappe-bench/sites/frontend" ]; then
            echo "Site 'frontend' already exists. Skipping creation."
            exit 0
          fi
          
          # Create the site
          bench new-site frontend \
            --admin-password "\$ADMIN_PASSWORD" \
            --mariadb-root-password "\$DB_PASSWORD" \
            --install-app erpnext \
            --set-default
          
          echo "Site creation completed successfully!"
        envFrom:
        - configMapRef:
            name: erpnext-managed-config
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
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.35.4-alpine
        command:
        - "/cloud_sql_proxy"
        - "-instances=erpnext-production:us-central1:erpnext-db=tcp:127.0.0.1:3306"
        securityContext:
          runAsNonRoot: true
          runAsUser: 2
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
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

## 📊 Auto-scaling Configuration

### 1. Horizontal Pod Autoscaler

```bash
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
  minReplicas: 3
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

# Test database connectivity
kubectl exec -it deployment/erpnext-backend -n erpnext -- nc -zv 127.0.0.1 3306

# Test Redis connectivity (from within cluster)
REDIS_HOST=$(kubectl get configmap erpnext-managed-config -n erpnext -o jsonpath='{.data.REDIS_CACHE_URL}' | cut -d'/' -f3 | cut -d':' -f1)
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h $REDIS_HOST ping
```

### 2. Test ERPNext Application

```bash
# Get the external IP
kubectl get ingress erpnext-ingress -n erpnext

# Test API endpoint
curl -k https://erpnext.yourdomain.com/api/method/ping

# Test login page
curl -k https://erpnext.yourdomain.com/login
```

## 🗄️ Backup Strategy for Managed Services

### 1. Cloud SQL Automated Backups

```bash
# Verify automated backups are enabled
gcloud sql instances describe erpnext-db --format="value(settings.backupConfiguration.enabled)"

# Create manual backup
gcloud sql backups create --instance=erpnext-db --description="Pre-migration backup"

# List backups
gcloud sql backups list --instance=erpnext-db
```

### 2. Site Files Backup

```bash
# Create backup job for site files
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: erpnext-files-backup
  namespace: erpnext
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: erpnext-ksa
          restartPolicy: OnFailure
          containers:
          - name: files-backup
            image: google/cloud-sdk:alpine
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
              tar -czf /tmp/sites_backup_\$BACKUP_DATE.tar.gz -C /sites .
              gsutil cp /tmp/sites_backup_\$BACKUP_DATE.tar.gz gs://erpnext-backups/sites/
              rm /tmp/sites_backup_\$BACKUP_DATE.tar.gz
            volumeMounts:
            - name: sites-data
              mountPath: /sites
              readOnly: true
          volumes:
          - name: sites-data
            persistentVolumeClaim:
              claimName: erpnext-sites-pvc
EOF
```

## 🛠️ Troubleshooting

### 1. Database Connection Issues

```bash
# Check Cloud SQL proxy logs
kubectl logs deployment/erpnext-backend -c cloud-sql-proxy -n erpnext

# Test direct Cloud SQL connection
gcloud sql connect erpnext-db --user=erpnext

# Check database status
gcloud sql instances describe erpnext-db --format="value(state)"
```

### 2. Redis Connection Issues

```bash
# Check Redis instance status
gcloud redis instances describe erpnext-redis --region=us-central1 --format="value(state)"

# Test Redis connection from cluster
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h $REDIS_HOST ping
```

### 3. Network Connectivity

```bash
# Check VPC peering
gcloud services vpc-peerings list --network=erpnext-vpc

# Verify firewall rules
gcloud compute firewall-rules list --filter="network:erpnext-vpc"

# Test connectivity from pod
kubectl exec -it deployment/erpnext-backend -n erpnext -- nslookup erpnext-redis.c.erpnext-production.internal
```

## 💰 Cost Optimization for Managed Services

### 1. Right-size Database Instance

```bash
# Monitor database utilization
gcloud monitoring metrics list --filter="resource.type=cloudsql_database"

# Scale down during low usage (if needed)
gcloud sql instances patch erpnext-db --tier=db-g1-small

# Scale up for high usage
gcloud sql instances patch erpnext-db --tier=db-n1-standard-4
```

### 2. Optimize Redis Instance

```bash
# Monitor Redis memory usage
gcloud redis instances describe erpnext-redis --region=us-central1 --format="value(memorySizeGb)"

# Use appropriate tier based on requirements
# Basic tier: Lower cost, no HA
# Standard tier: Higher cost, with HA
```

## 📈 Performance Benefits of Managed Services

### 1. Database Performance
- **Automatic optimization**: Cloud SQL automatically optimizes performance
- **Read replicas**: Easy to add for read scaling
- **Connection pooling**: Built-in connection management
- **Automatic backups**: Point-in-time recovery

### 2. Redis Performance
- **Managed scaling**: Easy to resize based on needs
- **High availability**: Automatic failover in standard tier
- **Monitoring**: Built-in performance metrics
- **Security**: Automatic security patches

### 3. Operational Benefits
- **Reduced maintenance**: No database administration overhead
- **Automated updates**: Security patches applied automatically
- **Monitoring**: Integrated with Cloud Monitoring
- **Compliance**: Built-in compliance features

## 📚 Additional Resources

- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/mysql/best-practices)
- [Memorystore Best Practices](https://cloud.google.com/memorystore/docs/redis/memory-management-best-practices)
- [GKE Networking](https://cloud.google.com/kubernetes-engine/docs/concepts/network-overview)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/mysql/sql-proxy)

## ➡️ Next Steps

1. **Production Hardening**: Follow `03-production-managed-setup.md`
2. **Monitoring Setup**: Configure detailed monitoring for managed services
3. **Performance Tuning**: Optimize based on your workload
4. **Disaster Recovery**: Implement cross-region backup strategy

---

**⚠️ Important**: This deployment uses managed services that incur continuous costs. Monitor your usage and optimize resource allocation based on actual requirements.