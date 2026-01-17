# Complete Azure Deployment Guide

This guide provides step-by-step instructions for deploying the VAPI application to Azure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Option 1: Azure Container Apps (Recommended)](#option-1-azure-container-apps-recommended)
4. [Option 2: Azure Kubernetes Service (AKS)](#option-2-azure-kubernetes-service-aks)
5. [Post-Deployment Configuration](#post-deployment-configuration)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed and configured (`az login`)
- Docker installed locally (for building images)
- Basic knowledge of Azure services

## Architecture Overview

```
┌─────────────┐
│  Frontend   │ (Azure Container App / Static Web App)
│  (Nginx)    │
└──────┬──────┘
       │
       ├─── /api ────> Backend API (Container App)
       │
       └─── /usecases ─> Usecases Service (Container App)
                         │
                         └───> MongoDB (Cosmos DB)
       
       ┌─────────────────┐
       │    Keycloak     │ (Container App)
       └────────┬────────┘
                │
                └───> PostgreSQL (Azure Database)
```

## Option 1: Azure Container Apps (Recommended)

### Step 1: Initial Setup

```bash
cd infra/azure

# Copy and configure environment variables
cp azure-env.example .env
# Edit .env with your values
```

### Step 2: Create Resource Group and ACR

```bash
# Set variables
export RESOURCE_GROUP=vapi-rg
export LOCATION=eastus
export ACR_NAME=vapiacr  # Must be globally unique

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
az acr login --name $ACR_NAME
```

### Step 3: Setup Databases

```bash
# Create MongoDB (Cosmos DB) and PostgreSQL
./setup-databases.sh

# Note the connection strings from the output
```

### Step 4: Build and Push Images

```bash
# Build backend API
cd ../../vapi-backend
az acr build --registry $ACR_NAME --image vapi-backend:latest --file Dockerfile.api .

# Build usecases service
az acr build --registry $ACR_NAME --image vapi-usecases:latest --file Dockerfile.usecases .

# Build frontend (with environment variables)
cd ../vapi-frontend
az acr build --registry $ACR_NAME --image vapi-frontend:latest --file Dockerfile \
  --build-arg VITE_KEYCLOAK_URL=$KEYCLOAK_URL \
  --build-arg VITE_KEYCLOAK_REALM=vapi \
  --build-arg VITE_KEYCLOAK_CLIENT_ID=vapi-frontend \
  --build-arg VITE_API_BASE_URL=/api \
  --build-arg VITE_USECASES_BASE_URL=/usecases \
  .

cd ../../infra/azure
```

### Step 5: Deploy Services

```bash
# Deploy all services (or deploy individually)
./deploy-all.sh

# Or deploy individually:
# ./deploy-keycloak.sh
# ./deploy-backend.sh
# ./deploy-usecases.sh
# ./deploy-frontend.sh
```

### Step 6: Configure Keycloak

After deployment, get the Keycloak URL:

```bash
KEYCLOAK_URL=$(az containerapp show \
  --name vapi-keycloak \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn -o tsv)
KEYCLOAK_URL="https://${KEYCLOAK_URL}"
```

Update Keycloak client redirect URIs to include your frontend URL.

### Step 7: Run Keycloak Initialization

You'll need to run the Keycloak initialization script. You can do this by:

1. Creating a one-time container app job, or
2. Using Azure Cloud Shell to run the script, or
3. Running it from a local machine that can access Keycloak

## Option 2: Azure Kubernetes Service (AKS)

For AKS deployment, you'll need Kubernetes manifests. See `k8s/` directory for examples.

## Important Configuration Notes

### 1. Service Discovery

In Azure Container Apps, services can discover each other using:
- Internal ingress URLs (for internal communication)
- Service names in the same environment

### 2. Environment Variables

Update these in Azure Portal or via CLI:
- `KEYCLOAK_URL` - Use the Container App FQDN
- `API_URL` - Use internal ingress URL for backend
- `MONGO_URI` - Use Cosmos DB connection string
- `KC_DB_URL` - Use PostgreSQL connection string

### 3. Networking

- Frontend: External ingress (public)
- Backend: Internal ingress (private)
- Usecases: Internal ingress (private)
- Keycloak: External ingress (public, for OAuth)

### 4. Custom Domains

To use custom domains:
1. Add custom domain in Container App settings
2. Configure DNS records
3. Update Keycloak redirect URIs
4. Rebuild frontend with new URLs

## Cost Estimation

Approximate monthly costs (East US region):
- Container Apps: ~$50-100 (depending on usage)
- Cosmos DB (MongoDB): ~$25-50
- PostgreSQL: ~$15-30
- Container Registry: ~$5
- **Total: ~$95-185/month**

## Security Best Practices

1. **Use Azure Key Vault** for secrets
2. **Enable Managed Identity** for service-to-service auth
3. **Use Private Endpoints** for databases
4. **Enable SSL/TLS** everywhere
5. **Configure Network Security Groups**
6. **Regular security updates**

## Monitoring

- **Azure Monitor**: Logs and metrics
- **Application Insights**: Application performance
- **Container Insights**: Container-specific metrics

## Scaling

Container Apps support:
- **Manual scaling**: Set min/max replicas
- **Auto-scaling**: Based on CPU, memory, or HTTP requests
- **Scale to zero**: For cost optimization

## Troubleshooting

### Services not starting
- Check logs: `az containerapp logs show --name <app-name> --resource-group <rg>`
- Verify environment variables
- Check database connectivity

### Keycloak not accessible
- Verify ingress is set to external
- Check firewall rules
- Verify DNS resolution

### Frontend can't reach backend
- Verify internal ingress is enabled
- Check service names match
- Verify network policies

## Next Steps

1. Set up CI/CD with GitHub Actions
2. Configure custom domains
3. Set up monitoring and alerts
4. Implement backup strategies
5. Configure auto-scaling rules

