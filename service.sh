#!/bin/bash

# Kill any existing port-forwards first
pkill -f "kubectl port-forward.*openstudybuilder"

# Start all in background
kubectl port-forward -n openstudybuilder svc/frontend 5005:5005 >/dev/null 2>&1 &
kubectl port-forward -n openstudybuilder svc/api 5003:5003 >/dev/null 2>&1 &
kubectl port-forward -n openstudybuilder svc/consumerapi 5008:5008 >/dev/null 2>&1 &
kubectl port-forward -n openstudybuilder svc/documentation 5006:5006 >/dev/null 2>&1 &
kubectl port-forward -n openstudybuilder svc/neodash 5007:5007 >/dev/null 2>&1 &
kubectl port-forward -n openstudybuilder svc/pocketbase 8090:8090 >/dev/null 2>&1 &
kubectl port-forward -n openstudybuilder svc/database 7474:7474 7687:7687 5002:7687 >/dev/null 2>&1 &

echo "--- All services exposed on localhost! ---"
echo "Frontend:      http://localhost:5005"
echo "API:           http://localhost:5003"
echo "Consumer API:  http://localhost:5008"
echo "Docs:          http://localhost:5006"
echo "Neo4j Browser: http://localhost:7474"
echo "Neo4j Bolt:    bolt://localhost:7687 (or :5002)"
echo "PocketBase:    http://localhost:8090"
echo "Neodash:       http://localhost:5007"