#!/bin/bash
#
# create-namespace.sh - Automate Kubernetes namespace scaffolding for fako-cluster
#
# This script generates a complete namespace structure following the established
# patterns in the fako-cluster GitOps repository.
#
# Usage:
#   ./automation/create-namespace.sh <app-name> [options]
#
# Options:
#   --with-ingress         Include ingress configuration
#   --with-secrets         Include AWS Secrets Manager integration
#   --with-storage         Include PersistentVolumeClaim
#   --with-redis           Include Redis deployment for caching
#   --image <image>        Container image (default: ghcr.io/lzetam/<app-name>:latest)
#   --port <port>          Container port (default: 8080)
#   --host <hostname>      Ingress hostname (default: <app-name>.fako-cluster.local)
#   --component <comp>     App component label (default: application)
#   --part-of <group>      Part-of label (default: <app-name>)
#   --storage-size <size>  Storage size (default: 10Gi)
#   --replicas <n>         Number of replicas (default: 1)
#   --register             Register app in staging/kustomization.yaml
#   --dry-run              Show what would be created without writing files
#
# Examples:
#   ./automation/create-namespace.sh my-api --with-ingress --with-secrets
#   ./automation/create-namespace.sh my-worker --image myorg/worker:v1.0 --with-storage
#   ./automation/create-namespace.sh my-app --with-ingress --with-secrets --register
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
APP_NAME=""
WITH_INGRESS=false
WITH_SECRETS=false
WITH_STORAGE=false
WITH_REDIS=false
IMAGE=""
PORT=8080
HOSTNAME=""
COMPONENT="application"
PART_OF=""
STORAGE_SIZE="10Gi"
REPLICAS=1
REGISTER=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    head -35 "$0" | tail -33
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-ingress)
            WITH_INGRESS=true
            shift
            ;;
        --with-secrets)
            WITH_SECRETS=true
            shift
            ;;
        --with-storage)
            WITH_STORAGE=true
            shift
            ;;
        --with-redis)
            WITH_REDIS=true
            shift
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOSTNAME="$2"
            shift 2
            ;;
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --part-of)
            PART_OF="$2"
            shift 2
            ;;
        --storage-size)
            STORAGE_SIZE="$2"
            shift 2
            ;;
        --replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --register)
            REGISTER=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$APP_NAME" ]]; then
                APP_NAME="$1"
            else
                log_error "Unexpected argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$APP_NAME" ]]; then
    log_error "App name is required"
    usage
fi

# Validate app name format
if ! [[ "$APP_NAME" =~ ^[a-z][a-z0-9-]*[a-z0-9]$|^[a-z]$ ]]; then
    log_error "App name must be lowercase alphanumeric with dashes, starting with a letter"
    exit 1
fi

# Set defaults based on app name
IMAGE="${IMAGE:-ghcr.io/lzetam/${APP_NAME}:latest}"
HOSTNAME="${HOSTNAME:-${APP_NAME}.fako-cluster.local}"
PART_OF="${PART_OF:-${APP_NAME}}"

BASE_DIR="${REPO_ROOT}/apps/base/${APP_NAME}"
STAGING_DIR="${REPO_ROOT}/apps/staging/${APP_NAME}"

log_info "Creating namespace scaffolding for: ${APP_NAME}"
log_info "Base directory: ${BASE_DIR}"
log_info "Options: ingress=$WITH_INGRESS, secrets=$WITH_SECRETS, storage=$WITH_STORAGE, redis=$WITH_REDIS"

if [[ -d "$BASE_DIR" ]]; then
    log_error "Directory already exists: ${BASE_DIR}"
    exit 1
fi

# Function to write file (respects dry-run)
write_file() {
    local path="$1"
    local content="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=== Would create: $path ==="
        echo "$content"
        echo "=== End of $path ==="
    else
        echo "$content" > "$path"
        log_success "Created: $path"
    fi
}

# Create directories
if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$BASE_DIR"
    mkdir -p "$STAGING_DIR"
    log_success "Created directories"
fi

# Generate namespace.yaml
write_file "${BASE_DIR}/namespace.yaml" "apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAME}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/part-of: ${PART_OF}"

# Generate deployment.yaml
DEPLOYMENT_CONTENT="apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAME}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/component: ${COMPONENT}
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${APP_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${APP_NAME}
    spec:
      imagePullSecrets:
        - name: dockerhub-registry
      containers:
        - name: ${APP_NAME}
          image: ${IMAGE}
          imagePullPolicy: Always
          ports:
            - containerPort: ${PORT}
              name: http"

# Add env section if secrets are enabled
if [[ "$WITH_SECRETS" == "true" ]]; then
    DEPLOYMENT_CONTENT="${DEPLOYMENT_CONTENT}
          envFrom:
            - secretRef:
                name: ${APP_NAME}-secrets"
fi

# Add volume mounts if storage is enabled
if [[ "$WITH_STORAGE" == "true" ]]; then
    DEPLOYMENT_CONTENT="${DEPLOYMENT_CONTENT}
          volumeMounts:
            - name: data
              mountPath: /data"
fi

# Add resources and probes
DEPLOYMENT_CONTENT="${DEPLOYMENT_CONTENT}
          resources:
            requests:
              memory: \"256Mi\"
              cpu: \"100m\"
            limits:
              memory: \"512Mi\"
              cpu: \"500m\"
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5"

# Add volumes if storage is enabled
if [[ "$WITH_STORAGE" == "true" ]]; then
    DEPLOYMENT_CONTENT="${DEPLOYMENT_CONTENT}
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${APP_NAME}-pvc"
fi

write_file "${BASE_DIR}/deployment.yaml" "$DEPLOYMENT_CONTENT"

# Generate service.yaml
write_file "${BASE_DIR}/service.yaml" "apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAME}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/component: ${COMPONENT}
spec:
  type: ClusterIP
  ports:
    - port: ${PORT}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: ${APP_NAME}"

# Generate ingress.yaml if requested
if [[ "$WITH_INGRESS" == "true" ]]; then
    write_file "${BASE_DIR}/ingress.yaml" "apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAME}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/component: ${COMPONENT}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - ${HOSTNAME}
      secretName: ${APP_NAME}-tls
  rules:
    - host: ${HOSTNAME}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${APP_NAME}
                port:
                  number: ${PORT}"
fi

# Generate secret-store.yaml and external-secret.yaml if requested
if [[ "$WITH_SECRETS" == "true" ]]; then
    write_file "${BASE_DIR}/secretstore.yaml" "apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: ${APP_NAME}
spec:
  provider:
    aws:
      auth:
        secretRef:
          accessKeyIDSecretRef:
            key: access-key-id
            name: aws-credentials
          secretAccessKeySecretRef:
            key: secret-access-key
            name: aws-credentials
      region: us-east-1
      service: SecretsManager"

    write_file "${BASE_DIR}/external-secret.yaml" "apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${APP_NAME}-secrets
  namespace: ${APP_NAME}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: ${APP_NAME}-secrets
    creationPolicy: Owner
  data:
    # Add your secrets here
    # Example:
    # - secretKey: API_KEY
    #   remoteRef:
    #     key: ${APP_NAME}/api-key
    #     property: key
    - secretKey: PLACEHOLDER
      remoteRef:
        key: ${APP_NAME}/config
        property: placeholder"

    write_file "${BASE_DIR}/external-secret-dockerhub.yaml" "apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: dockerhub-registry
  namespace: ${APP_NAME}
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: dockerhub-registry
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: \"{{ .dockerconfig | toString }}\"
  data:
    - secretKey: dockerconfig
      remoteRef:
        key: dockerhub/credentials
        property: dockerconfigjson"
fi

# Generate storage.yaml if requested
if [[ "$WITH_STORAGE" == "true" ]]; then
    write_file "${BASE_DIR}/storage.yaml" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP_NAME}-pvc
  namespace: ${APP_NAME}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-csi-v2
  resources:
    requests:
      storage: ${STORAGE_SIZE}"
fi

# Generate redis.yaml if requested
if [[ "$WITH_REDIS" == "true" ]]; then
    write_file "${BASE_DIR}/redis.yaml" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: ${APP_NAME}
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: ${APP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: redis
      app.kubernetes.io/part-of: ${APP_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis
        app.kubernetes.io/part-of: ${APP_NAME}
    spec:
      imagePullSecrets:
        - name: dockerhub-registry
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
              name: redis
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"50m\"
            limits:
              memory: \"128Mi\"
              cpu: \"100m\"
          livenessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 10
            periodSeconds: 5
          readinessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 5
            periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ${APP_NAME}
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: ${APP_NAME}
spec:
  type: ClusterIP
  ports:
    - port: 6379
      targetPort: redis
      protocol: TCP
      name: redis
  selector:
    app.kubernetes.io/name: redis
    app.kubernetes.io/part-of: ${APP_NAME}"
fi

# Build the resources list for kustomization.yaml
RESOURCES="  - namespace.yaml"

if [[ "$WITH_SECRETS" == "true" ]]; then
    RESOURCES="${RESOURCES}
  - secretstore.yaml
  - external-secret.yaml
  - external-secret-dockerhub.yaml"
fi

if [[ "$WITH_REDIS" == "true" ]]; then
    RESOURCES="${RESOURCES}
  - redis.yaml"
fi

if [[ "$WITH_STORAGE" == "true" ]]; then
    RESOURCES="${RESOURCES}
  - storage.yaml"
fi

RESOURCES="${RESOURCES}
  - deployment.yaml
  - service.yaml"

if [[ "$WITH_INGRESS" == "true" ]]; then
    RESOURCES="${RESOURCES}
  - ingress.yaml"
fi

# Generate base kustomization.yaml
write_file "${BASE_DIR}/kustomization.yaml" "apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${APP_NAME}

resources:
${RESOURCES}

labels:
  - pairs:
      app.kubernetes.io/name: ${APP_NAME}
      app.kubernetes.io/instance: production
      app.kubernetes.io/component: ${COMPONENT}
      app.kubernetes.io/part-of: ${PART_OF}"

# Generate staging kustomization.yaml
write_file "${STAGING_DIR}/kustomization.yaml" "apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/${APP_NAME}"

# Register in staging/kustomization.yaml if requested
if [[ "$REGISTER" == "true" && "$DRY_RUN" == "false" ]]; then
    STAGING_KUSTOMIZATION="${REPO_ROOT}/apps/staging/kustomization.yaml"
    if grep -q "^  - ${APP_NAME}$" "$STAGING_KUSTOMIZATION" 2>/dev/null; then
        log_warn "App '${APP_NAME}' is already registered in staging/kustomization.yaml"
    else
        # Add the app to the end of the resources list
        echo "  - ${APP_NAME}  # Auto-generated by create-namespace.sh" >> "$STAGING_KUSTOMIZATION"
        log_success "Registered ${APP_NAME} in apps/staging/kustomization.yaml"
    fi
elif [[ "$REGISTER" == "true" && "$DRY_RUN" == "true" ]]; then
    log_info "Would register ${APP_NAME} in apps/staging/kustomization.yaml"
fi

# Summary
echo ""
echo "============================================"
log_success "Namespace scaffolding complete!"
echo "============================================"
echo ""
echo "Created files:"
if [[ "$DRY_RUN" == "false" ]]; then
    find "$BASE_DIR" -type f -name "*.yaml" | sort | while read -r file; do
        echo "  - ${file#$REPO_ROOT/}"
    done
    find "$STAGING_DIR" -type f -name "*.yaml" | sort | while read -r file; do
        echo "  - ${file#$REPO_ROOT/}"
    done
fi
echo ""
echo "Next steps:"
echo "  1. Review and customize the generated files"
if [[ "$WITH_SECRETS" == "true" ]]; then
    echo "  2. Create AWS secrets at: ${APP_NAME}/config"
    echo "  3. Update external-secret.yaml with your secret mappings"
fi
if [[ "$REGISTER" == "false" ]]; then
    echo "  4. Add '  - ${APP_NAME}' to apps/staging/kustomization.yaml"
fi
echo "  5. Commit and push to trigger FluxCD deployment"
echo ""
