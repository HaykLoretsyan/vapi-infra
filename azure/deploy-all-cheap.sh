#!/bin/bash

# Cost-optimized deployment script for VAPI to Azure
# Optimized for single-user testing scenarios
# Estimated cost: ~$30-50/month (vs ~$95-185/month standard)

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

echo "💰 Cost-optimized Azure deployment for VAPI (single-user testing)..."
echo "   Estimated monthly cost: ~$30-50"
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

# Step 4: Setup cost-optimized databases
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

# Step 6: Deploy Keycloak (with minimal resources)
echo "🔐 Deploying Keycloak (optimized for single user)..."
./deploy-keycloak-cheap.sh

# Get Keycloak URL
KEYCLOAK_URL=$(az containerapp show --name vapi-keycloak --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
KEYCLOAK_URL="https://${KEYCLOAK_URL}"
echo "Keycloak URL: $KEYCLOAK_URL"

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to be ready..."
sleep 30

# Step 7: Deploy Backend (with minimal resources)
echo "⚙️ Deploying Backend API (optimized resources)..."
export KEYCLOAK_URL=$KEYCLOAK_URL
export MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING
# Backend already uses minimal resources (0.5 CPU, 1.0 Gi)
./deploy-backend.sh

# Get Backend URL
BACKEND_URL=$(az containerapp show --name vapi-backend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
BACKEND_URL="http://${BACKEND_URL}"
echo "Backend URL: $BACKEND_URL"

# Step 8: Deploy Usecases (with minimal resources)
echo "📊 Deploying Usecases Service (optimized resources)..."
export API_URL=$BACKEND_URL
export KEYCLOAK_URL=$KEYCLOAK_URL
export MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING
# Usecases already uses minimal resources (0.5 CPU, 1.0 Gi)
./deploy-usecases.sh

# Get Usecases URL
USECASES_URL=$(az containerapp show --name vapi-usecases --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
USECASES_URL="http://${USECASES_URL}"
echo "Usecases URL: $USECASES_URL"

# Step 9: Deploy Frontend (with minimal resources)
echo "🎨 Deploying Frontend (optimized resources)..."
export KEYCLOAK_URL=$KEYCLOAK_URL
export BACKEND_URL=$BACKEND_URL
export USECASES_URL=$USECASES_URL
./deploy-frontend.sh

# Get Frontend URL
FRONTEND_URL=$(az containerapp show --name vapi-frontend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
FRONTEND_URL="https://${FRONTEND_URL}"

echo ""
echo "✅ Cost-optimized deployment complete!"
echo ""
echo "📋 Service URLs:"
echo "  Frontend:  $FRONTEND_URL"
echo "  Backend:   $BACKEND_URL"
echo "  Usecases:  $USECASES_URL"
echo "  Keycloak:  $KEYCLOAK_URL"
echo ""
echo "💰 Estimated Monthly Costs:"
echo "  - Container Apps (Consumption): ~$10-20"
echo "  - MongoDB Container: ~$0-5"
echo "  - PostgreSQL (B1ms): ~$15"
echo "  - ACR (Basic): ~$5"
echo "  - Total: ~$30-50/month"
echo ""
echo "⚠️  Next steps:"
echo "  1. Update Keycloak client redirect URIs to include: $FRONTEND_URL"
echo "  2. Run Keycloak initialization script"
echo "  3. Monitor costs in Azure Portal"
echo ""
echo "💡 Cost-saving tips:"
echo "  - Stop services when not in use (scale to 0 replicas)"
echo "  - Use Azure Dev/Test pricing if eligible"
echo "  - Consider Azure Free Account credits ($200 for 30 days)"

