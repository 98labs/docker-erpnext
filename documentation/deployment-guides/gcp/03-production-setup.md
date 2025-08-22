# ERPNext GKE Production Hardening Guide

## Overview

This guide covers production-ready configurations, security hardening, monitoring, backup strategies, and operational best practices for ERPNext on GKE.

## 🔐 Security Hardening

### 1. Private GKE Cluster Setup

```bash
# Create private GKE cluster with enhanced security
gcloud container clusters create erpnext-prod \
    --zone=us-central1-a \
    --node-locations=us-central1-a,us-central1-b,us-central1-c \
    --enable-private-nodes \
    --master-ipv4-cidr-block=172.16.0.0/28 \
    --enable-ip-alias \
    --cluster-ipv4-cidr=10.1.0.0/16 \
    --services-ipv4-cidr=10.2.0.0/16 \
    --enable-network-policy \
    --enable-autoscaling \
    --min-nodes=3 \
    --max-nodes=20 \
    --machine-type=e2-standard-4 \
    --disk-type=pd-ssd \
    --disk-size=100GB \
    --enable-autorepair \
    --enable-autoupgrade \
    --maintenance-window-start=2024-01-01T03:00:00Z \
    --maintenance-window-end=2024-01-01T07:00:00Z \
    --maintenance-window-recurrence="FREQ=WEEKLY;BYDAY=SU" \
    --workload-pool=erpnext-production.svc.id.goog \
    --enable-shielded-nodes \
    --enable-image-streaming \
    --logging=SYSTEM,WORKLOAD,API_SERVER \
    --monitoring=SYSTEM,WORKLOAD,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,CADVISOR,KUBELET
```

### 2. Network Security Policies

```bash
# Deny all traffic by default
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: erpnext
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Allow ERPNext frontend to backend communication
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: erpnext-frontend-to-backend
  namespace: erpnext
spec:
  podSelector:
    matchLabels:
      app: erpnext-frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: erpnext-backend
    ports:
    - protocol: TCP
      port: 8000
  - to:
    - podSelector:
        matchLabels:
          app: erpnext-backend
    ports:
    - protocol: TCP
      port: 9000
EOF

# Allow backend to database and redis
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: erpnext-backend-to-services
  namespace: erpnext
spec:
  podSelector:
    matchLabels:
      app: erpnext-backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mariadb
    ports:
    - protocol: TCP
      port: 3306
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF

# Allow ingress from nginx controller
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx-ingress
  namespace: erpnext
spec:
  podSelector:
    matchLabels:
      app: erpnext-frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
EOF
```

### 3. Pod Security Standards

```bash
# Apply restricted pod security standards
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

# Security context for ERPNext backend
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend-secure
  namespace: erpnext
spec:
  replicas: 3
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      serviceAccountName: erpnext-ksa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          runAsGroup: 1000
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: sites-data
          mountPath: /home/frappe/frappe-bench/sites
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /home/frappe/frappe-bench/logs
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}
EOF
```

### 4. RBAC Configuration

```bash
# Create service account with minimal permissions
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: erpnext-ksa
  namespace: erpnext
  annotations:
    iam.gke.io/gcp-service-account: erpnext-gke@erpnext-production.iam.gserviceaccount.com
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: erpnext
  name: erpnext-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: erpnext-binding
  namespace: erpnext
subjects:
- kind: ServiceAccount
  name: erpnext-ksa
  namespace: erpnext
roleRef:
  kind: Role
  name: erpnext-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

## 🛡️ Secrets Management

### 1. External Secrets Operator Setup

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Create SecretStore for GCP Secret Manager
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcpsm-secret-store
  namespace: erpnext
spec:
  provider:
    gcpsm:
      projectId: "erpnext-production"
      auth:
        workloadIdentity:
          clusterLocation: us-central1-a
          clusterName: erpnext-prod
          serviceAccountRef:
            name: erpnext-ksa
EOF

# Create ExternalSecret for ERPNext credentials
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erpnext-external-secret
  namespace: erpnext
spec:
  refreshInterval: 15m
  secretStoreRef:
    name: gcpsm-secret-store
    kind: SecretStore
  target:
    name: erpnext-secrets
    creationPolicy: Owner
  data:
  - secretKey: admin-password
    remoteRef:
      key: erpnext-admin-password
  - secretKey: db-password
    remoteRef:
      key: erpnext-db-password
  - secretKey: api-key
    remoteRef:
      key: erpnext-api-key
  - secretKey: api-secret
    remoteRef:
      key: erpnext-api-secret
EOF
```

### 2. Encrypt Secrets at Rest

```bash
# Create KMS key for additional encryption
gcloud kms keyrings create erpnext-keyring --location=us-central1

gcloud kms keys create erpnext-key \
    --location=us-central1 \
    --keyring=erpnext-keyring \
    --purpose=encryption

# Update cluster to use application-layer secrets encryption
gcloud container clusters update erpnext-prod \
    --zone=us-central1-a \
    --database-encryption-key projects/erpnext-production/locations/us-central1/keyRings/erpnext-keyring/cryptoKeys/erpnext-key \
    --database-encryption-key-state=ENCRYPTED
```

## 📊 Monitoring and Observability

### 1. Install Prometheus Stack

```bash
# Add prometheus-community helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
    --set prometheus.prometheusSpec.retention=30d \
    --set grafana.adminPassword=SecurePassword123! \
    --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=10Gi
```

### 2. ERPNext Monitoring ConfigMap

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-monitoring
  namespace: erpnext
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'erpnext-backend'
      static_configs:
      - targets: ['erpnext-backend:8000']
      metrics_path: '/api/method/frappe.utils.response.get_response_length'
      scrape_interval: 30s
    - job_name: 'erpnext-queue-metrics'
      static_configs:
      - targets: ['erpnext-backend:8000']
      metrics_path: '/api/method/frappe.utils.scheduler.get_events'
      scrape_interval: 60s
EOF
```

### 3. Custom Grafana Dashboard

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: erpnext-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  erpnext-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "ERPNext Production Dashboard",
        "tags": ["erpnext"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"erpnext-backend\"}[5m])) by (le))",
                "legendFormat": "95th percentile"
              }
            ]
          },
          {
            "id": 2,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{job=\"erpnext-backend\"}[5m]))",
                "legendFormat": "Requests/sec"
              }
            ]
          },
          {
            "id": 3,
            "title": "Pod CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"erpnext\"}[5m])) by (pod)",
                "legendFormat": "{{pod}}"
              }
            ]
          },
          {
            "id": 4,
            "title": "Pod Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(container_memory_working_set_bytes{namespace=\"erpnext\"}) by (pod)",
                "legendFormat": "{{pod}}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
EOF
```

### 4. Alerting Rules

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: erpnext-alerts
  namespace: monitoring
  labels:
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: erpnext.rules
    rules:
    - alert: ERPNextHighResponseTime
      expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="erpnext-backend"}[5m])) by (le)) > 2
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "ERPNext response time is high"
        description: "95th percentile response time is {{ $value }}s"
    
    - alert: ERPNextPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="erpnext"}[5m]) > 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "ERPNext pod is crash looping"
        description: "Pod {{ $labels.pod }} is restarting frequently"
    
    - alert: ERPNextHighCPUUsage
      expr: sum(rate(container_cpu_usage_seconds_total{namespace="erpnext"}[5m])) by (pod) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "ERPNext pod high CPU usage"
        description: "Pod {{ $labels.pod }} CPU usage is {{ $value }}"
    
    - alert: ERPNextHighMemoryUsage
      expr: sum(container_memory_working_set_bytes{namespace="erpnext"}) by (pod) / sum(container_spec_memory_limit_bytes{namespace="erpnext"}) by (pod) > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "ERPNext pod high memory usage"
        description: "Pod {{ $labels.pod }} memory usage is {{ $value }}"
    
    - alert: ERPNextDatabaseDown
      expr: up{job="mariadb"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "ERPNext database is down"
        description: "MariaDB database is not responding"
EOF
```

## 🔄 Backup and Disaster Recovery

### 1. Database Backup Strategy

```bash
# Create backup job using CronJob
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: erpnext-db-backup
  namespace: erpnext
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: erpnext-ksa
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: mysql:8.0
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_FILE="erpnext_backup_\$(date +%Y%m%d_%H%M%S).sql"
              mysqldump -h mariadb -u erpnext -p\$DB_PASSWORD --single-transaction --routines --triggers erpnext > /backup/\$BACKUP_FILE
              gzip /backup/\$BACKUP_FILE
              gsutil cp /backup/\$BACKUP_FILE.gz gs://erpnext-backups/database/
              # Keep only last 30 days of backups
              find /backup -name "*.gz" -mtime +30 -delete
            env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: erpnext-secrets
                  key: db-password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
EOF
```

### 2. Site Files Backup

```bash
# Create site files backup job
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

### 3. Backup Storage Setup

```bash
# Create backup bucket with lifecycle policy
gsutil mb gs://erpnext-backups

# Set lifecycle policy
gsutil lifecycle set - gs://erpnext-backups <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 60}
      }
    ]
  }
}
EOF

# Create backup PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
  namespace: erpnext
spec:
  storageClassName: standard-retain
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
```

### 4. Disaster Recovery Plan

```bash
# Create DR restoration job template
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: erpnext-restore
  namespace: erpnext
spec:
  template:
    spec:
      serviceAccountName: erpnext-ksa
      restartPolicy: Never
      containers:
      - name: restore
        image: mysql:8.0
        command:
        - /bin/bash
        - -c
        - |
          # Download latest backup
          gsutil cp gs://erpnext-backups/database/\$BACKUP_FILE /tmp/
          gunzip /tmp/\$BACKUP_FILE
          
          # Restore database
          mysql -h mariadb -u erpnext -p\$DB_PASSWORD erpnext < /tmp/\${BACKUP_FILE%.gz}
          
          # Verify restoration
          mysql -h mariadb -u erpnext -p\$DB_PASSWORD -e "SHOW TABLES;" erpnext
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
        - name: BACKUP_FILE
          value: "erpnext_backup_20241201_020000.sql.gz"
EOF
```

## 🚀 Performance Optimization

### 1. Resource Optimization

```bash
# Vertical Pod Autoscaler for right-sizing
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: erpnext-backend-vpa
  namespace: erpnext
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erpnext-backend
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: erpnext-backend
      maxAllowed:
        cpu: 2
        memory: 4Gi
      minAllowed:
        cpu: 500m
        memory: 1Gi
EOF
```

### 2. Pod Disruption Budgets

```bash
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: erpnext-backend-pdb
  namespace: erpnext
spec:
  minAvailable: 2
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

### 3. Node Affinity and Anti-Affinity

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend-ha
  namespace: erpnext
spec:
  replicas: 3
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - erpnext-backend
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: cloud.google.com/gke-preemptible
                operator: DoesNotExist
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
EOF
```

## 🔧 Operational Procedures

### 1. Health Checks and Probes

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend-health
  namespace: erpnext
spec:
  replicas: 3
  selector:
    matchLabels:
      app: erpnext-backend
  template:
    metadata:
      labels:
        app: erpnext-backend
    spec:
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        ports:
        - containerPort: 8000
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
        startupProbe:
          httpGet:
            path: /api/method/ping
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
EOF
```

### 2. Log Aggregation

```bash
# Configure Fluentd for log collection
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-gcp
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: fluentd-gcp
  template:
    metadata:
      labels:
        k8s-app: fluentd-gcp
    spec:
      serviceAccountName: fluentd-gcp
      containers:
      - name: fluentd-gcp
        image: gcr.io/gke-release/fluentd-gcp:2.0.17-gke.0
        env:
        - name: FLUENTD_ARGS
          value: --no-supervisor -q
        resources:
          limits:
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: libsystemddir
          mountPath: /host/lib
          readOnly: true
        - name: config-volume
          mountPath: /etc/fluent/config.d
      nodeSelector:
        beta.kubernetes.io/os: linux
      tolerations:
      - operator: Exists
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: libsystemddir
        hostPath:
          path: /usr/lib64
      - name: config-volume
        configMap:
          name: fluentd-gcp-config
EOF
```

### 3. Update Strategy

```bash
# Rolling update configuration
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: erpnext-backend-rolling
  namespace: erpnext
spec:
  replicas: 5
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
        version: v14.1.0
    spec:
      containers:
      - name: erpnext-backend
        image: frappe/erpnext-worker:v14
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
EOF
```

## 🔍 Compliance and Governance

### 1. OPA Gatekeeper Policies

```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Create constraint template for required labels
kubectl apply -f - <<EOF
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        type: object
        properties:
          labels:
            type: array
            items:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("Missing required label: %v", [missing])
        }
EOF

# Apply constraint
kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: must-have-environment
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["erpnext"]
  parameters:
    labels: ["environment", "app", "version"]
EOF
```

### 2. Resource Quotas

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: erpnext-quota
  namespace: erpnext
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    pods: "20"
    services: "10"
EOF
```

## 📈 Performance Testing

### 1. Load Testing Setup

```bash
# Create load testing job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: erpnext-load-test
  namespace: erpnext
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: load-test
        image: grafana/k6:latest
        command:
        - k6
        - run
        - --vus=50
        - --duration=10m
        - -
        stdin: |
          import http from 'k6/http';
          import { check, sleep } from 'k6';
          
          export default function () {
            let response = http.get('https://erpnext.yourdomain.com/api/method/ping');
            check(response, {
              'status is 200': (r) => r.status === 200,
              'response time < 2s': (r) => r.timings.duration < 2000,
            });
            sleep(1);
          }
EOF
```

## 🚨 Incident Response

### 1. Runbook for Common Issues

```bash
# Create incident response ConfigMap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-runbooks
  namespace: erpnext
data:
  pod-crashloop.md: |
    # Pod CrashLoop Incident Response
    
    ## Investigation Steps
    1. Check pod logs: kubectl logs <pod-name> -n erpnext
    2. Check events: kubectl describe pod <pod-name> -n erpnext
    3. Check resource usage: kubectl top pod <pod-name> -n erpnext
    
    ## Common Causes
    - Database connection issues
    - Insufficient resources
    - Configuration errors
    - Image pull failures
    
    ## Resolution Steps
    1. Scale down problematic deployment
    2. Fix underlying issue
    3. Scale back up
    4. Monitor for stability
  
  high-response-time.md: |
    # High Response Time Incident Response
    
    ## Investigation Steps
    1. Check current load: kubectl top pods -n erpnext
    2. Check HPA status: kubectl get hpa -n erpnext
    3. Check database performance
    4. Review nginx access logs
    
    ## Resolution Steps
    1. Scale up if needed: kubectl scale deployment erpnext-backend --replicas=5
    2. Check database queries
    3. Clear Redis cache if needed
    4. Review and optimize slow queries
EOF
```

## 📋 Production Checklist

### Pre-Deployment Checklist

- [ ] Security hardening applied
- [ ] Network policies configured
- [ ] RBAC properly set up
- [ ] Secrets management implemented
- [ ] Monitoring stack deployed
- [ ] Backup procedures tested
- [ ] Load testing completed
- [ ] Disaster recovery plan documented
- [ ] Incident response procedures ready
- [ ] Documentation updated

### Post-Deployment Checklist

- [ ] All pods running and healthy
- [ ] Ingress working correctly
- [ ] SSL certificates issued
- [ ] Monitoring alerts configured
- [ ] Backup jobs scheduled
- [ ] Log aggregation working
- [ ] Performance metrics baseline established
- [ ] Team trained on operational procedures

## 📚 Additional Resources

- [GKE Security Best Practices](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
- [ERPNext Administration Guide](https://docs.erpnext.com/docs/user/manual/en/setting-up)
- [Prometheus Monitoring Best Practices](https://prometheus.io/docs/practices/)

---

**⚠️ Important**: Regular security audits and updates are essential for maintaining a secure production environment. Schedule quarterly reviews of all security configurations and keep up with the latest security patches.