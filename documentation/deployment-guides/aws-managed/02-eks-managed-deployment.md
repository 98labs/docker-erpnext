# ERPNext EKS Deployment with Managed Database Services

## Overview

This guide provides step-by-step instructions for deploying ERPNext on Amazon Elastic Kubernetes Service (EKS) using Amazon RDS for MySQL and Amazon MemoryDB for Redis. This approach offers enterprise-grade Kubernetes orchestration with AWS managed database services for maximum reliability and scalability.

## 🏗️ EKS Cluster Setup

### 1. Create EKS Cluster with eksctl
```bash
# Create cluster configuration file
cat > erpnext-eks-cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: erpnext-cluster
  region: us-east-1
  version: "1.28"

availabilityZones: ["us-east-1a", "us-east-1b"]

vpc:
  id: $(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erpnext-vpc" --query "Vpcs[0].VpcId" --output text)
  subnets:
    private:
      us-east-1a:
        id: $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=erpnext-private-subnet-1a" --query "Subnets[0].SubnetId" --output text)
      us-east-1b:
        id: $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=erpnext-private-subnet-1b" --query "Subnets[0].SubnetId" --output text)
    public:
      us-east-1a:
        id: $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=erpnext-public-subnet-1a" --query "Subnets[0].SubnetId" --output text)
      us-east-1b:
        id: $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=erpnext-public-subnet-1b" --query "Subnets[0].SubnetId" --output text)

nodeGroups:
  - name: erpnext-workers
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 2
    maxSize: 10
    volumeSize: 50
    volumeType: gp3
    subnets:
      - us-east-1a
      - us-east-1b
    privateNetworking: true
    securityGroups:
      attachIDs: ["$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=erpnext-app-sg" --query "SecurityGroups[0].GroupId" --output text)"]
    ssh:
      allow: false
    iam:
      withAddonPolicies:
        ebs: true
        fsx: true
        efs: true
        albIngress: true
        autoScaler: true
        cloudWatch: true
        externalDNS: true
    labels:
      node-type: worker
      application: erpnext
    tags:
      Name: erpnext-worker-node
      Application: ERPNext
      Environment: production

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest

iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: aws-load-balancer-controller
        namespace: kube-system
      wellKnownPolicies:
        awsLoadBalancerController: true
    - metadata:
        name: efs-csi-controller-sa
        namespace: kube-system
      wellKnownPolicies:
        efsCSIController: true
    - metadata:
        name: external-secrets-operator
        namespace: external-secrets
      attachPolicyARNs:
        - "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
    - metadata:
        name: erpnext-sa
        namespace: erpnext
      attachPolicyARNs:
        - "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
        - "arn:aws:iam::aws:policy/AmazonS3FullAccess"
EOF

# Create the cluster
eksctl create cluster -f erpnext-eks-cluster.yaml

# Wait for cluster to be ready
eksctl utils wait-cluster-ready --cluster erpnext-cluster --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name erpnext-cluster

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Install Required Add-ons

#### AWS Load Balancer Controller
```bash
# Download and install AWS Load Balancer Controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Install AWS Load Balancer Controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=erpnext-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

#### EFS CSI Driver
```bash
# Install EFS CSI Driver
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update

helm install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=efs-csi-controller-sa

# Verify installation
kubectl get pods -n kube-system -l app=efs-csi-controller
```

#### External Secrets Operator
```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace \
    --set installCRDs=true

# Verify installation
kubectl get pods -n external-secrets
```

## 📦 Storage Setup

### 1. Create EFS for Shared Storage
```bash
# EFS was created in prerequisites, get the ID
EFS_ID=$(aws efs describe-file-systems \
    --query "FileSystems[?Tags[?Key=='Name' && Value=='erpnext-sites-efs']].FileSystemId" --output text)

# Create storage class for EFS
cat > efs-storageclass.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: $EFS_ID
  directoryPerms: "700"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"
EOF

kubectl apply -f efs-storageclass.yaml

# Create persistent volume for sites
cat > erpnext-efs-pv.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: erpnext-sites-pv
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: $EFS_ID
EOF

kubectl apply -f erpnext-efs-pv.yaml
```

### 2. Create EBS Storage Class for Database Backups
```bash
cat > ebs-gp3-storageclass.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
EOF

kubectl apply -f ebs-gp3-storageclass.yaml
```

## 🔑 Namespace and RBAC Setup
```bash
# Create ERPNext namespace
kubectl create namespace erpnext

# Create service account for ERPNext
kubectl create serviceaccount erpnext-sa -n erpnext

# Annotate service account with IAM role (this was done by eksctl)
kubectl annotate serviceaccount erpnext-sa \
    -n erpnext \
    eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/eksctl-erpnext-cluster-addon-iamserviceaccount-Role1-$(aws sts get-caller-identity --query Account --output text)
```

## 🔐 External Secrets Configuration
```bash
# Create SecretStore for AWS Secrets Manager
cat > aws-secretstore.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretstore
  namespace: erpnext
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-operator
EOF

kubectl apply -f aws-secretstore.yaml

# Create external secrets
cat > erpnext-external-secrets.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-db-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-db-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: erpnext/database/password
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-redis-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-redis-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: erpnext/redis/password
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-admin-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-admin-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: erpnext/admin/password
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-api-secret
  namespace: erpnext
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: erpnext-api-secret
    creationPolicy: Owner
  data:
    - secretKey: api-key
      remoteRef:
        key: erpnext/api/credentials
        property: api_key
    - secretKey: api-secret
      remoteRef:
        key: erpnext/api/credentials
        property: api_secret
EOF

kubectl apply -f erpnext-external-secrets.yaml
```

## ⚙️ ConfigMap for Application Configuration
```bash
# Get database and Redis endpoints from Parameter Store
DB_HOST=$(aws ssm get-parameter --name "/erpnext/database/host" --query "Parameter.Value" --output text)
REDIS_HOST=$(aws ssm get-parameter --name "/erpnext/redis/host" --query "Parameter.Value" --output text)

cat > erpnext-configmap.yaml <<EOF
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
  # Database configuration
  DB_HOST: "$DB_HOST"
  DB_PORT: "3306"
  DB_NAME: "erpnext"
  DB_USER: "admin"
  # Redis configuration
  REDIS_CACHE_URL: "redis://$REDIS_HOST:6379/0"
  REDIS_QUEUE_URL: "redis://$REDIS_HOST:6379/1"
  REDIS_SOCKETIO_URL: "redis://$REDIS_HOST:6379/2"
  # Connection settings
  DB_TIMEOUT: "60"
  DB_CHARSET: "utf8mb4"
EOF

kubectl apply -f erpnext-configmap.yaml
```

## 📂 Persistent Volume Claims
```bash
cat > erpnext-pvcs.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-sites-pvc
  namespace: erpnext
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: erpnext-backups-pvc
  namespace: erpnext
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-gp3
  resources:
    requests:
      storage: 100Gi
EOF

kubectl apply -f erpnext-pvcs.yaml
```

## 🐳 Deploy ERPNext Services

### 1. ERPNext Backend Deployment
```bash
cat > erpnext-backend.yaml <<EOF
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
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      initContainers:
      - name: wait-for-db
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo 'Waiting for database to be ready...'
          until nc -z \$DB_HOST \$DB_PORT; do
            echo 'Waiting for database...'
            sleep 10
          done
          echo 'Database is ready!'
        envFrom:
        - configMapRef:
            name: erpnext-config
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 9000
          name: socketio
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
              key: password
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        - name: backups-data
          mountPath: /home/frappe/frappe-bench/sites/backups
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
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /api/method/ping
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      - name: backups-data
        persistentVolumeClaim:
          claimName: erpnext-backups-pvc
      nodeSelector:
        node-type: worker
---
apiVersion: v1
kind: Service
metadata:
  name: erpnext-backend
  namespace: erpnext
  labels:
    app: erpnext-backend
spec:
  selector:
    app: erpnext-backend
  ports:
  - name: http
    port: 8000
    targetPort: 8000
    protocol: TCP
  - name: socketio
    port: 9000
    targetPort: 9000
    protocol: TCP
  type: ClusterIP
EOF

kubectl apply -f erpnext-backend.yaml
```

### 2. ERPNext Frontend Deployment
```bash
cat > erpnext-frontend.yaml <<EOF
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
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 1000
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
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      nodeSelector:
        node-type: worker
---
apiVersion: v1
kind: Service
metadata:
  name: erpnext-frontend
  namespace: erpnext
  labels:
    app: erpnext-frontend
spec:
  selector:
    app: erpnext-frontend
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
EOF

kubectl apply -f erpnext-frontend.yaml
```

### 3. ERPNext Worker Deployments
```bash
cat > erpnext-workers.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-queue-default
  namespace: erpnext
  labels:
    app: erpnext-queue-default
    component: worker
    queue: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-queue-default
  template:
    metadata:
      labels:
        app: erpnext-queue-default
        component: worker
        queue: default
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: queue-worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "default"]
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
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
      nodeSelector:
        node-type: worker
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-queue-long
  namespace: erpnext
  labels:
    app: erpnext-queue-long
    component: worker
    queue: long
spec:
  replicas: 1
  selector:
    matchLabels:
      app: erpnext-queue-long
  template:
    metadata:
      labels:
        app: erpnext-queue-long
        component: worker
        queue: long
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: queue-worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "long"]
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
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
      nodeSelector:
        node-type: worker
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-queue-short
  namespace: erpnext
  labels:
    app: erpnext-queue-short
    component: worker
    queue: short
spec:
  replicas: 2
  selector:
    matchLabels:
      app: erpnext-queue-short
  template:
    metadata:
      labels:
        app: erpnext-queue-short
        component: worker
        queue: short
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: queue-worker
        image: frappe/erpnext-worker:v14
        command: ["bench", "worker", "--queue", "short"]
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
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
      nodeSelector:
        node-type: worker
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-scheduler
  namespace: erpnext
  labels:
    app: erpnext-scheduler
    component: scheduler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: erpnext-scheduler
  template:
    metadata:
      labels:
        app: erpnext-scheduler
        component: scheduler
    spec:
      serviceAccountName: erpnext-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: scheduler
        image: frappe/erpnext-worker:v14
        command: ["bench", "schedule"]
        envFrom:
        - configMapRef:
            name: erpnext-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-db-secret
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
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
      nodeSelector:
        node-type: worker
EOF

kubectl apply -f erpnext-workers.yaml
```

## 🌐 Application Load Balancer and Ingress

### 1. Create Ingress with AWS Load Balancer Controller
```bash
cat > erpnext-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: erpnext-ingress
  namespace: erpnext
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:$(aws sts get-caller-identity --query Account --output text):certificate/your-cert-id
    alb.ingress.kubernetes.io/load-balancer-attributes: routing.http2.enabled=true,idle_timeout.timeout_seconds=60
    alb.ingress.kubernetes.io/healthcheck-grace-period-seconds: "60"
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/tags: Environment=production,Application=ERPNext
spec:
  rules:
  - host: erpnext.yourdomain.com
    http:
      paths:
      - path: /socket.io
        pathType: Prefix
        backend:
          service:
            name: erpnext-backend
            port:
              number: 9000
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: erpnext-backend
            port:
              number: 8000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: erpnext-frontend
            port:
              number: 8080
EOF

kubectl apply -f erpnext-ingress.yaml
```

## 🚀 Initialize ERPNext Site

### 1. Create Site Initialization Job
```bash
cat > erpnext-create-site-job.yaml <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: erpnext-create-site
  namespace: erpnext
spec:
  backoffLimit: 3
  template:
    spec:
      serviceAccountName: erpnext-sa
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      initContainers:
      - name: wait-for-db
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo 'Waiting for database to be ready...'
          until nc -z \$DB_HOST \$DB_PORT; do
            echo 'Waiting for database...'
            sleep 10
          done
          echo 'Database is ready!'
          sleep 30
        envFrom:
        - configMapRef:
            name: erpnext-config
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
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-redis-secret
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
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      nodeSelector:
        node-type: worker
EOF

kubectl apply -f erpnext-create-site-job.yaml

# Monitor job progress
kubectl get jobs -n erpnext
kubectl logs -f job/erpnext-create-site -n erpnext
```

## 📊 Auto-scaling Configuration

### 1. Horizontal Pod Autoscaler
```bash
cat > erpnext-hpa.yaml <<EOF
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
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
---
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
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: erpnext-queue-default-hpa
  namespace: erpnext
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erpnext-queue-default
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 85
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: erpnext-queue-short-hpa
  namespace: erpnext
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erpnext-queue-short
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 85
EOF

kubectl apply -f erpnext-hpa.yaml
```

### 2. Cluster Autoscaler
```bash
# Enable cluster autoscaler (already configured in eksctl)
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"

# Update cluster autoscaler image version
kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=k8s.gcr.io/autoscaling/cluster-autoscaler:v1.28.2

# Verify cluster autoscaler
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```

## 🔍 Verification and Testing

### 1. Check Deployment Status
```bash
# Check all resources
kubectl get all -n erpnext

# Check deployments
kubectl get deployments -n erpnext

# Check pods
kubectl get pods -n erpnext -o wide

# Check services
kubectl get services -n erpnext

# Check ingress
kubectl get ingress -n erpnext

# Check persistent volumes
kubectl get pv,pvc -n erpnext

# Check external secrets
kubectl get externalsecrets -n erpnext

# Check HPA status
kubectl get hpa -n erpnext
```

### 2. Test Application Connectivity
```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress erpnext-ingress -n erpnext -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test frontend
curl -I http://$ALB_ENDPOINT/

# Test backend API
curl -I http://$ALB_ENDPOINT/api/method/ping

# Test Socket.IO
curl -I http://$ALB_ENDPOINT/socket.io/

# Check SSL certificate (if HTTPS is configured)
curl -I https://$ALB_ENDPOINT/
```

### 3. Database and Redis Connectivity Tests
```bash
# Test database connectivity from a pod
kubectl run mysql-test --rm -i --tty --image=mysql:8.0 --restart=Never -n erpnext -- mysql -h $DB_HOST -u admin -p

# Test Redis connectivity
kubectl run redis-test --rm -i --tty --image=redis:alpine --restart=Never -n erpnext -- redis-cli -h $REDIS_HOST ping
```

## 🗄️ Backup Strategy

### 1. Automated EFS Backup with AWS Backup
```bash
# This was configured in prerequisites, verify it's working
aws backup list-backup-jobs --by-resource-arn arn:aws:elasticfilesystem:us-east-1:$(aws sts get-caller-identity --query Account --output text):file-system/$EFS_ID
```

### 2. Database Backup CronJob
```bash
cat > erpnext-backup-cronjob.yaml <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: erpnext-backup
  namespace: erpnext
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: erpnext-sa
          restartPolicy: OnFailure
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            runAsGroup: 1000
            fsGroup: 1000
          containers:
          - name: backup
            image: frappe/erpnext-worker:v14
            command:
            - bash
            - -c
            - |
              set -e
              BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
              echo "Starting backup at \$BACKUP_DATE"
              
              # Create database backup
              bench --site frontend backup --with-files
              
              # Upload to S3 (optional)
              if [ -n "\$AWS_S3_BUCKET" ]; then
                aws s3 cp /home/frappe/frappe-bench/sites/frontend/private/backups/ s3://\$AWS_S3_BUCKET/backups/\$BACKUP_DATE/ --recursive
              fi
              
              echo "Backup completed successfully"
            envFrom:
            - configMapRef:
                name: erpnext-config
            env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: erpnext-db-secret
                  key: password
            - name: AWS_S3_BUCKET
              value: "erpnext-backups-$(aws sts get-caller-identity --query Account --output text)"
            volumeMounts:
            - name: sites-data
              mountPath: /home/frappe/frappe-bench/sites
            - name: backups-data
              mountPath: /home/frappe/frappe-bench/sites/backups
          volumes:
          - name: sites-data
            persistentVolumeClaim:
              claimName: erpnext-sites-pvc
          - name: backups-data
            persistentVolumeClaim:
              claimName: erpnext-backups-pvc
          nodeSelector:
            node-type: worker
EOF

kubectl apply -f erpnext-backup-cronjob.yaml
```

## 🛠️ Troubleshooting

### 1. Pod Issues
```bash
# Check pod status
kubectl describe pods -n erpnext

# Check pod logs
kubectl logs -f deployment/erpnext-backend -n erpnext

# Get events
kubectl get events -n erpnext --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top pods -n erpnext
kubectl top nodes
```

### 2. Storage Issues
```bash
# Check PVC status
kubectl describe pvc -n erpnext

# Check EFS mount targets
aws efs describe-mount-targets --file-system-id $EFS_ID

# Check EFS access points
aws efs describe-access-points --file-system-id $EFS_ID
```

### 3. Network Issues
```bash
# Check ingress
kubectl describe ingress erpnext-ingress -n erpnext

# Check service endpoints
kubectl get endpoints -n erpnext

# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller

# Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID"
```

### 4. External Secrets Issues
```bash
# Check external secrets status
kubectl describe externalsecrets -n erpnext

# Check secret store
kubectl describe secretstore aws-secretstore -n erpnext

# Check external secrets operator
kubectl logs -n external-secrets deployment/external-secrets
```

## 💰 Cost Optimization for EKS

### 1. Use Spot Instances
```bash
# Add spot instance node group
eksctl create nodegroup \
    --cluster=erpnext-cluster \
    --region=us-east-1 \
    --name=erpnext-workers-spot \
    --node-type=t3.medium \
    --nodes=2 \
    --nodes-min=1 \
    --nodes-max=5 \
    --spot \
    --ssh-access=false \
    --managed=true
```

### 2. Right-size Resources
```bash
# Install metrics server for resource monitoring
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Monitor resource usage
kubectl top pods -n erpnext
kubectl top nodes

# Use VPA for recommendations
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vertical-pod-autoscaler-crd.yaml
```

## 📚 Additional Resources

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [External Secrets Operator](https://external-secrets.io/)
- [EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [Kubernetes Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

## ➡️ Next Steps

1. **Production Hardening**: Follow `03-production-managed-setup.md`
2. **Monitoring Setup**: Configure Prometheus, Grafana, and CloudWatch integration
3. **CI/CD Pipeline**: Set up GitOps with ArgoCD or Flux
4. **Security**: Implement Pod Security Standards, Network Policies, and RBAC
5. **Observability**: Set up distributed tracing and logging

---

**⚠️ Important**: This deployment uses managed services and EKS cluster that incur continuous costs. Monitor your usage and optimize resource allocation based on actual requirements.