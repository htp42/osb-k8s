# OpenStudyBuilder Kubernetes Deployment

## Prerequisites

- Kubernetes cluster (minikube, Docker Desktop, or cloud provider)
- kubectl configured to access your cluster
- Bash shell (WSL2 on Windows, or native Linux/macOS)

## Fresh Start (New Machine)

```bash
# 1. Start your Kubernetes cluster
minikube start          # For minikube
# OR
# Docker Desktop: Enable Kubernetes in settings

# 2. Clone/copy this repository

# 3. Deploy everything (including PocketBase seed data)
bash deploy.sh

# 4. Access services
bash service.sh
```

## Quick Start

### Deploy (Recommended)

Use the deploy script which handles namespace creation and PocketBase data seeding automatically:

```bash
./deploy.sh
```

### Manual Deploy

```bash
# Apply namespace first, then all resources
kubectl apply -f k8s/namespace.yaml
sleep 2
kubectl apply -f k8s/
```

If you get "namespace not found" errors, run the apply command again.

### Check Status

```bash
kubectl get pods -n openstudybuilder -w
```

Wait until all pods show `Running` and `READY 1/1`.

### Access Services

Run the port-forward script:

```bash
./service.sh
```

Services will be available at:

| Service       | URL                        |
|---------------|----------------------------|
| Frontend      | http://localhost:5005      |
| API           | http://localhost:5003      |
| Consumer API  | http://localhost:5008      |
| Documentation | http://localhost:5006      |
| Neo4j Browser | http://localhost:7474      |
| Neo4j Bolt    | bolt://localhost:7687      |
| PocketBase    | http://localhost:8090      |
| Neodash       | http://localhost:5007      |

## PocketBase Database

The `deploy.sh` script automatically seeds PocketBase with data from `pocketbase-db/pb_data/` on first deployment. This includes the superuser and collection schemas.

### Manual Data Seeding

If you need to manually seed the data:

```bash
# Get the pod name
POD=$(kubectl get pods -n openstudybuilder -l app=pocketbase -o jsonpath='{.items[0].metadata.name}')

# Copy seed data
kubectl cp ./pocketbase-db/pb_data/data.db openstudybuilder/$POD:/pb_app/pb_data/data.db
kubectl cp ./pocketbase-db/pb_data/auxiliary.db openstudybuilder/$POD:/pb_app/pb_data/auxiliary.db

# Restart to load data
kubectl rollout restart deployment/pocketbase -n openstudybuilder
```

### Reset PocketBase Data

To reset PocketBase to the seed data:

```bash
# Delete the PVC and redeploy
kubectl delete pvc pocketbase-data-pvc -n openstudybuilder
kubectl apply -f k8s/pvc.yaml
kubectl rollout restart deployment/pocketbase -n openstudybuilder

# Re-seed the data
./deploy.sh
```

## Teardown

```bash
# Delete all resources
kubectl delete -f k8s/

# Or delete the entire namespace
kubectl delete namespace openstudybuilder
```

## Troubleshooting

### Namespace not found errors

This is a race condition during first deploy. Simply run `kubectl apply -f k8s/` again, or use `./deploy.sh` which handles this automatically.

### PocketBase pod not starting

Check pod status and logs:

```bash
kubectl describe pod -l app=pocketbase -n openstudybuilder
kubectl logs -l app=pocketbase -n openstudybuilder
```

### Pod stuck in Pending

Check PVC status:

```bash
kubectl get pvc -n openstudybuilder
```

If PVC is `Pending`, ensure your cluster has a default StorageClass:

```bash
kubectl get storageclass
```

### Kustomization error

The error about `kustomization.yaml` can be ignored when using `kubectl apply -f`. That file is for `kubectl apply -k` (Kustomize).

## Architecture

```
openstudybuilder namespace
├── frontend (React app)
├── api (Backend API)
├── consumerapi (Consumer API)
├── database (Neo4j StatefulSet)
├── pocketbase (Auth service with SQLite)
├── neodash (Neo4j dashboard)
└── documentation (Docs server)
```

## Minikube Notes

For minikube users:

```bash
# Start minikube
minikube start

# Deploy
./deploy.sh

# Access services via port-forward
./service.sh
```
