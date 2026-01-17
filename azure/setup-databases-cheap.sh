#!/bin/bash

# Cost-optimized database setup for single-user testing
# Uses MongoDB container instead of Cosmos DB (saves ~$25-50/month)
# Uses cheapest PostgreSQL tier (already optimal)

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
LOCATION=${LOCATION:-eastus}
ENV_NAME=${ENV_NAME:-vapi-env}
POSTGRES_SERVER_NAME=${POSTGRES_SERVER_NAME:-vapi-postgres}
POSTGRES_ADMIN_USER=${POSTGRES_ADMIN_USER:-keycloak}
POSTGRES_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD}
MONGO_USERNAME=${MONGO_USERNAME:-admin}
MONGO_PASSWORD=${MONGO_PASSWORD}

if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
  echo "Error: POSTGRES_ADMIN_PASSWORD must be set"
  exit 1
fi

if [ -z "$MONGO_PASSWORD" ]; then
  echo "Error: MONGO_PASSWORD must be set"
  exit 1
fi

echo "💰 Cost-optimized database setup for testing..."
echo ""

# Step 1: Deploy MongoDB as a container (much cheaper than Cosmos DB)
echo "📦 Deploying MongoDB as Container App (replaces Cosmos DB)..."
echo "   This saves ~$25-50/month compared to Cosmos DB"

az containerapp create \
  --name vapi-mongodb \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image mongo:7.0 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 1 \
  --ingress internal \
  --env-vars \
    MONGO_INITDB_ROOT_USERNAME=$MONGO_USERNAME \
    MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD \
    MONGO_INITDB_DATABASE=vapi \
  --command "mongod --bind_ip_all" \
  || echo "MongoDB container may already exist"

# Wait for MongoDB to be ready
echo "⏳ Waiting for MongoDB to start..."
sleep 15

# Get MongoDB internal FQDN
MONGO_FQDN=$(az containerapp show --name vapi-mongodb --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
MONGO_CONNECTION_STRING="mongodb://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_FQDN}:27017/vapi?authSource=admin"

echo "MongoDB Connection String: $MONGO_CONNECTION_STRING"
echo "MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING" >> .env
echo "MONGO_USERNAME=$MONGO_USERNAME" >> .env
echo "MONGO_PASSWORD=$MONGO_PASSWORD" >> .env
echo "MONGO_HOST=$MONGO_FQDN" >> .env
echo "MONGO_DATABASE=vapi" >> .env

echo ""
echo "🐘 Creating PostgreSQL (cheapest tier - Burstable B1ms)..."
echo "   Cost: ~$15/month (already optimal)"

# Create PostgreSQL Flexible Server with cheapest tier
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --location $LOCATION \
  --admin-user $POSTGRES_ADMIN_USER \
  --admin-password $POSTGRES_ADMIN_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 16 \
  --storage-size 32 \
  --public-access 0.0.0.0 \
  --high-availability Disabled \
  || echo "PostgreSQL server may already exist"

# Create database
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $POSTGRES_SERVER_NAME \
  --database-name keycloak || echo "Database may already exist"

# Allow Azure services to access
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 || echo "Firewall rule may already exist"

POSTGRES_CONNECTION_STRING="postgresql://${POSTGRES_ADMIN_USER}:${POSTGRES_ADMIN_PASSWORD}@${POSTGRES_SERVER_NAME}.postgres.database.azure.com:5432/keycloak?sslmode=require"
echo "POSTGRES_CONNECTION_STRING=$POSTGRES_CONNECTION_STRING" >> .env

echo ""
echo "✅ Cost-optimized databases created!"
echo ""
echo "📋 Connection Information:"
echo "  MongoDB: $MONGO_CONNECTION_STRING"
echo "  PostgreSQL: $POSTGRES_CONNECTION_STRING"
echo ""
echo "💰 Cost Savings:"
echo "  - MongoDB container: ~$0-5/month (vs Cosmos DB ~$25-50/month)"
echo "  - PostgreSQL: ~$15/month (already cheapest tier)"
echo "  - Total database cost: ~$15-20/month (vs ~$40-65/month with Cosmos DB)"
echo ""
echo "⚠️  Note: MongoDB container has no automatic backups."
echo "   For production, consider using Cosmos DB or Azure Database for MongoDB."

