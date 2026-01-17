#!/bin/bash

# Setup Azure managed databases for VAPI
set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-vapi-rg}
LOCATION=${LOCATION:-eastus}
MONGO_ACCOUNT_NAME=${MONGO_ACCOUNT_NAME:-vapi-mongodb}
POSTGRES_SERVER_NAME=${POSTGRES_SERVER_NAME:-vapi-postgres}
POSTGRES_ADMIN_USER=${POSTGRES_ADMIN_USER:-keycloak}
POSTGRES_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD}

if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
  echo "Error: POSTGRES_ADMIN_PASSWORD must be set"
  exit 1
fi

echo "📦 Creating MongoDB (Cosmos DB with MongoDB API)..."

# Create Cosmos DB account with MongoDB API
az cosmosdb create \
  --name $MONGO_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --kind MongoDB \
  --locations regionName=$LOCATION \
  --default-consistency-level Session || echo "Cosmos DB account may already exist"

# Create database
az cosmosdb mongodb database create \
  --account-name $MONGO_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --name vapi || echo "Database may already exist"

# Get connection string
MONGO_CONNECTION_STRING=$(az cosmosdb keys list \
  --name $MONGO_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --type connection-strings \
  --query connectionStrings[0].connectionString -o tsv)

echo "MongoDB Connection String: $MONGO_CONNECTION_STRING"
echo "MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING" >> .env

echo ""
echo "🐘 Creating PostgreSQL (Azure Database for PostgreSQL)..."

# Create PostgreSQL Flexible Server
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
  --public-access 0.0.0.0 || echo "PostgreSQL server may already exist"

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

echo ""
echo "✅ Databases created successfully!"
echo ""
echo "📋 Connection Information:"
echo "  MongoDB: $MONGO_CONNECTION_STRING"
echo "  PostgreSQL: $POSTGRES_SERVER_NAME.postgres.database.azure.com"
echo ""
echo "⚠️  Note: Update your .env file with these connection strings"

