# Multi-Developer Deployment Guide

This guide explains deployment options for 3-4 developers testing simultaneously.

## Deployment Options Comparison

| Option | Cost/Month | Resources | Best For |
|--------|------------|-----------|----------|
| **Single-User** (`deploy-all-cheap.sh`) | ~$30-50 | Minimal (0.5 CPU, 1.0 Gi) | 1 developer |
| **Multi-Dev** (`deploy-all-multi-dev.sh`) | ~$50-70 | Moderate (0.75-1.0 CPU, 1.5-2.0 Gi) | 3-4 developers |
| **Production** (`deploy-all.sh`) | ~$95-185 | Full (1.0+ CPU, 2.0+ Gi) | Production, many users |

## Is Single-User Setup Suitable for 3-4 Developers?

### Short Answer: **Not Recommended**

The single-user optimized setup (`deploy-all-cheap.sh`) uses:
- **0.5 CPU, 1.0 Gi** per service
- **Single replica** (no auto-scaling)
- **Minimal Keycloak** (0.5 CPU, 1.0 Gi)

### Issues with 3-4 Developers:

1. **Resource Constraints**
   - 0.5 CPU may cause slow responses with concurrent requests
   - 1.0 Gi memory might be insufficient for multiple sessions
   - No auto-scaling means all load on single instance

2. **Keycloak Performance**
   - 0.5 CPU, 1.0 Gi is tight for multiple authentication requests
   - May experience timeouts or slow login

3. **Database Connections**
   - MongoDB container with minimal resources may struggle with concurrent connections
   - PostgreSQL B1ms tier should be fine (handles 3-4 users easily)

### Recommendation: Use Multi-Developer Setup

Use `deploy-all-multi-dev.sh` which provides:
- **0.75 CPU, 1.5 Gi** for Backend/Usecases (50% more resources)
- **1.0 CPU, 2.0 Gi** for Keycloak (standard resources)
- **Max 2 replicas** (allows auto-scaling if needed)
- **Same cost-optimized databases** (MongoDB container, cheapest PostgreSQL)

## Multi-Developer Deployment

### Quick Start

```bash
cd infra/azure

# 1. Configure environment
cp azure-env.example .env
# Edit .env with your values

# 2. Deploy multi-developer optimized setup
./deploy-all-multi-dev.sh
```

### Resource Allocation

| Service | CPU | Memory | Min Replicas | Max Replicas |
|---------|-----|--------|--------------|--------------|
| Backend API | 0.75 | 1.5 Gi | 1 | 2 |
| Usecases API | 0.75 | 1.5 Gi | 1 | 2 |
| Keycloak | 1.0 | 2.0 Gi | 1 | 2 |
| Frontend | 0.5 | 1.0 Gi | 1 | 2 |
| MongoDB | 0.5 | 1.0 Gi | 1 | 1 |

### Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| Container Apps (Consumption) | ~$20-35 |
| MongoDB Container | ~$0-5 |
| PostgreSQL (B1ms) | ~$15 |
| ACR (Basic) | ~$5 |
| **Total** | **~$50-70** |

### Performance Expectations

With this setup, you can expect:
- ✅ Smooth operation with 3-4 concurrent users
- ✅ Fast authentication (Keycloak has adequate resources)
- ✅ Responsive API calls (0.75 CPU handles moderate load)
- ✅ Auto-scaling if traffic spikes (up to 2 replicas)
- ⚠️ May slow down with 5+ concurrent heavy users

### Monitoring

Monitor performance and scale up if needed:

```bash
# Check service metrics
az containerapp show --name vapi-backend --resource-group vapi-rg --query properties.template.scale

# View logs
az containerapp logs show --name vapi-backend --resource-group vapi-rg --tail 50
```

### Scaling Up Further

If you experience performance issues with 3-4 developers:

1. **Increase CPU/Memory**:
   ```bash
   az containerapp update --name vapi-backend --resource-group vapi-rg \
     --cpu 1.0 --memory 2.0Gi
   ```

2. **Increase Max Replicas**:
   ```bash
   az containerapp update --name vapi-backend --resource-group vapi-rg \
     --max-replicas 3
   ```

3. **Consider Production Setup**:
   - Use `deploy-all.sh` for full resources
   - Consider Cosmos DB for better MongoDB performance

## Cost vs Performance Trade-offs

### Single-User Setup ($30-50/month)
- ✅ Lowest cost
- ❌ May struggle with 3-4 concurrent users
- ❌ Slow responses possible
- ❌ No auto-scaling

### Multi-Dev Setup ($50-70/month) ⭐ **Recommended**
- ✅ Good performance for 3-4 developers
- ✅ Auto-scaling available
- ✅ Still cost-optimized
- ✅ 50% more resources than single-user

### Production Setup ($95-185/month)
- ✅ Best performance
- ✅ Full auto-scaling
- ✅ Cosmos DB with backups
- ❌ Higher cost

## Recommendation

**For 3-4 developers: Use `deploy-all-multi-dev.sh`**

The extra $20-40/month is worth it for:
- Better developer experience
- Fewer performance issues
- Ability to handle concurrent testing
- Auto-scaling for traffic spikes

You can still use `scale-down.sh` when not testing to save costs.

