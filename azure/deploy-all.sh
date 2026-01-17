#!/bin/bash

# Complete deployment script for VAPI to Azure
# This script deploys all services in the correct order

set -e

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Configuration
RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
LOCATION=${LOCATION:-eastus}
ACR_NAME=${ACR_NAME:-vapiacr}
ENV_NAME=${ENV_NAME:-vapi-env}

echo "🚀 Starting Azure deployment for VAPI..."

# Step 1: Create Resource Group
echo "📦 Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION || echo "Resource group already exists"

# Step 2: Create ACR
echo "🐳 Creating Azure Container Registry..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic || echo "ACR already exists"
az acr login --name $ACR_NAME

# Step 3: Create Container Apps Environment
echo "🌐 Creating Container Apps environment..."
az containerapp env create \
  --name $ENV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION || echo "Environment already exists"

# Step 4: Build and push images
echo "🔨 Building and pushing Docker images..."
cd ../..

# Build backend API
echo "Building backend API..."
az acr build --registry $ACR_NAME --image vapi-backend:latest --file vapi-backend/Dockerfile.api vapi-backend/

# Build usecases service
echo "Building usecases service..."
az acr build --registry $ACR_NAME --image vapi-usecases:latest --file vapi-backend/Dockerfile.usecases vapi-backend/

cd infra/azure

# Step 5: Deploy Keycloak
echo "🔐 Deploying Keycloak..."
./deploy-keycloak.sh

# Get Keycloak URL
KEYCLOAK_URL=$(az containerapp show --name vapi-keycloak --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
KEYCLOAK_URL="https://${KEYCLOAK_URL}"
echo "Keycloak URL: $KEYCLOAK_URL"

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to be ready..."
sleep 30

# Step 6: Deploy Backend
echo "⚙️ Deploying Backend API..."
export KEYCLOAK_URL=$KEYCLOAK_URL
./deploy-backend.sh

# Get Backend URL
BACKEND_URL=$(az containerapp show --name vapi-backend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
BACKEND_URL="http://${BACKEND_URL}"
echo "Backend URL: $BACKEND_URL"

# Step 7: Deploy Usecases
echo "📊 Deploying Usecases Service..."
export API_URL=$BACKEND_URL
export KEYCLOAK_URL=$KEYCLOAK_URL
./deploy-usecases.sh

# Get Usecases URL
USECASES_URL=$(az containerapp show --name vapi-usecases --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
USECASES_URL="http://${USECASES_URL}"
echo "Usecases URL: $USECASES_URL"

# Step 8: Deploy Frontend
echo "🎨 Deploying Frontend..."
export KEYCLOAK_URL=$KEYCLOAK_URL
export BACKEND_URL=$BACKEND_URL
export USECASES_URL=$USECASES_URL
./deploy-frontend.sh

# Get Frontend URL
FRONTEND_URL=$(az containerapp show --name vapi-frontend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
FRONTEND_URL="https://${FRONTEND_URL}"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Service URLs:"
echo "  Frontend:  $FRONTEND_URL"
echo "  Backend:   $BACKEND_URL"
echo "  Usecases:  $USECASES_URL"
echo "  Keycloak:  $KEYCLOAK_URL"
echo ""
echo "⚠️  Next steps:"
echo "  1. Update Keycloak client redirect URIs to include: $FRONTEND_URL"
echo "  2. Run Keycloak initialization script"
echo "  3. Configure custom domains (optional)"
echo "  4. Set up SSL certificates"

