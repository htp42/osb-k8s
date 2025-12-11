#!/bin/bash

set -e

NAMESPACE="openstudybuilder"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== OpenStudyBuilder Kubernetes Deployment ==="

# Step 1: Apply namespace first
echo "[1/5] Creating namespace..."
kubectl apply -f "$SCRIPT_DIR/k8s/namespace.yaml"
sleep 2

# Step 2: Apply all other resources
echo "[2/5] Deploying all resources..."
kubectl apply -f "$SCRIPT_DIR/k8s/" 2>&1 | grep -v "kustomization.yaml" || true

# Step 3: Wait for PocketBase pod to be ready
echo "[3/5] Waiting for PocketBase pod to start..."
kubectl wait --for=condition=Ready pod -l app=pocketbase -n "$NAMESPACE" --timeout=120s || true

# Step 4: Seed PocketBase data
echo "[4/5] Seeding PocketBase data..."
POD=$(kubectl get pods -n "$NAMESPACE" -l app=pocketbase -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "ERROR: PocketBase pod not found. Check pod status with: kubectl get pods -n $NAMESPACE"
    exit 1
fi

# Check local seed data size vs pod data size
LOCAL_SIZE=$(stat -c%s "$SCRIPT_DIR/pocketbase-db/pb_data/data.db" 2>/dev/null || stat -f%z "$SCRIPT_DIR/pocketbase-db/pb_data/data.db" 2>/dev/null)
POD_SIZE=$(kubectl exec -n "$NAMESPACE" "$POD" -- stat -c%s /pb_app/pb_data/data.db 2>/dev/null || echo "0")

echo "Local data.db size: $LOCAL_SIZE bytes"
echo "Pod data.db size: $POD_SIZE bytes"

if [ "$LOCAL_SIZE" != "$POD_SIZE" ]; then
    echo "Data differs. Copying seed data to pod..."

    # Scale down to stop writes
    kubectl scale deployment pocketbase -n "$NAMESPACE" --replicas=0
    sleep 5

    # Scale back up to get fresh pod
    kubectl scale deployment pocketbase -n "$NAMESPACE" --replicas=1
    kubectl wait --for=condition=Ready pod -l app=pocketbase -n "$NAMESPACE" --timeout=120s

    # Get new pod name
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=pocketbase -o jsonpath='{.items[0].metadata.name}')

    # Copy seed data
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
else
    echo "PocketBase data already matches seed data."
fi

# Step 5: Wait for all pods
echo "[5/5] Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready pod --all -n "$NAMESPACE" --timeout=300s || true

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Check pod status:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "To access services, run:"
echo "  ./service.sh"
