#!/bin/bash

set -e

NAMESPACE="openstudybuilder"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OpenStudyBuilder Kubernetes Deployment ===${NC}"

# Step 1: Apply namespace first
echo -e "${GREEN}[1/5] Creating namespace...${NC}"
kubectl apply -f "$SCRIPT_DIR/k8s/namespace.yaml"
sleep 2

# Step 2: Apply all other resources
echo -e "${GREEN}[2/5] Deploying all resources...${NC}"
kubectl apply -f "$SCRIPT_DIR/k8s/" 2>&1 | grep -v "kustomization.yaml" || true

# Step 3: Wait for PocketBase pod to be ready
echo -e "${GREEN}[3/5] Waiting for PocketBase pod to start...${NC}"
kubectl wait --for=condition=Ready pod -l app=pocketbase -n "$NAMESPACE" --timeout=120s || {
    echo "PocketBase pod not ready. Checking status..."
    kubectl get pods -n "$NAMESPACE" -l app=pocketbase
    kubectl describe pod -l app=pocketbase -n "$NAMESPACE" | tail -20
    exit 1
}

# Step 4: Seed PocketBase data
echo -e "${GREEN}[4/5] Seeding PocketBase data...${NC}"
POD=$(kubectl get pods -n "$NAMESPACE" -l app=pocketbase -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "ERROR: PocketBase pod not found."
    exit 1
fi

# Check if local seed data exists
if [ -f "$SCRIPT_DIR/pocketbase-db/pb_data/data.db" ]; then
    echo "Found local seed data. Copying to pod..."

    # Copy seed data to pod
    kubectl cp "$SCRIPT_DIR/pocketbase-db/pb_data/data.db" "$NAMESPACE/$POD:/pb_app/pb_data/data.db"
    kubectl cp "$SCRIPT_DIR/pocketbase-db/pb_data/auxiliary.db" "$NAMESPACE/$POD:/pb_app/pb_data/auxiliary.db"

    # Copy marker files if they exist
    [ -f "$SCRIPT_DIR/pocketbase-db/pb_data/.superuser_created" ] && \
        kubectl cp "$SCRIPT_DIR/pocketbase-db/pb_data/.superuser_created" "$NAMESPACE/$POD:/pb_app/pb_data/.superuser_created"
    [ -f "$SCRIPT_DIR/pocketbase-db/pb_data/.admin_created" ] && \
        kubectl cp "$SCRIPT_DIR/pocketbase-db/pb_data/.admin_created" "$NAMESPACE/$POD:/pb_app/pb_data/.admin_created"

    echo "Restarting PocketBase to load seed data..."
    kubectl rollout restart deployment/pocketbase -n "$NAMESPACE"
    kubectl wait --for=condition=Ready pod -l app=pocketbase -n "$NAMESPACE" --timeout=120s

    echo "PocketBase seed data loaded successfully."
else
    echo "No local seed data found at $SCRIPT_DIR/pocketbase-db/pb_data/data.db"
    echo "PocketBase will start with empty database."
fi

# Step 5: Wait for all pods
echo -e "${GREEN}[5/5] Waiting for all pods to be ready...${NC}"
kubectl wait --for=condition=Ready pod --all -n "$NAMESPACE" --timeout=300s || true

echo ""
echo -e "${BLUE}=== Deployment Complete ===${NC}"
echo ""
kubectl get pods -n "$NAMESPACE"
echo ""
echo "To access services, run:"
echo "  bash service.sh"
