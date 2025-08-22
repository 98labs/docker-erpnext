#!/bin/bash

# ERPNext Backup and Restore Script for GKE
# This script provides backup and restore functionality for ERPNext on GKE

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-"erpnext"}
BACKUP_BUCKET=${BACKUP_BUCKET:-"erpnext-backups"}
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project)}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if required tools are installed
    local required_tools=("kubectl" "gcloud" "gsutil")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "$tool is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create manual backup
create_backup() {
    local backup_type=${1:-"full"}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    print_status "Creating $backup_type backup at $timestamp"
    
    case $backup_type in
        "database"|"db")
            backup_database "$timestamp"
            ;;
        "files")
            backup_files "$timestamp"
            ;;
        "full")
            backup_database "$timestamp"
            backup_files "$timestamp"
            ;;
        *)
            print_error "Unknown backup type: $backup_type"
            print_status "Available types: database, files, full"
            exit 1
            ;;
    esac
    
    print_success "Backup completed successfully"
}

# Function to backup database
backup_database() {
    local timestamp=$1
    local backup_name="manual_db_backup_$timestamp"
    
    print_status "Creating database backup: $backup_name"
    
    # Create temporary job for backup
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $backup_name
  namespace: $NAMESPACE
spec:
  backoffLimit: 2
  template:
    spec:
      serviceAccountName: erpnext-ksa
      restartPolicy: Never
      containers:
      - name: backup
        image: mysql:8.0
        command:
        - /bin/bash
        - -c
        - |
          set -e
          BACKUP_FILE="erpnext_manual_backup_$timestamp.sql"
          
          echo "Starting database backup..."
          mysqldump -h mariadb -u erpnext -p\$DB_PASSWORD \
            --single-transaction \
            --routines \
            --triggers \
            --events \
            --default-character-set=utf8mb4 \
            erpnext > /backup/\$BACKUP_FILE
          
          gzip /backup/\$BACKUP_FILE
          
          if command -v gsutil &> /dev/null; then
            gsutil cp /backup/\$BACKUP_FILE.gz gs://$BACKUP_BUCKET/manual/database/
            echo "Backup uploaded to GCS"
          fi
          
          echo "Database backup completed: \$BACKUP_FILE.gz"
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

    # Wait for job to complete
    kubectl wait --for=condition=complete job/$backup_name -n "$NAMESPACE" --timeout=600s
    
    # Check if job succeeded
    if kubectl get job $backup_name -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        print_success "Database backup completed: $backup_name"
    else
        print_error "Database backup failed. Check logs:"
        kubectl logs job/$backup_name -n "$NAMESPACE"
        exit 1
    fi
    
    # Cleanup job
    kubectl delete job $backup_name -n "$NAMESPACE"
}

# Function to backup files
backup_files() {
    local timestamp=$1
    local backup_name="manual_files_backup_$timestamp"
    
    print_status "Creating files backup: $backup_name"
    
    # Create temporary job for backup
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $backup_name
  namespace: $NAMESPACE
spec:
  backoffLimit: 2
  template:
    spec:
      serviceAccountName: erpnext-ksa
      restartPolicy: Never
      containers:
      - name: files-backup
        image: google/cloud-sdk:alpine
        command:
        - /bin/bash
        - -c
        - |
          set -e
          BACKUP_FILE="erpnext_files_manual_backup_$timestamp.tar.gz"
          
          echo "Starting files backup..."
          tar -czf /tmp/\$BACKUP_FILE -C /sites .
          
          if command -v gsutil &> /dev/null; then
            gsutil cp /tmp/\$BACKUP_FILE gs://$BACKUP_BUCKET/manual/sites/
            echo "Files backup uploaded to GCS"
          else
            cp /tmp/\$BACKUP_FILE /backup/
          fi
          
          rm /tmp/\$BACKUP_FILE
          echo "Files backup completed: \$BACKUP_FILE"
        volumeMounts:
        - name: sites-data
          mountPath: /sites
          readOnly: true
        - name: backup-storage
          mountPath: /backup
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
      - name: backup-storage
        persistentVolumeClaim:
          claimName: backup-pvc
EOF

    # Wait for job to complete
    kubectl wait --for=condition=complete job/$backup_name -n "$NAMESPACE" --timeout=600s
    
    # Check if job succeeded
    if kubectl get job $backup_name -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        print_success "Files backup completed: $backup_name"
    else
        print_error "Files backup failed. Check logs:"
        kubectl logs job/$backup_name -n "$NAMESPACE"
        exit 1
    fi
    
    # Cleanup job
    kubectl delete job $backup_name -n "$NAMESPACE"
}

# Function to list backups
list_backups() {
    print_status "Listing available backups..."
    
    echo ""
    echo "=== Database Backups ==="
    gsutil ls gs://$BACKUP_BUCKET/database/ 2>/dev/null | tail -20 || echo "No database backups found"
    
    echo ""
    echo "=== Files Backups ==="
    gsutil ls gs://$BACKUP_BUCKET/sites/ 2>/dev/null | tail -20 || echo "No files backups found"
    
    echo ""
    echo "=== Manual Backups ==="
    gsutil ls gs://$BACKUP_BUCKET/manual/ 2>/dev/null | tail -20 || echo "No manual backups found"
}

# Function to restore from backup
restore_backup() {
    local backup_type=$1
    local backup_file=$2
    
    if [[ -z "$backup_file" ]]; then
        print_error "Please specify backup file to restore"
        print_status "Usage: $0 restore [database|files] [backup_file]"
        print_status "Use '$0 list' to see available backups"
        exit 1
    fi
    
    print_warning "This will restore $backup_type from $backup_file"
    print_warning "This operation will OVERWRITE existing data!"
    print_warning "Are you sure you want to continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Restore cancelled"
        exit 0
    fi
    
    case $backup_type in
        "database"|"db")
            restore_database "$backup_file"
            ;;
        "files")
            restore_files "$backup_file"
            ;;
        *)
            print_error "Unknown restore type: $backup_type"
            print_status "Available types: database, files"
            exit 1
            ;;
    esac
}

# Function to restore database
restore_database() {
    local backup_file=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local restore_job="restore-db-$timestamp"
    
    print_status "Restoring database from: $backup_file"
    
    # Scale down ERPNext pods to prevent conflicts
    print_status "Scaling down ERPNext pods..."
    kubectl scale deployment erpnext-backend --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-default --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-long --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-short --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-scheduler --replicas=0 -n "$NAMESPACE"
    
    # Wait for pods to be terminated
    sleep 30
    
    # Create restore job
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $restore_job
  namespace: $NAMESPACE
spec:
  backoffLimit: 2
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
          set -e
          
          echo "Downloading backup file..."
          gsutil cp $backup_file /tmp/backup.sql.gz
          gunzip /tmp/backup.sql.gz
          
          echo "Dropping existing database..."
          mysql -h mariadb -u root -p\$DB_PASSWORD -e "DROP DATABASE IF EXISTS erpnext;"
          mysql -h mariadb -u root -p\$DB_PASSWORD -e "CREATE DATABASE erpnext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          
          echo "Restoring database..."
          mysql -h mariadb -u erpnext -p\$DB_PASSWORD erpnext < /tmp/backup.sql
          
          echo "Database restoration completed successfully"
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: erpnext-secrets
              key: db-password
EOF

    # Wait for job to complete
    kubectl wait --for=condition=complete job/$restore_job -n "$NAMESPACE" --timeout=1200s
    
    # Check if job succeeded
    if kubectl get job $restore_job -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        print_success "Database restoration completed"
    else
        print_error "Database restoration failed. Check logs:"
        kubectl logs job/$restore_job -n "$NAMESPACE"
        exit 1
    fi
    
    # Cleanup job
    kubectl delete job $restore_job -n "$NAMESPACE"
    
    # Scale up ERPNext pods
    print_status "Scaling up ERPNext pods..."
    kubectl scale deployment erpnext-backend --replicas=3 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-default --replicas=2 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-long --replicas=1 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-short --replicas=2 -n "$NAMESPACE"
    kubectl scale deployment erpnext-scheduler --replicas=1 -n "$NAMESPACE"
    
    print_success "Database restore completed successfully"
}

# Function to restore files
restore_files() {
    local backup_file=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local restore_job="restore-files-$timestamp"
    
    print_status "Restoring files from: $backup_file"
    
    # Scale down ERPNext pods
    print_status "Scaling down ERPNext pods..."
    kubectl scale deployment erpnext-backend --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-frontend --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-default --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-long --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-short --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment erpnext-scheduler --replicas=0 -n "$NAMESPACE"
    
    # Wait for pods to be terminated
    sleep 30
    
    # Create restore job
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $restore_job
  namespace: $NAMESPACE
spec:
  backoffLimit: 2
  template:
    spec:
      serviceAccountName: erpnext-ksa
      restartPolicy: Never
      containers:
      - name: restore-files
        image: google/cloud-sdk:alpine
        command:
        - /bin/bash
        - -c
        - |
          set -e
          
          echo "Downloading backup file..."
          gsutil cp $backup_file /tmp/backup.tar.gz
          
          echo "Clearing existing files..."
          rm -rf /sites/*
          
          echo "Extracting backup..."
          tar -xzf /tmp/backup.tar.gz -C /sites/
          
          echo "Setting correct permissions..."
          chown -R 1000:1000 /sites/
          
          echo "Files restoration completed successfully"
        volumeMounts:
        - name: sites-data
          mountPath: /sites
      volumes:
      - name: sites-data
        persistentVolumeClaim:
          claimName: erpnext-sites-pvc
EOF

    # Wait for job to complete
    kubectl wait --for=condition=complete job/$restore_job -n "$NAMESPACE" --timeout=600s
    
    # Check if job succeeded
    if kubectl get job $restore_job -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        print_success "Files restoration completed"
    else
        print_error "Files restoration failed. Check logs:"
        kubectl logs job/$restore_job -n "$NAMESPACE"
        exit 1
    fi
    
    # Cleanup job
    kubectl delete job $restore_job -n "$NAMESPACE"
    
    # Scale up ERPNext pods
    print_status "Scaling up ERPNext pods..."
    kubectl scale deployment erpnext-backend --replicas=3 -n "$NAMESPACE"
    kubectl scale deployment erpnext-frontend --replicas=2 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-default --replicas=2 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-long --replicas=1 -n "$NAMESPACE"
    kubectl scale deployment erpnext-queue-short --replicas=2 -n "$NAMESPACE"
    kubectl scale deployment erpnext-scheduler --replicas=1 -n "$NAMESPACE"
    
    print_success "Files restore completed successfully"
}

# Function to setup backup bucket
setup_backup_bucket() {
    print_status "Setting up backup bucket: $BACKUP_BUCKET"
    
    # Create bucket if it doesn't exist
    if ! gsutil ls -b gs://$BACKUP_BUCKET &> /dev/null; then
        gsutil mb gs://$BACKUP_BUCKET
        print_success "Backup bucket created"
    else
        print_warning "Backup bucket already exists"
    fi
    
    # Set lifecycle policy
    gsutil lifecycle set - gs://$BACKUP_BUCKET <<EOF
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
    
    print_success "Backup bucket lifecycle policy set"
}

# Function to show backup status
show_status() {
    print_status "Backup system status..."
    
    echo ""
    echo "=== Backup CronJobs ==="
    kubectl get cronjobs -n "$NAMESPACE"
    
    echo ""
    echo "=== Recent Backup Jobs ==="
    kubectl get jobs -n "$NAMESPACE" | grep backup | tail -10
    
    echo ""
    echo "=== Backup Storage ==="
    kubectl get pvc backup-pvc -n "$NAMESPACE"
    
    echo ""
    echo "=== Backup Bucket Contents ==="
    gsutil du -sh gs://$BACKUP_BUCKET/* 2>/dev/null || echo "No backups found"
}

# Function to show help
show_help() {
    echo "ERPNext Backup and Restore Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  backup [type]           - Create manual backup (type: database, files, full)"
    echo "  restore [type] [file]   - Restore from backup"
    echo "  list                    - List available backups"
    echo "  status                  - Show backup system status"
    echo "  setup                   - Setup backup bucket and policies"
    echo "  help                    - Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE       - Kubernetes namespace (default: erpnext)"
    echo "  BACKUP_BUCKET   - GCS bucket for backups (default: erpnext-backups)"
    echo "  PROJECT_ID      - GCP Project ID"
    echo ""
    echo "Examples:"
    echo "  $0 backup database                              # Backup database only"
    echo "  $0 backup files                                 # Backup files only"
    echo "  $0 backup full                                  # Full backup"
    echo "  $0 restore database gs://bucket/backup.sql.gz  # Restore database"
    echo "  $0 restore files gs://bucket/backup.tar.gz     # Restore files"
}

# Main script logic
case "${1:-help}" in
    "backup")
        check_prerequisites
        create_backup "${2:-full}"
        ;;
    "restore")
        check_prerequisites
        restore_backup "$2" "$3"
        ;;
    "list")
        list_backups
        ;;
    "status")
        show_status
        ;;
    "setup")
        setup_backup_bucket
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac