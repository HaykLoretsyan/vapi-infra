#!/bin/bash

# Alternative deployment using Azure App Service
# This is simpler but less flexible than Container Apps

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
LOCATION=${LOCATION:-eastus}
APP_SERVICE_PLAN=${APP_SERVICE_PLAN:-vapi-plan}

echo "🚀 Deploying to Azure App Service..."

# Create App Service Plan
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku B1 \
  --is-linux || echo "Plan may already exist"

# Create Web Apps
echo "Creating Web Apps..."

# Backend API
az webapp create \
  --name vapi-backend-api \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --runtime "GO:1.23" || echo "Backend app may already exist"

# Usecases Service  
az webapp create \
  --name vapi-usecases-api \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --runtime "GO:1.23" || echo "Usecases app may already exist"

# Frontend
az webapp create \
  --name vapi-frontend-app \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --runtime "NODE:22-lts" || echo "Frontend app may already exist"

echo "✅ App Services created!"
echo ""
echo "Next steps:"
echo "1. Configure deployment from ACR or GitHub"
echo "2. Set environment variables"
echo "3. Configure custom domains"
echo ""
echo "Note: App Service requires different deployment approach."
echo "Consider using Container Apps for easier container deployment."

