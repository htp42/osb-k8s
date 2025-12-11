# OpenStudyBuilder Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the OpenStudyBuilder application.

## Architecture Overview

```
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                        Ingress                               │
                                    │  openstudybuilder.local                                      │
                                    └──────┬──────┬──────┬───────┬───────┬───────┬───────────────┘
                                           │      │      │       │       │       │
                    ┌──────────────────────┼──────┼──────┼───────┼───────┼───────┼─────────────────┐
                    │                      │      │      │       │       │       │                 │
                    │    /                 │ /api │/cons-│ /doc  │/neod- │ /pb   │                 │
                    │                      │      │umer  │       │ ash   │       │                 │
                    │                      │      │ -api │       │       │       │                 │
                    ▼                      ▼      ▼      ▼       ▼       ▼       │                 │
              ┌──────────┐          ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
              │ Frontend │          │   API    │ │Consumer  │ │  Docs    │ │ NeoDash  │            │
              │  :5005   │          │  :5003   │ │API :5008 │ │  :5006   │ │  :5007   │            │
              └──────────┘          └────┬─────┘ └────┬─────┘ └──────────┘ └────┬─────┘            │
                    │                    │            │                        │                   │
                    │                    │            │                        │                   │
                    │                    ▼            ▼                        ▼                   │
                    │               ┌─────────────────────────────────────────────┐               │
                    │               │                Neo4j Database               │               │
                    │               │            (StatefulSet :7687)              │               │
                    │               └─────────────────────────────────────────────┘               │
                    │                                                                              │
                    │               ┌─────────────────────────────────────────────┐               │
                    └──────────────►│              PocketBase Auth                │               │
                                    │                  :8090                      │               │
                                    └─────────────────────────────────────────────┘               │
                    └─────────────────────────────────────────────────────────────────────────────┘
                                              Namespace: openstudybuilder
```

## Prerequisites

1. **Kubernetes cluster** (minikube, kind, EKS, GKE, AKS, etc.)
2. **kubectl** configured to communicate with your cluster
3. **Nginx Ingress Controller** installed (or modify ingress.yaml for your ingress controller)
4. **Docker images** built and pushed to a registry accessible by your cluster

## Quick Start

### 1. Build and Push Docker Images

First, build all the Docker images from the project root:

```bash
# Build API image
docker build -t your-registry/osb-api:latest -f clinical-mdr-api/Dockerfile clinical-mdr-api/

# Build Frontend image
docker build -t your-registry/osb-frontend:latest -f studybuilder/Dockerfile studybuilder/

# Build Documentation image
docker build -t your-registry/osb-documentation:latest -f documentation-portal/Dockerfile documentation-portal/

# Build NeoDash image
docker build -t your-registry/osb-neodash:latest -f osb-neodash/Dockerfile osb-neodash/

# Build PocketBase image
docker build -t your-registry/osb-pocketbase:latest -f pocketbase/Dockerfile pocketbase/

# Push images to your registry
docker push your-registry/osb-api:latest
docker push your-registry/osb-frontend:latest
docker push your-registry/osb-documentation:latest
docker push your-registry/osb-neodash:latest
docker push your-registry/osb-pocketbase:latest
```

### 2. Update Image References

Edit [kustomization.yaml](kustomization.yaml) to use your actual image references:

```yaml
images:
  - name: osb-api
    newName: your-registry/osb-api
    newTag: latest
  - name: osb-frontend
    newName: your-registry/osb-frontend
    newTag: latest
  # ... etc
```

### 3. Update Secrets

Edit [secrets.yaml](secrets.yaml) to set your actual credentials:

```yaml
stringData:
  NEO4J_PASSWORD: "your-secure-password"
  NEO4J_AUTH: "neo4j/your-secure-password"
  AWS_ACCESS_KEY_ID: "your-aws-key"
  AWS_SECRET_ACCESS_KEY: "your-aws-secret"
```

### 4. Update ConfigMap

Edit [configmap.yaml](configmap.yaml) if needed for your environment.

### 5. Update Ingress Host

Edit [ingress.yaml](ingress.yaml) to use your actual domain:

```yaml
spec:
  rules:
    - host: your-domain.com
```

### 6. Deploy to Kubernetes

```bash
# Using kustomize (recommended)
kubectl apply -k k8s/

# Or apply files individually
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/database.yaml
kubectl apply -f k8s/pocketbase.yaml
kubectl apply -f k8s/api.yaml
kubectl apply -f k8s/consumerapi.yaml
kubectl apply -f k8s/documentation.yaml
kubectl apply -f k8s/neodash.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/ingress.yaml
```

### 7. Verify Deployment

```bash
# Check all resources
kubectl get all -n openstudybuilder

# Check pods status
kubectl get pods -n openstudybuilder -w

# Check logs for a specific service
kubectl logs -n openstudybuilder deployment/api -f

# Check ingress
kubectl get ingress -n openstudybuilder
```

## Local Development with Minikube

```bash
# Start minikube
minikube start --memory=8192 --cpus=4

# Enable ingress addon
minikube addons enable ingress

# Build images in minikube's Docker daemon
eval $(minikube docker-env)

# Build images (they'll be available directly in minikube)
docker build -t osb-api:latest -f clinical-mdr-api/Dockerfile clinical-mdr-api/
docker build -t osb-frontend:latest -f studybuilder/Dockerfile studybuilder/
docker build -t osb-documentation:latest -f documentation-portal/Dockerfile documentation-portal/
docker build -t osb-neodash:latest -f osb-neodash/Dockerfile osb-neodash/
docker build -t osb-pocketbase:latest -f pocketbase/Dockerfile pocketbase/

# Deploy
kubectl apply -k k8s/

# Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts on Windows)
echo "$(minikube ip) openstudybuilder.local" | sudo tee -a /etc/hosts

# Access the application
open http://openstudybuilder.local
```

## File Structure

```
k8s/
├── namespace.yaml      # Kubernetes namespace
├── configmap.yaml      # Non-sensitive configuration
├── secrets.yaml        # Sensitive credentials (passwords, keys)
├── pvc.yaml           # Persistent Volume Claims for databases
├── database.yaml      # Neo4j StatefulSet and Services
├── api.yaml           # Clinical MDR API Deployment and Service
├── consumerapi.yaml   # Consumer API Deployment and Service
├── frontend.yaml      # Frontend Deployment and Service
├── documentation.yaml # Documentation Portal Deployment and Service
├── neodash.yaml       # NeoDash Deployment and Service
├── pocketbase.yaml    # PocketBase Auth Deployment and Service
├── ingress.yaml       # Ingress rules for external access
├── kustomization.yaml # Kustomize configuration
└── README.md          # This file
```

## Configuration

### Environment Variables

Key environment variables are managed via ConfigMap ([configmap.yaml](configmap.yaml)):

| Variable | Description | Default |
|----------|-------------|---------|
| `NEO4J_DSN` | Neo4j connection string | `bolt://neo4j:password@database:7687/mdrdb` |
| `POCKETBASE_PUBLIC_URL` | PocketBase URL | `http://pocketbase:8090` |
| `OAUTH_ENABLED` | Enable OAuth authentication | `false` |
| `OAUTH_RBAC_ENABLED` | Enable OAuth RBAC | `false` |

### Secrets

Sensitive data is managed via Secrets ([secrets.yaml](secrets.yaml)):

| Secret | Description |
|--------|-------------|
| `NEO4J_PASSWORD` | Neo4j database password |
| `NEO4J_AUTH` | Neo4j authentication string |
| `AWS_ACCESS_KEY_ID` | AWS access key (for backups) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key (for backups) |

### Storage

Persistent Volume Claims ([pvc.yaml](pvc.yaml)):

| PVC | Size | Purpose |
|-----|------|---------|
| `neo4j-data-pvc` | 10Gi | Neo4j database files |
| `neo4j-logs-pvc` | 2Gi | Neo4j logs |
| `pocketbase-data-pvc` | 1Gi | PocketBase SQLite database |
| `neo4j-backup-pvc` | 20Gi | Neo4j backups |

## Scaling

```bash
# Scale API replicas
kubectl scale deployment/api -n openstudybuilder --replicas=3

# Scale Consumer API replicas
kubectl scale deployment/consumerapi -n openstudybuilder --replicas=2
```

Note: Neo4j and PocketBase should remain at 1 replica due to database constraints.

## Troubleshooting

### Pods not starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n openstudybuilder

# Check logs
kubectl logs <pod-name> -n openstudybuilder
```

### Database connection issues

```bash
# Verify database is running
kubectl get pods -n openstudybuilder -l app=database

# Check database logs
kubectl logs -n openstudybuilder statefulset/database

# Test connectivity from another pod
kubectl exec -it deployment/api -n openstudybuilder -- nc -zv database 7687
```

### Ingress not working

```bash
# Check ingress status
kubectl describe ingress openstudybuilder-ingress -n openstudybuilder

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## Cleanup

```bash
# Delete all resources
kubectl delete -k k8s/

# Or delete namespace (removes everything in it)
kubectl delete namespace openstudybuilder
```

## Production Considerations

1. **Use proper secrets management** (HashiCorp Vault, AWS Secrets Manager, etc.)
2. **Configure resource limits** appropriately for your workload
3. **Set up monitoring** (Prometheus, Grafana)
4. **Configure TLS** for ingress (cert-manager recommended)
5. **Set up backup jobs** for Neo4j and PocketBase data
6. **Consider using Helm** for more complex deployments
7. **Use proper storage classes** for your cloud provider
