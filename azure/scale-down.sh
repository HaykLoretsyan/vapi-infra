#!/bin/bash

# Scale down all services to save costs when not in use
# This reduces costs by ~80-90% (only pay for storage)

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}

echo "💰 Scaling down all services to save costs..."
echo "   You'll only pay for storage (~$5-10/month)"
echo ""

az containerapp update --name vapi-backend --resource-group $RESOURCE_GROUP --min-replicas 0 --max-replicas 1 || echo "Backend not found"
az containerapp update --name vapi-usecases --resource-group $RESOURCE_GROUP --min-replicas 0 --max-replicas 1 || echo "Usecases not found"
az containerapp update --name vapi-frontend --resource-group $RESOURCE_GROUP --min-replicas 0 --max-replicas 1 || echo "Frontend not found"
az containerapp update --name vapi-keycloak --resource-group $RESOURCE_GROUP --min-replicas 0 --max-replicas 1 || echo "Keycloak not found"
az containerapp update --name vapi-mongodb --resource-group $RESOURCE_GROUP --min-replicas 0 --max-replicas 1 || echo "MongoDB not found"

echo ""
echo "✅ All services scaled down!"
echo ""
echo "💡 To start services again, run: ./scale-up.sh"
echo "   First request may take 30-60 seconds to start containers"

