# Azure Networking Options for VAPI

This document explains different networking approaches for deploying VAPI on Azure.

## Option 1: Direct API Calls (Simplest)

Have the frontend call backend services directly via their Container App FQDNs.

**Pros**: Simple, no proxy needed
**Cons**: Requires services to have external ingress, CORS configuration needed

**Configuration**:
- Set backend/usecases ingress to `external`
- Update frontend environment variables to use full URLs
- Configure CORS on backend services

## Option 2: Azure Application Gateway (Recommended for Production)

Use Application Gateway as a reverse proxy.

**Pros**: 
- Single entry point
- SSL termination
- Load balancing
- WAF capabilities
- Custom domains

**Cons**: Additional cost (~$20-50/month)

**Setup**:
```bash
# Create Application Gateway
az network application-gateway create \
  --name vapi-gateway \
  --resource-group vapi-rg \
  --location eastus \
  --capacity 2 \
  --sku Standard_v2
```

## Option 3: Nginx Proxy in Frontend Container

Use nginx in the frontend container to proxy requests (current approach).

**Pros**: 
- Works with internal ingress
- No additional services needed
- Simple setup

**Cons**: 
- Frontend container needs to know backend URLs
- Requires rebuilding frontend when backend URLs change

**Current Implementation**: See `nginx-azure.conf`

## Option 4: Azure Front Door

Use Azure Front Door for global distribution and routing.

**Pros**:
- Global CDN
- DDoS protection
- Advanced routing rules
- Custom domains with SSL

**Cons**: Higher cost, more complex setup

## Recommended Approach

For **development/testing**: Use Option 1 (Direct API calls)
For **production**: Use Option 2 (Application Gateway)

## Implementation Example: Direct API Calls

Update frontend build to use direct URLs:

```bash
az acr build --registry $ACR_NAME --image vapi-frontend:latest \
  --build-arg VITE_KEYCLOAK_URL=$KEYCLOAK_URL \
  --build-arg VITE_API_BASE_URL=https://vapi-backend.azurecontainerapps.io \
  --build-arg VITE_USECASES_BASE_URL=https://vapi-usecases.azurecontainerapps.io \
  --file Dockerfile vapi-frontend/
```

Then update frontend API service to use these URLs directly instead of `/api` and `/usecases` paths.

