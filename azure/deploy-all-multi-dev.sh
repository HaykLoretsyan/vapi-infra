#!/bin/bash

# Multi-developer optimized deployment script for VAPI to Azure
# Optimized for 3-4 developers testing simultaneously
# Estimated cost: ~$50-70/month (vs ~$95-185/month standard)

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

echo "👥 Multi-developer optimized Azure deployment for VAPI..."
echo "   Optimized for 3-4 developers testing simultaneously"
echo "   Estimated monthly cost: ~$50-70"
echo ""

# Step 1: Create Resource Group
echo "📦 Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION || echo "Resource group already exists"

# Step 2: Create ACR (Basic tier - cheapest)
echo "🐳 Creating Azure Container Registry (Basic tier)..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic || echo "ACR already exists"
az acr login --name $ACR_NAME

# Step 3: Create Container Apps Environment (Consumption plan - pay-per-use)
echo "🌐 Creating Container Apps environment (Consumption plan)..."
az containerapp env create \
  --name $ENV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION || echo "Environment already exists"

# Step 4: Setup cost-optimized databases (MongoDB container, cheapest PostgreSQL)
echo "💾 Setting up cost-optimized databases..."
./setup-databases-cheap.sh

# Load database connection strings
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Step 5: Build and push images
echo "🔨 Building and pushing Docker images..."
cd ../..

# Build backend API
echo "Building backend API..."
az acr build --registry $ACR_NAME --image vapi-backend:latest --file vapi-backend/Dockerfile.api vapi-backend/

# Build usecases service
echo "Building usecases service..."
az acr build --registry $ACR_NAME --image vapi-usecases:latest --file vapi-backend/Dockerfile.usecases vapi-backend/

cd infra/azure

# Step 6: Deploy Keycloak (with moderate resources for multiple users)
echo "🔐 Deploying Keycloak (optimized for 3-4 developers)..."
./deploy-keycloak-multi-dev.sh

# Get Keycloak URL
KEYCLOAK_URL=$(az containerapp show --name vapi-keycloak --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
KEYCLOAK_URL="https://${KEYCLOAK_URL}"
echo "Keycloak URL: $KEYCLOAK_URL"

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to be ready..."
sleep 30

# Step 7: Deploy Backend (with moderate resources)
echo "⚙️ Deploying Backend API (optimized for multiple developers)..."
export KEYCLOAK_URL=$KEYCLOAK_URL
export MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING
./deploy-backend-multi-dev.sh

# Get Backend URL
BACKEND_URL=$(az containerapp show --name vapi-backend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
BACKEND_URL="http://${BACKEND_URL}"
echo "Backend URL: $BACKEND_URL"

# Step 8: Deploy Usecases (with moderate resources)
echo "📊 Deploying Usecases Service (optimized for multiple developers)..."
export API_URL=$BACKEND_URL
export KEYCLOAK_URL=$KEYCLOAK_URL
export MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING
./deploy-usecases-multi-dev.sh

# Get Usecases URL
USECASES_URL=$(az containerapp show --name vapi-usecases --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
USECASES_URL="http://${USECASES_URL}"
echo "Usecases URL: $USECASES_URL"

# Step 9: Deploy Frontend (with moderate resources)
echo "🎨 Deploying Frontend (optimized for multiple developers)..."
export KEYCLOAK_URL=$KEYCLOAK_URL
export BACKEND_URL=$BACKEND_URL
export USECASES_URL=$USECASES_URL
./deploy-frontend-multi-dev.sh

# Get Frontend URL
FRONTEND_URL=$(az containerapp show --name vapi-frontend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
FRONTEND_URL="https://${FRONTEND_URL}"

echo ""
echo "✅ Multi-developer optimized deployment complete!"
echo ""
echo "📋 Service URLs:"
echo "  Frontend:  $FRONTEND_URL"
echo "  Backend:   $BACKEND_URL"
echo "  Usecases:  $USECASES_URL"
echo "  Keycloak:  $KEYCLOAK_URL"
echo ""
echo "💰 Estimated Monthly Costs:"
echo "  - Container Apps (Consumption): ~$20-35"
echo "  - MongoDB Container: ~$0-5"
echo "  - PostgreSQL (B1ms): ~$15"
echo "  - ACR (Basic): ~$5"
echo "  - Total: ~$50-70/month"
echo ""
echo "⚠️  Next steps:"
echo "  1. Update Keycloak client redirect URIs to include: $FRONTEND_URL"
echo "  2. Run Keycloak initialization script"
echo "  3. Monitor performance and scale up if needed"
echo ""
echo "💡 Resource allocation:"
echo "  - Backend/Usecases: 0.75 CPU, 1.5 Gi (vs 0.5 CPU, 1.0 Gi single-user)"
echo "  - Keycloak: 1.0 CPU, 2.0 Gi (vs 0.5 CPU, 1.0 Gi single-user)"
echo "  - Frontend: 0.5 CPU, 1.0 Gi (same as single-user)"
echo "  - Max replicas: 2 (allows some auto-scaling)"

