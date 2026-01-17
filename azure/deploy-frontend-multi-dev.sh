#!/bin/bash

# Multi-developer optimized Frontend deployment
# Frontend can handle multiple users with same resources, but allows auto-scaling

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
ACR_NAME=${ACR_NAME:-vapiacr}
ENV_NAME=${ENV_NAME:-vapi-env}
APP_NAME=${APP_NAME:-vapi-frontend}
KEYCLOAK_URL=${KEYCLOAK_URL}
BACKEND_URL=${BACKEND_URL}
USECASES_URL=${USECASES_URL}

if [ -z "$KEYCLOAK_URL" ] || [ -z "$BACKEND_URL" ] || [ -z "$USECASES_URL" ]; then
  echo "Error: KEYCLOAK_URL, BACKEND_URL, and USECASES_URL must be set"
  exit 1
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)

# Get service URLs for nginx configuration
BACKEND_FQDN=$(az containerapp show --name vapi-backend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv 2>/dev/null || echo "")
USECASES_FQDN=$(az containerapp show --name vapi-usecases --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv 2>/dev/null || echo "")

# Build frontend with environment variables
cd ../../vapi-frontend

# Create nginx config for Azure (if services are available)
if [ -n "$BACKEND_FQDN" ] && [ -n "$USECASES_FQDN" ]; then
  # Copy Azure-specific nginx config
  cp ../infra/azure/nginx-azure.conf nginx.conf
  # Update with actual FQDNs
  sed -i "s|http://vapi-backend:8080|http://${BACKEND_FQDN}|g" nginx.conf
  sed -i "s|http://vapi-usecases:8080|http://${USECASES_FQDN}|g" nginx.conf
fi

az acr build \
  --registry $ACR_NAME \
  --image vapi-frontend:latest \
  --file Dockerfile \
  --build-arg VITE_KEYCLOAK_URL=$KEYCLOAK_URL \
  --build-arg VITE_KEYCLOAK_REALM=${KEYCLOAK_REALM:-vapi} \
  --build-arg VITE_KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-vapi-frontend} \
  --build-arg VITE_API_BASE_URL=/api \
  --build-arg VITE_USECASES_BASE_URL=/usecases \
  .

cd ../infra/azure

# Create Container App with moderate resources and auto-scaling
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image ${ACR_LOGIN_SERVER}/vapi-frontend:latest \
  --target-port 80 \
  --ingress external \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 2 \
  || az containerapp update \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --cpu 0.5 \
    --memory 1.0Gi \
    --min-replicas 1 \
    --max-replicas 2

echo "✅ Multi-developer optimized Frontend deployed!"
echo "   Resources: 0.5 CPU, 1.0 Gi (supports multiple concurrent users)"
echo "Get the URL with: az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv"

