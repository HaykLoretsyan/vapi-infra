# Quick Start: Deploy to Azure in 15 Minutes

This is a simplified guide to get you up and running quickly.

## Prerequisites Check

```bash
# Verify Azure CLI is installed and you're logged in
az --version
az account show

# If not logged in:
az login
```

## Step-by-Step Deployment

### 1. Set Variables

```bash
export RESOURCE_GROUP=vapi-rg
export LOCATION=eastus
export ACR_NAME=vapiacr  # Must be globally unique - change this!
export VAPI_API_KEY=your-vapi-api-key-here
```

### 2. Create Infrastructure

```bash
cd infra/azure

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
az acr login --name $ACR_NAME

# Create Container Apps environment
az containerapp env create \
  --name vapi-env \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### 3. Create Databases

```bash
# MongoDB (Cosmos DB)
az cosmosdb create \
  --name vapi-mongodb \
  --resource-group $RESOURCE_GROUP \
  --kind MongoDB \
  --locations regionName=$LOCATION

az cosmosdb mongodb database create \
  --account-name vapi-mongodb \
  --resource-group $RESOURCE_GROUP \
  --name vapi

# Get MongoDB connection string
MONGO_CS=$(az cosmosdb keys list \
  --name vapi-mongodb \
  --resource-group $RESOURCE_GROUP \
  --type connection-strings \
  --query connectionStrings[0].connectionString -o tsv)

# PostgreSQL
POSTGRES_PASSWORD=$(openssl rand -base64 32)
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name vapi-postgres \
  --location $LOCATION \
  --admin-user keycloak \
  --admin-password $POSTGRES_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 16 \
  --public-access 0.0.0.0

az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name vapi-postgres \
  --database-name keycloak
```

### 4. Build and Push Images

```bash
cd ../../vapi-backend

# Backend
az acr build --registry $ACR_NAME --image vapi-backend:latest --file Dockerfile.api .

# Usecases
az acr build --registry $ACR_NAME --image vapi-usecases:latest --file Dockerfile.usecases .

# Frontend
cd ../vapi-frontend
az acr build --registry $ACR_NAME --image vapi-frontend:latest --file Dockerfile .
```

### 5. Deploy Keycloak

```bash
cd ../../infra/azure

ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)
KEYCLOAK_PASSWORD=$(openssl rand -base64 32)

az acr import \
  --name $ACR_NAME \
  --source quay.io/keycloak/keycloak:26.0 \
  --image keycloak:26.0

az containerapp create \
  --name vapi-keycloak \
  --resource-group $RESOURCE_GROUP \
  --environment vapi-env \
  --image ${ACR_LOGIN_SERVER}/keycloak:26.0 \
  --target-port 8081 \
  --ingress external \
  --env-vars \
    "KC_HOSTNAME=vapi-keycloak.$(az containerapp env show --name vapi-env --resource-group $RESOURCE_GROUP --query properties.defaultDomain -o tsv)" \
    "KC_HTTP_ENABLED=true" \
    "KC_BOOTSTRAP_ADMIN_PASSWORD=$KEYCLOAK_PASSWORD" \
    "KC_DB=postgres" \
    "KC_DB_URL=jdbc:postgresql://vapi-postgres.postgres.database.azure.com:5432/keycloak?sslmode=require" \
    "KC_DB_USERNAME=keycloak@vapi-postgres" \
    "KC_DB_PASSWORD=$POSTGRES_PASSWORD" \
  --command "/bin/bash" \
  --args "-c" "/opt/keycloak/bin/kc.sh build --db postgres && /opt/keycloak/bin/kc.sh start" \
  --cpu 1.0 \
  --memory 2.0Gi

# Get Keycloak URL
KEYCLOAK_URL=$(az containerapp show --name vapi-keycloak --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
KEYCLOAK_URL="https://${KEYCLOAK_URL}"
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Keycloak Admin Password: $KEYCLOAK_PASSWORD"
```

### 6. Deploy Backend Services

```bash
# Backend
az containerapp create \
  --name vapi-backend \
  --resource-group $RESOURCE_GROUP \
  --environment vapi-env \
  --image ${ACR_LOGIN_SERVER}/vapi-backend:latest \
  --target-port 8080 \
  --ingress internal \
  --env-vars \
    "VAPI_API_KEY=$VAPI_API_KEY" \
    "KEYCLOAK_URL=$KEYCLOAK_URL" \
    "KEYCLOAK_REALM=vapi" \
  --cpu 0.5 \
  --memory 1.0Gi

# Get backend internal URL
BACKEND_URL=$(az containerapp show --name vapi-backend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
BACKEND_URL="http://${BACKEND_URL}"

# Usecases
az containerapp create \
  --name vapi-usecases \
  --resource-group $RESOURCE_GROUP \
  --environment vapi-env \
  --image ${ACR_LOGIN_SERVER}/vapi-usecases:latest \
  --target-port 8080 \
  --ingress internal \
  --env-vars \
    "MONGO_URI=$MONGO_CS" \
    "API_URL=$BACKEND_URL" \
    "KEYCLOAK_URL=$KEYCLOAK_URL" \
  --cpu 0.5 \
  --memory 1.0Gi

USECASES_URL=$(az containerapp show --name vapi-usecases --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
USECASES_URL="http://${USECASES_URL}"
```

### 7. Deploy Frontend

```bash
# Rebuild frontend with correct URLs
cd ../../vapi-frontend
az acr build --registry $ACR_NAME --image vapi-frontend:latest --file Dockerfile \
  --build-arg VITE_KEYCLOAK_URL=$KEYCLOAK_URL \
  --build-arg VITE_KEYCLOAK_REALM=vapi \
  --build-arg VITE_KEYCLOAK_CLIENT_ID=vapi-frontend \
  --build-arg VITE_API_BASE_URL=/api \
  --build-arg VITE_USECASES_BASE_URL=/usecases \
  .

cd ../infra/azure

# Deploy frontend
az containerapp create \
  --name vapi-frontend \
  --resource-group $RESOURCE_GROUP \
  --environment vapi-env \
  --image ${ACR_LOGIN_SERVER}/vapi-frontend:latest \
  --target-port 80 \
  --ingress external \
  --cpu 0.25 \
  --memory 0.5Gi

FRONTEND_URL=$(az containerapp show --name vapi-frontend --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
FRONTEND_URL="https://${FRONTEND_URL}"
echo "Frontend URL: $FRONTEND_URL"
```

### 8. Initialize Keycloak

Wait a few minutes for Keycloak to start, then:

```bash
# Update Keycloak client redirect URIs
# You'll need to do this via Keycloak admin console or API
# URL: $KEYCLOAK_URL
# Username: admin
# Password: $KEYCLOAK_PASSWORD
```

## Summary

Your application is now deployed! Access it at:
- **Frontend**: $FRONTEND_URL
- **Keycloak**: $KEYCLOAK_URL

**Important**: Update Keycloak client redirect URIs to include your frontend URL.

## Next Steps

1. Configure custom domains
2. Set up SSL certificates
3. Configure monitoring
4. Set up backups
5. Implement CI/CD

