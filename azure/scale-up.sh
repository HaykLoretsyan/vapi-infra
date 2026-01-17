#!/bin/bash

# Scale up all services after scaling down
# Services will start automatically on first request

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}

echo "🚀 Scaling up all services..."
echo ""

az containerapp update --name vapi-backend --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 1 || echo "Backend not found"
az containerapp update --name vapi-usecases --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 1 || echo "Usecases not found"
az containerapp update --name vapi-frontend --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 1 || echo "Frontend not found"
az containerapp update --name vapi-keycloak --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 1 || echo "Keycloak not found"
az containerapp update --name vapi-mongodb --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 1 || echo "MongoDB not found"

echo ""
echo "✅ All services scaled up!"
echo ""
echo "⏳ Services will be ready in 30-60 seconds"
echo "💡 First request may be slow as containers start"

