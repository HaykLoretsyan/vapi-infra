#!/bin/bash

# Deploy Usecases Service to Azure Container Apps
set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
ACR_NAME=${ACR_NAME:-vapiacr}
ENV_NAME=${ENV_NAME:-vapi-env}
APP_NAME=${APP_NAME:-vapi-usecases}
MONGO_CONNECTION_STRING=${MONGO_CONNECTION_STRING}
API_URL=${API_URL}
KEYCLOAK_URL=${KEYCLOAK_URL}
SERVICE_AUTH_TOKEN=${SERVICE_AUTH_TOKEN}

if [ -z "$MONGO_CONNECTION_STRING" ] || [ -z "$API_URL" ] || [ -z "$KEYCLOAK_URL" ]; then
  echo "Error: MONGO_CONNECTION_STRING, API_URL, and KEYCLOAK_URL must be set"
  exit 1
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)

# Create Container App
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image ${ACR_LOGIN_SERVER}/vapi-usecases:latest \
  --target-port 8080 \
  --ingress internal \
  --env-vars \
    "MONGO_URI=$MONGO_CONNECTION_STRING" \
    "MONGO_DATABASE=${MONGO_DATABASE:-vapi}" \
    "PORT=8080" \
    "API_URL=$API_URL" \
    "KEYCLOAK_URL=$KEYCLOAK_URL" \
    "KEYCLOAK_REALM=${KEYCLOAK_REALM:-vapi}" \
    "KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-vapi-frontend}" \
    "SERVICE_AUTH_TOKEN=${SERVICE_AUTH_TOKEN}" \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 3

echo "Usecases service deployed successfully!"

