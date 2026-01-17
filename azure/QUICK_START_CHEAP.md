# Quick Start: Cost-Optimized Deployment

This guide deploys VAPI to Azure with minimal costs (~$30-50/month) for single-user testing.

## Prerequisites

1. Azure CLI installed and logged in: `az login`
2. Azure subscription with billing enabled
3. Docker installed (for local builds, optional)

## Quick Deployment (15 minutes)

### 1. Configure Environment

```bash
cd infra/azure
cp azure-env.example .env
```

Edit `.env` and set:
- `POSTGRES_ADMIN_PASSWORD` - Strong password for PostgreSQL
- `MONGO_PASSWORD` - Strong password for MongoDB
- `KEYCLOAK_ADMIN_PASSWORD` - Password for Keycloak admin
- `KEYCLOAK_HOSTNAME` - Your Keycloak hostname (e.g., `vapi-keycloak.azurecontainerapps.io`)
- `VAPI_API_KEY` - Your VAPI API key
- `SERVICE_AUTH_TOKEN` - Random token for service-to-service auth

### 2. Run Cost-Optimized Deployment

```bash
chmod +x *.sh
./deploy-all-cheap.sh
```

This will:
- Create resource group
- Create ACR (Basic tier)
- Create Container Apps environment
- Deploy MongoDB as container (instead of Cosmos DB)
- Deploy PostgreSQL (cheapest tier)
- Build and deploy all services with minimal resources

### 3. Wait for Services

Services will be ready in 5-10 minutes. Get URLs:

```bash
# Frontend
az containerapp show --name vapi-frontend --resource-group vapi-rg --query properties.configuration.ingress.fqdn -o tsv

# Keycloak
az containerapp show --name vapi-keycloak --resource-group vapi-rg --query properties.configuration.ingress.fqdn -o tsv
```

### 4. Configure Keycloak

1. Access Keycloak admin console
2. Update client redirect URIs to include your frontend URL
3. Run initialization script (if you have one)

## Cost Management

### Scale Down When Not in Use

Save ~80-90% when not testing:

```bash
./scale-down.sh
```

### Scale Up When Testing

```bash
./scale-up.sh
```

Services will start automatically on first request (30-60 seconds).

## Cost Breakdown

| Service | Monthly Cost |
|---------|--------------|
| Container Apps (Consumption) | ~$10-20 |
| MongoDB Container | ~$0-5 |
| PostgreSQL (B1ms) | ~$15 |
| ACR (Basic) | ~$5 |
| **Total** | **~$30-50** |

When scaled down: ~$5-10/month (storage only)

## Troubleshooting

### Services Not Starting

Check logs:
```bash
az containerapp logs show --name vapi-backend --resource-group vapi-rg --tail 50
```

### High Costs

1. Scale down services: `./scale-down.sh`
2. Check Azure Cost Management in portal
3. Set up budget alerts

### MongoDB Connection Issues

MongoDB container may take 1-2 minutes to start. Check:
```bash
az containerapp logs show --name vapi-mongodb --resource-group vapi-rg
```

## Next Steps

1. Monitor costs in Azure Portal
2. Set up budget alerts
3. Use `scale-down.sh` when not testing
4. Consider Azure Free Account credits if eligible

## Comparison

**Standard Deployment**: ~$95-185/month
**Cost-Optimized**: ~$30-50/month
**Savings**: ~$65-135/month (70% reduction)

