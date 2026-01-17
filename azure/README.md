# Azure Deployment Guide

This guide will help you deploy the VAPI application to Azure.

## 🎯 Quick Start

**For single-user testing (~$30-50/month):**
- See [QUICK_START_CHEAP.md](./QUICK_START_CHEAP.md) for cost-optimized deployment
- Uses MongoDB container instead of Cosmos DB (saves ~$25-50/month)
- Minimal resource allocation for all services
- Includes scripts to scale down when not in use

**For 3-4 developers testing (~$50-70/month):** ⭐ **Recommended for small teams**
- See [MULTI_DEV_GUIDE.md](./MULTI_DEV_GUIDE.md) for multi-developer deployment
- Moderate resources (0.75-1.0 CPU, 1.5-2.0 Gi)
- Auto-scaling up to 2 replicas
- Still uses cost-optimized databases

**For production or many users (~$95-185/month):**
- See [QUICK_START.md](./QUICK_START.md) for standard deployment
- Full resources with auto-scaling
- Cosmos DB with automatic backups

## Architecture Overview

The application consists of:
- **Frontend**: React/Vite app served via Nginx
- **Backend API**: Go service (port 8080)
- **Usecases Service**: Go service (port 8080)
- **Keycloak**: Identity and Access Management
- **MongoDB**: Database for usecases service
- **PostgreSQL**: Database for Keycloak

## Deployment Options

### Option 1: Azure Container Apps (Recommended)
Best for: Simple containerized deployments, automatic scaling, managed infrastructure

### Option 2: Azure Kubernetes Service (AKS)
Best for: Complex orchestration needs, advanced networking, full Kubernetes features

### Option 3: Azure App Service + Managed Databases
Best for: Traditional web app deployment with managed databases

## Prerequisites

1. Azure CLI installed and logged in
2. Docker images pushed to Azure Container Registry (ACR)
3. Azure subscription with appropriate permissions

## Quick Start with Azure Container Apps

### Step 1: Create Resource Group

```bash
az group create --name vapi-rg --location eastus
```

### Step 2: Create Azure Container Registry

```bash
az acr create --resource-group vapi-rg --name vapiacr --sku Basic
az acr login --name vapiacr
```

### Step 3: Create Managed Databases

#### MongoDB (Azure Cosmos DB with MongoDB API)

```bash
az cosmosdb create \
  --name vapi-mongodb \
  --resource-group vapi-rg \
  --kind MongoDB \
  --locations regionName=eastus

az cosmosdb mongodb database create \
  --account-name vapi-mongodb \
  --resource-group vapi-rg \
  --name vapi
```

#### PostgreSQL (Azure Database for PostgreSQL)

```bash
az postgres flexible-server create \
  --resource-group vapi-rg \
  --name vapi-postgres \
  --location eastus \
  --admin-user keycloak \
  --admin-password <YOUR_PASSWORD> \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 16 \
  --storage-size 32
```

### Step 4: Build and Push Docker Images

```bash
# Build and push backend API
cd ../vapi-backend
az acr build --registry vapiacr --image vapi-backend:latest --file Dockerfile.api .

# Build and push usecases service
az acr build --registry vapiacr --image vapi-usecases:latest --file Dockerfile.usecases .

# Build and push frontend
cd ../vapi-frontend
az acr build --registry vapiacr --image vapi-frontend:latest --file Dockerfile .
```

### Step 5: Create Container Apps Environment

```bash
az containerapp env create \
  --name vapi-env \
  --resource-group vapi-rg \
  --location eastus
```

### Step 6: Deploy Services

See individual deployment scripts in this directory:
- `deploy-keycloak.sh`
- `deploy-backend.sh`
- `deploy-usecases.sh`
- `deploy-frontend.sh`

## Environment Variables

Create a `.env` file based on `env.example` with Azure-specific values:

- Use Azure Database connection strings
- Use Azure Container Registry image references
- Configure Keycloak with public URLs
- Set up proper CORS and redirect URIs

## Networking

- All services will be accessible via Azure Container Apps URLs
- Configure Keycloak redirect URIs to match your frontend URL
- Set up Application Gateway or Front Door for custom domains and SSL

## Security

- Use Azure Key Vault for secrets
- Enable managed identities for service-to-service authentication
- Configure network security groups
- Use Azure Private Link for database connections

## Monitoring

- Azure Monitor for logs and metrics
- Application Insights for application performance
- Container Apps built-in monitoring

## Cost Optimization

### For Single-User Testing

Use the **cost-optimized deployment** (`deploy-all-cheap.sh`):
- **MongoDB Container**: Replaces Cosmos DB, saves ~$25-50/month
- **Minimal Resources**: 0.5 CPU, 1.0 Gi per service (vs 1.0 CPU, 2.0 Gi)
- **Scale Down Scripts**: Use `scale-down.sh` when not testing (saves ~80-90%)
- **Total Cost**: ~$30-50/month (vs ~$95-185/month standard)

### For 3-4 Developers Testing

Use the **multi-developer deployment** (`deploy-all-multi-dev.sh`): ⭐ **Recommended**
- **Same cost-optimized databases** (MongoDB container, cheapest PostgreSQL)
- **Moderate Resources**: 0.75-1.0 CPU, 1.5-2.0 Gi per service
- **Auto-scaling**: Up to 2 replicas for traffic spikes
- **Total Cost**: ~$50-70/month
- **Better Performance**: Handles 3-4 concurrent users smoothly

See [MULTI_DEV_GUIDE.md](./MULTI_DEV_GUIDE.md) for details and [COST_OPTIMIZATION.md](./COST_OPTIMIZATION.md) for cost breakdown.

### For Production

- Use appropriate SKU sizes for databases
- Enable auto-scaling for Container Apps
- Use Azure Reserved Instances for long-term savings
- Monitor and optimize resource usage
- Consider Cosmos DB for automatic backups and global distribution

