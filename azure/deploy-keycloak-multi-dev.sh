#!/bin/bash

# Multi-developer optimized Keycloak deployment
# Uses moderate resources (1.0 CPU, 2.0 Gi) for 3-4 concurrent users

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
ACR_NAME=${ACR_NAME:-vapiacr}
ENV_NAME=${ENV_NAME:-vapi-env}
APP_NAME=${APP_NAME:-vapi-keycloak}
POSTGRES_HOST=${POSTGRES_HOST:-vapi-postgres.postgres.database.azure.com}
POSTGRES_DB=${POSTGRES_DB:-keycloak}
POSTGRES_USER=${POSTGRES_USER:-keycloak}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
KEYCLOAK_HOSTNAME=${KEYCLOAK_HOSTNAME}

if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$KEYCLOAK_ADMIN_PASSWORD" ] || [ -z "$KEYCLOAK_HOSTNAME" ]; then
  echo "Error: POSTGRES_PASSWORD, KEYCLOAK_ADMIN_PASSWORD, and KEYCLOAK_HOSTNAME must be set"
  exit 1
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)

# Import Keycloak image to ACR (or use public image)
az acr import \
  --name $ACR_NAME \
  --source quay.io/keycloak/keycloak:26.0 \
  --image keycloak:26.0 || echo "Image may already exist"

# Create Container App with moderate resources for multiple developers
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image ${ACR_LOGIN_SERVER}/keycloak:26.0 \
  --target-port 8081 \
  --ingress external \
  --env-vars \
    "KC_HOSTNAME=$KEYCLOAK_HOSTNAME" \
    "KC_HOSTNAME_STRICT=false" \
    "KC_HOSTNAME_STRICT_HTTPS=false" \
    "KC_HTTP_ENABLED=true" \
    "KC_HTTP_PORT=8081" \
    "KC_BOOTSTRAP_ADMIN_USERNAME=$KEYCLOAK_ADMIN" \
    "KC_BOOTSTRAP_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD" \
    "KC_HEALTH_ENABLED=true" \
    "KC_DB=postgres" \
    "KC_DB_URL=jdbc:postgresql://${POSTGRES_HOST}:5432/${POSTGRES_DB}?sslmode=require" \
    "KC_DB_USERNAME=${POSTGRES_USER}@${POSTGRES_HOST%%.*}" \
    "KC_DB_PASSWORD=$POSTGRES_PASSWORD" \
    "JAVA_OPTS=-Xms1024m -Xmx1536m" \
  --command "/bin/bash" \
  --args "-c" "/opt/keycloak/bin/kc.sh build --db postgres && /opt/keycloak/bin/kc.sh start" \
  --cpu 1.0 \
  --memory 2.0Gi \
  --min-replicas 1 \
  --max-replicas 2 \
  || az containerapp update \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --cpu 1.0 \
    --memory 2.0Gi \
    --min-replicas 1 \
    --max-replicas 2

echo "✅ Multi-developer optimized Keycloak deployed!"
echo "   Resources: 1.0 CPU, 2.0 Gi (supports 3-4 concurrent users)"
echo "Get the URL with: az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv"

