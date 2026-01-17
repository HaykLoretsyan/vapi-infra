#!/bin/bash

# Deploy Backend API to Azure Container Apps
set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
ACR_NAME=${ACR_NAME:-vapiacr}
ENV_NAME=${ENV_NAME:-vapi-env}
APP_NAME=${APP_NAME:-vapi-backend}
VAPI_API_KEY=${VAPI_API_KEY}
KEYCLOAK_URL=${KEYCLOAK_URL}
SERVICE_AUTH_TOKEN=${SERVICE_AUTH_TOKEN}

if [ -z "$VAPI_API_KEY" ] || [ -z "$KEYCLOAK_URL" ]; then
  echo "Error: VAPI_API_KEY and KEYCLOAK_URL must be set"
  exit 1
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)

# Create Container App
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image ${ACR_LOGIN_SERVER}/vapi-backend:latest \
  --target-port 8080 \
  --ingress internal \
  --env-vars \
    "VAPI_API_KEY=$VAPI_API_KEY" \
    "VAPI_BASE_URL=${VAPI_BASE_URL:-https://api.vapi.ai}" \
    "VAPI_TIMEOUT=${VAPI_TIMEOUT:-30}" \
    "PORT=8080" \
    "KEYCLOAK_URL=$KEYCLOAK_URL" \
    "KEYCLOAK_REALM=${KEYCLOAK_REALM:-vapi}" \
    "KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-vapi-frontend}" \
    "SERVICE_AUTH_TOKEN=${SERVICE_AUTH_TOKEN}" \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 3

echo "Backend API deployed successfully!"

