#!/bin/bash

# Script to update Keycloak client with postLogoutRedirectUris
# This can be run manually to fix logout redirect issues

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8081}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="${REALM_NAME:-vapi}"
CLIENT_ID="${CLIENT_ID:-vapi-frontend}"

echo "Getting access token..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KEYCLOAK_ADMIN" \
  -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to get access token. Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Finding client..."
CLIENT_LIST=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_LIST" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//' || echo "")

if [ -z "$CLIENT_UUID" ]; then
  echo "Error: Client '$CLIENT_ID' not found!"
  exit 1
fi

echo "Updating client '$CLIENT_ID' with postLogoutRedirectUris..."
curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"$CLIENT_ID\",
    \"enabled\": true,
    \"publicClient\": true,
    \"standardFlowEnabled\": true,
    \"implicitFlowEnabled\": false,
    \"directAccessGrantsEnabled\": true,
    \"serviceAccountsEnabled\": false,
    \"redirectUris\": [
      \"http://localhost:3000/*\",
      \"http://localhost:3000\",
      \"http://localhost:3000/\"
    ],
    \"postLogoutRedirectUris\": [
      \"http://localhost:3000/login\",
      \"http://localhost:3000/*\",
      \"http://localhost:3000\",
      \"http://localhost:3000/\",
      \"+\"
    ],
    \"webOrigins\": [
      \"http://localhost:3000\",
      \"*\"
    ],
    \"protocol\": \"openid-connect\",
    \"attributes\": {
      \"pkce.code.challenge.method\": \"S256\"
    }
  }" > /dev/null

echo "✅ Client updated successfully!"
