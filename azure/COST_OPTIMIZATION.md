# Azure Cost Optimization Guide

This guide explains cost optimization strategies for single-user testing scenarios.

## Cost Comparison

### Standard Deployment
- **Container Apps**: ~$50-100/month (with auto-scaling)
- **Cosmos DB (MongoDB)**: ~$25-50/month
- **PostgreSQL Flexible Server**: ~$15-30/month
- **ACR (Basic)**: ~$5/month
- **Total**: ~$95-185/month

### Cost-Optimized Deployment
- **Container Apps (Consumption)**: ~$10-20/month (minimal replicas)
- **MongoDB Container**: ~$0-5/month (runs as container)
- **PostgreSQL (B1ms Burstable)**: ~$15/month
- **ACR (Basic)**: ~$5/month
- **Total**: ~$30-50/month

**Savings: ~$65-135/month (70% reduction)**

## Optimization Strategies

### 1. Use MongoDB Container Instead of Cosmos DB

**Standard**: Cosmos DB with MongoDB API (~$25-50/month)
**Optimized**: MongoDB container in Container Apps (~$0-5/month)

**Trade-offs**:
- ✅ Much cheaper
- ✅ Same functionality for testing
- ❌ No automatic backups
- ❌ No global distribution
- ❌ Manual scaling

**For testing**: Perfectly fine. Use Cosmos DB only for production.

### 2. Minimize Container Resources

**Standard**:
- CPU: 1.0 cores
- Memory: 2.0 Gi
- Min replicas: 1
- Max replicas: 3

**Optimized**:
- CPU: 0.5 cores (or 0.25 if possible)
- Memory: 1.0 Gi (or 0.5 Gi if possible)
- Min replicas: 1
- Max replicas: 1 (for testing)

**Savings**: ~50-70% on compute costs

### 3. Use Cheapest PostgreSQL Tier

**Standard**: Standard_B1ms Burstable (~$15/month)
**Optimized**: Already using cheapest tier ✅

**Note**: Can't go cheaper without losing functionality.

### 4. Scale Down When Not in Use

Create scripts to scale services to 0 replicas when not testing:

```bash
# Scale down all services
az containerapp update --name vapi-backend --resource-group vapi-rg --min-replicas 0
az containerapp update --name vapi-usecases --resource-group vapi-rg --min-replicas 0
az containerapp update --name vapi-frontend --resource-group vapi-rg --min-replicas 0
az containerapp update --name vapi-keycloak --resource-group vapi-rg --min-replicas 0
az containerapp update --name vapi-mongodb --resource-group vapi-rg --min-replicas 0

# Scale up when needed
az containerapp update --name vapi-backend --resource-group vapi-rg --min-replicas 1
# ... repeat for other services
```

**Savings**: ~80-90% when scaled down (only pay for storage)

### 5. Use Azure Free Account Credits

If eligible, use Azure Free Account:
- $200 credit for 30 days
- 12 months free for certain services
- Always free tier for some services

### 6. Use Dev/Test Pricing

If you have Visual Studio subscription:
- 50% discount on VMs
- Discounts on other services

## Quick Cost Optimization Scripts

### Scale Down (Stop Services)
```bash
./scale-down.sh
```

### Scale Up (Start Services)
```bash
./scale-up.sh
```

## Monthly Cost Breakdown (Optimized)

| Service | Cost | Notes |
|---------|------|-------|
| Container Apps Environment | $0 | Free |
| Backend API (0.5 CPU, 1 Gi) | ~$3-5 | Consumption pricing |
| Usecases API (0.5 CPU, 1 Gi) | ~$3-5 | Consumption pricing |
| Frontend (0.5 CPU, 1 Gi) | ~$3-5 | Consumption pricing |
| Keycloak (1 CPU, 2 Gi) | ~$5-8 | Consumption pricing |
| MongoDB Container (0.5 CPU, 1 Gi) | ~$2-3 | Consumption pricing |
| PostgreSQL B1ms | ~$15 | Fixed cost |
| ACR Basic | ~$5 | Fixed cost |
| **Total** | **~$36-46/month** | |

## Additional Savings Tips

1. **Delete unused resources**: Remove old deployments, unused resource groups
2. **Monitor costs**: Set up budget alerts in Azure Portal
3. **Use Azure Cost Management**: Track spending daily
4. **Schedule shutdowns**: Use Azure Automation to scale down during off-hours
5. **Use Spot instances**: For non-critical workloads (not available for Container Apps)

## When to Use Standard Deployment

Use the standard deployment when:
- Multiple users
- Production environment
- Need automatic backups
- Need high availability
- Need global distribution
- Need auto-scaling

## When to Use Cost-Optimized Deployment

Use the cost-optimized deployment when:
- Single user testing
- Development environment
- Manual backups are acceptable
- Can tolerate downtime
- Budget is limited

