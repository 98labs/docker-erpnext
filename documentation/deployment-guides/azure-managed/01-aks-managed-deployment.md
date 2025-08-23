# Azure Kubernetes Service (AKS) Deployment with Managed Services

## Overview

This guide covers deploying ERPNext on Azure Kubernetes Service (AKS) using Azure Database for PostgreSQL and Azure Cache for Redis as managed services.

## Prerequisites

- Completed all steps in `00-prerequisites-managed.md`
- Azure CLI installed and configured
- kubectl and Helm installed
- Environment variables from prerequisites exported

## 🚀 AKS Cluster Setup

### 1. Create AKS Cluster
```bash
# Source environment variables
source ~/erpnext-azure-env.sh

# Create AKS cluster
az aks create \
    --name erpnext-aks \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --node-count 3 \
    --node-vm-size Standard_D4s_v3 \
    --enable-managed-identity \
    --assign-identity $IDENTITY_ID \
    --network-plugin azure \
    --vnet-subnet-id /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/erpnext-vnet/subnets/aks-subnet \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.0.10.10 \
    --service-cidr 10.0.10.0/24 \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 10 \
    --enable-addons monitoring,azure-keyvault-secrets-provider \
    --workspace-resource-id /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/erpnext-logs \
    --enable-ahub \
    --generate-ssh-keys

# Get AKS credentials
az aks get-credentials \
    --name erpnext-aks \
    --resource-group $RESOURCE_GROUP \
    --overwrite-existing

# Verify cluster connection
kubectl get nodes
```

### 2. Configure Cluster Autoscaler
```bash
# Update autoscaler configuration
az aks update \
    --name erpnext-aks \
    --resource-group $RESOURCE_GROUP \
    --cluster-autoscaler-profile \
        scale-down-delay-after-add=10m \
        scale-down-unneeded-time=10m \
        scale-down-utilization-threshold=0.5 \
        skip-nodes-with-local-storage=false \
        max-graceful-termination-sec=600
```

### 3. Install NGINX Ingress Controller
```bash
# Add Helm repo for ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --set controller.service.externalTrafficPolicy=Local

# Wait for external IP
kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -w
```

### 4. Install Cert-Manager (for SSL)
```bash
# Install cert-manager for Let's Encrypt SSL
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.12.0 \
    --set installCRDs=true

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL:-admin@example.com}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## 🔐 Secrets Management

### 1. Configure Azure Key Vault Provider
```bash
# Enable Key Vault secrets provider
az aks enable-addons \
    --addons azure-keyvault-secrets-provider \
    --name erpnext-aks \
    --resource-group $RESOURCE_GROUP

# Configure SecretProviderClass
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: erpnext-secrets
  namespace: erpnext
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$CLIENT_ID"
    keyvaultName: "$KEYVAULT_NAME"
    objects: |
      array:
        - |
          objectName: erpnext-admin-password
          objectType: secret
        - |
          objectName: erpnext-db-password
          objectType: secret
        - |
          objectName: erpnext-redis-key
          objectType: secret
        - |
          objectName: erpnext-api-key
          objectType: secret
        - |
          objectName: erpnext-api-secret
          objectType: secret
    tenantId: "$(az account show --query tenantId -o tsv)"
  secretObjects:
  - secretName: erpnext-secrets
    type: Opaque
    data:
    - objectName: erpnext-admin-password
      key: admin-password
    - objectName: erpnext-db-password
      key: db-password
    - objectName: erpnext-redis-key
      key: redis-key
    - objectName: erpnext-api-key
      key: api-key
    - objectName: erpnext-api-secret
      key: api-secret
EOF
```

### 2. Create ConfigMap for Database Connection
```bash
# Create namespace
kubectl create namespace erpnext

# Create ConfigMap with connection details
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-config
  namespace: erpnext
data:
  DB_HOST: "$DB_SERVER_NAME.postgres.database.azure.com"
  DB_PORT: "5432"
  DB_NAME: "erpnext"
  DB_USER: "$DB_ADMIN_USER"
  REDIS_HOST: "$REDIS_HOST"
  REDIS_PORT: "6380"
  STORAGE_ACCOUNT: "$STORAGE_ACCOUNT"
  STORAGE_CONTAINER: "erpnext-files"
EOF
```

## 📦 Deploy ERPNext

### 1. Create Persistent Volume Claims
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-sites
  namespace: erpnext
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile-csi
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-assets
  namespace: erpnext
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile-csi
  resources:
    requests:
      storage: 20Gi
EOF
```

### 2. Deploy Backend Service
```bash
cat <<EOF | kubectl apply -f -
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
      serviceAccountName: default
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: assets
        persistentVolumeClaim:
          claimName: erpnext-assets
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: erpnext-secrets
      containers:
      - name: backend
        image: frappe/erpnext-worker:v14
        ports:
        - containerPort: 8000
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: assets
          mountPath: /home/frappe/frappe-bench/sites/assets
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_PORT
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_NAME
        - name: POSTGRES_USER
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: REDIS_CACHE
          value: "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/0"
        - name: REDIS_QUEUE
          value: "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/1"
        - name: REDIS_SOCKETIO
          value: "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/2"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: redis-key
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: REDIS_HOST
        - name: REDIS_PORT
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: REDIS_PORT
        - name: ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: admin-password
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
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
  - port: 8000
    targetPort: 8000
  type: ClusterIP
EOF
```

### 3. Deploy Frontend Service
```bash
cat <<EOF | kubectl apply -f -
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
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: assets
        persistentVolumeClaim:
          claimName: erpnext-assets
      containers:
      - name: frontend
        image: frappe/erpnext-nginx:v14
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: assets
          mountPath: /usr/share/nginx/html/assets
        env:
        - name: BACKEND
          value: erpnext-backend:8000
        - name: FRAPPE_SITE_NAME_HEADER
          value: "frontend"
        - name: SOCKETIO
          value: erpnext-websocket:9000
        - name: UPSTREAM_REAL_IP_ADDRESS
          value: "127.0.0.1"
        - name: UPSTREAM_REAL_IP_HEADER
          value: "X-Forwarded-For"
        - name: UPSTREAM_REAL_IP_RECURSIVE
          value: "on"
        - name: PROXY_READ_TIMEOUT
          value: "120"
        - name: CLIENT_MAX_BODY_SIZE
          value: "50m"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
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
  type: ClusterIP
EOF
```

### 4. Deploy Workers
```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-worker-default
  namespace: erpnext
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-worker-default
  template:
    metadata:
      labels:
        app: erpnext-worker-default
    spec:
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: erpnext-secrets
      containers:
      - name: worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "default"]
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_HOST
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: redis-key
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-worker-long
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: erpnext-worker-long
  template:
    metadata:
      labels:
        app: erpnext-worker-long
    spec:
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: erpnext-secrets
      containers:
      - name: worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "long"]
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_HOST
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: redis-key
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-worker-short
  namespace: erpnext
spec:
  replicas: 1
  selector:
    matchLabels:
      app: erpnext-worker-short
  template:
    metadata:
      labels:
        app: erpnext-worker-short
    spec:
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: erpnext-secrets
      containers:
      - name: worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "short"]
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_HOST
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: redis-key
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
EOF
```

### 5. Deploy Scheduler
```bash
cat <<EOF | kubectl apply -f -
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
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: erpnext-secrets
      containers:
      - name: scheduler
        image: frappe/erpnext-worker:v14
        command: ["bench", "schedule"]
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_HOST
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: redis-key
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
EOF
```

### 6. Deploy WebSocket Service
```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-websocket
  namespace: erpnext
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-websocket
  template:
    metadata:
      labels:
        app: erpnext-websocket
    spec:
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      containers:
      - name: websocket
        image: frappe/frappe-socketio:v14
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: erpnext-websocket
  namespace: erpnext
spec:
  selector:
    app: erpnext-websocket
  ports:
  - port: 9000
    targetPort: 9000
  type: ClusterIP
EOF
```

## 🌐 Configure Ingress

```bash
# Create Ingress with SSL
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: erpnext-ingress
  namespace: erpnext
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "120"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${DOMAIN:-erpnext.example.com}
    secretName: erpnext-tls
  rules:
  - host: ${DOMAIN:-erpnext.example.com}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: erpnext-frontend
            port:
              number: 8080
      - path: /socket.io
        pathType: Prefix
        backend:
          service:
            name: erpnext-websocket
            port:
              number: 9000
EOF
```

## 🔄 Initialize ERPNext Site

```bash
# Create site initialization job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: erpnext-site-init
  namespace: erpnext
spec:
  template:
    spec:
      restartPolicy: Never
      volumes:
      - name: sites
        persistentVolumeClaim:
          claimName: erpnext-sites
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: erpnext-secrets
      containers:
      - name: init
        image: frappe/erpnext-worker:v14
        command: 
        - /bin/bash
        - -c
        - |
          bench new-site frontend \
            --db-host $DB_HOST \
            --db-port 5432 \
            --db-name erpnext \
            --db-password \$POSTGRES_PASSWORD \
            --admin-password \$ADMIN_PASSWORD \
            --install-app erpnext
          bench --site frontend migrate
        volumeMounts:
        - name: sites
          mountPath: /home/frappe/frappe-bench/sites
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: erpnext-config
              key: DB_HOST
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: admin-password
EOF

# Wait for job completion
kubectl wait --for=condition=complete --timeout=600s job/erpnext-site-init -n erpnext
```

## 📊 Configure Horizontal Pod Autoscaling

```bash
# Create HPA for backend
kubectl autoscale deployment erpnext-backend \
    --namespace erpnext \
    --cpu-percent=70 \
    --min=2 \
    --max=10

# Create HPA for frontend
kubectl autoscale deployment erpnext-frontend \
    --namespace erpnext \
    --cpu-percent=70 \
    --min=2 \
    --max=5

# Create HPA for workers
kubectl autoscale deployment erpnext-worker-default \
    --namespace erpnext \
    --cpu-percent=70 \
    --min=2 \
    --max=8
```

## 🔍 Monitoring and Logging

### 1. Enable Application Insights
```bash
# Add Application Insights to deployments
kubectl set env deployment/erpnext-backend \
    -n erpnext \
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$INSTRUMENTATION_KEY"
```

### 2. Create Azure Monitor Alerts
```bash
# Create alert for high CPU usage
az monitor metrics alert create \
    --name erpnext-high-cpu \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/erpnext-aks \
    --condition "avg node_cpu_usage_percentage > 80" \
    --window-size 5m \
    --evaluation-frequency 1m

# Create alert for pod failures
az monitor metrics alert create \
    --name erpnext-pod-failures \
    --resource-group $RESOURCE_GROUP \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/erpnext-aks \
    --condition "sum kube_pod_status_phase{phase='Failed'} > 0" \
    --window-size 5m \
    --evaluation-frequency 1m
```

### 3. View Logs
```bash
# View backend logs
kubectl logs -f deployment/erpnext-backend -n erpnext

# View all pods in namespace
kubectl get pods -n erpnext -w

# Check pod events
kubectl describe pod -n erpnext
```

## 🔧 Troubleshooting

### Database Connection Issues
```bash
# Test database connection from pod
kubectl run pg-test --rm -i --tty --image=postgres:13 -n erpnext -- \
    psql -h $DB_SERVER_NAME.postgres.database.azure.com -U $DB_ADMIN_USER -d erpnext

# Check secret mounting
kubectl exec -it deployment/erpnext-backend -n erpnext -- ls -la /mnt/secrets-store/
```

### Redis Connection Issues
```bash
# Test Redis connection
kubectl run redis-test --rm -i --tty --image=redis:alpine -n erpnext -- \
    redis-cli -h $REDIS_HOST -a $REDIS_KEY ping
```

### Storage Issues
```bash
# Check PVC status
kubectl get pvc -n erpnext

# Check storage class
kubectl get storageclass

# Describe PVC for events
kubectl describe pvc erpnext-sites -n erpnext
```

## 🚀 Production Optimizations

### 1. Enable Pod Disruption Budgets
```bash
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: erpnext-backend-pdb
  namespace: erpnext
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: erpnext-backend
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: erpnext-frontend-pdb
  namespace: erpnext
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: erpnext-frontend
EOF
```

### 2. Configure Resource Quotas
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: erpnext-quota
  namespace: erpnext
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
EOF
```

### 3. Network Policies
```bash
cat <<EOF | kubectl apply -f -
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
    - podSelector: {}
  egress:
  - to:
    - podSelector: {}
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 6380
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
```

## 📋 Verification Checklist

```bash
# Check all pods are running
kubectl get pods -n erpnext

# Verify services
kubectl get svc -n erpnext

# Check ingress
kubectl get ingress -n erpnext

# Test application
curl -I https://${DOMAIN:-erpnext.example.com}

# Check HPA status
kubectl get hpa -n erpnext

# View cluster nodes
kubectl get nodes

# Check cluster autoscaler
kubectl describe configmap cluster-autoscaler-status -n kube-system
```

## 🎯 Next Steps

1. Configure backup strategy (see `03-production-managed-setup.md`)
2. Set up monitoring dashboards
3. Configure CI/CD pipeline
4. Implement disaster recovery plan
5. Performance tuning based on workload

---

**⚠️ Important Notes**:
- Monitor costs regularly in Azure Cost Management
- Review and rotate secrets periodically
- Keep AKS cluster and node pools updated
- Plan maintenance windows for updates
- Test disaster recovery procedures regularly