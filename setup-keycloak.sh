#!/bin/bash

# Keycloak setup script for VAPI
# This script sets up a Keycloak realm and client for the VAPI application

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8081}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="${REALM_NAME:-vapi}"
CLIENT_ID="${CLIENT_ID:-vapi-frontend}"

echo "Setting up Keycloak for VAPI..."
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Realm: $REALM_NAME"
echo "Client ID: $CLIENT_ID"

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0
until curl -f -s "$KEYCLOAK_URL/realms/master/.well-known/openid-configuration" > /dev/null 2>&1; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "Keycloak did not become ready after $MAX_ATTEMPTS attempts. Continuing anyway..."
    break
  fi
  echo "Waiting for Keycloak... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 2
done

echo "Keycloak is ready!"

# Get access token
echo "Getting admin access token..."
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

echo "Access token obtained."

# Check if realm already exists
REALM_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -o /dev/null -w "%{http_code}")

if [ "$REALM_EXISTS" = "200" ]; then
  echo "Realm '$REALM_NAME' already exists. Skipping creation."
else
  echo "Creating realm '$REALM_NAME'..."
  
  # Create realm
  curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"realm\": \"$REALM_NAME\",
      \"enabled\": true,
      \"registrationAllowed\": true,
      \"registrationEmailAsUsername\": false,
      \"rememberMe\": true,
      \"verifyEmail\": false,
      \"loginWithEmailAllowed\": true,
      \"duplicateEmailsAllowed\": false,
      \"resetPasswordAllowed\": true,
      \"editUsernameAllowed\": false,
      \"bruteForceProtected\": false
    }" > /dev/null
  
  echo "Realm created."
fi

# Get realm token
echo "Getting realm access token..."
REALM_TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KEYCLOAK_ADMIN" \
  -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

REALM_ACCESS_TOKEN=$(echo $REALM_TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

# Ensure core realm roles exist
ensure_role() {
  local ROLE_NAME="$1"
  local ROLE_DESCRIPTION="$2"

  local ROLE_STATUS
  ROLE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$ROLE_NAME" \
    -H "Authorization: Bearer $REALM_ACCESS_TOKEN")

  if [ "$ROLE_STATUS" = "200" ]; then
    echo "Role '$ROLE_NAME' already exists."
    return
  fi

  echo "Creating role '$ROLE_NAME'..."
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles" \
    -H "Authorization: Bearer $REALM_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$ROLE_NAME\",
      \"description\": \"$ROLE_DESCRIPTION\",
      \"composite\": false,
      \"clientRole\": false
    }" > /dev/null
  echo "Role '$ROLE_NAME' created."
}

ensure_role "admin" "Administrator with full access to all services"
ensure_role "tenant" "Tenant with access limited to usecases APIs"

# Configure default roles - add tenant role to default-roles-vapi composite role
echo "Configuring default roles for new users..."
DEFAULT_ROLES_ROLE="default-roles-$REALM_NAME"

# Get the tenant role ID
TENANT_ROLE_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/tenant" \
  -H "Authorization: Bearer $REALM_ACCESS_TOKEN")

TENANT_ROLE_ID=$(echo $TENANT_ROLE_RESPONSE | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)

if [ -n "$TENANT_ROLE_ID" ]; then
  # Check if tenant role is already in default roles
  COMPOSITES_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$DEFAULT_ROLES_ROLE/composites" \
    -H "Authorization: Bearer $REALM_ACCESS_TOKEN")
  
  if echo "$COMPOSITES_RESPONSE" | grep -q "\"id\":\"$TENANT_ROLE_ID\""; then
    echo "Tenant role is already in default roles."
  else
    echo "Adding tenant role to default roles..."
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$DEFAULT_ROLES_ROLE/composites" \
      -H "Authorization: Bearer $REALM_ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "[{\"id\":\"$TENANT_ROLE_ID\",\"name\":\"tenant\"}]" > /dev/null
    echo "Tenant role added to default roles."
  fi
else
  echo "Warning: Could not find tenant role ID. Skipping default role configuration."
fi

# Check if client already exists and get its UUID
CLIENT_LIST=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $REALM_ACCESS_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_LIST" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//' || echo "")

if [ -n "$CLIENT_UUID" ]; then
  echo "Client '$CLIENT_ID' already exists. Updating configuration..."
  
  # Update existing client with post-logout redirect URIs
  curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID" \
    -H "Authorization: Bearer $REALM_ACCESS_TOKEN" \
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
        \"http://localhost:3000\"
      ],
      \"postLogoutRedirectUris\": [
        \"http://localhost:3000/login\",
        \"http://localhost:3000/*\",
        \"http://localhost:3000\"
      ],
      \"webOrigins\": [
        \"http://localhost:3000\",
        \"*\"
      ],
      \"protocol\": \"openid-connect\",
      \"fullScopeAllowed\": true,
      \"attributes\": {
        \"pkce.code.challenge.method\": \"S256\"
      }
    }" > /dev/null
  echo "Client configuration updated."
else
  echo "Creating client '$CLIENT_ID'..."
  
  # Get client UUID after creation
  CLIENT_UUID=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
    -H "Authorization: Bearer $REALM_ACCESS_TOKEN" \
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
        \"http://localhost:3000\"
      ],
      \"postLogoutRedirectUris\": [
        \"http://localhost:3000/login\",
        \"http://localhost:3000/*\",
        \"http://localhost:3000\"
      ],
      \"webOrigins\": [
        \"http://localhost:3000\",
        \"*\"
      ],
      \"protocol\": \"openid-connect\",
      \"fullScopeAllowed\": true,
      \"attributes\": {
        \"pkce.code.challenge.method\": \"S256\"
      }
    }" | grep -o '"id":"[^"]*' | sed 's/"id":"//' || echo "")
  
  if [ -n "$CLIENT_UUID" ]; then
    echo "Client created with UUID: $CLIENT_UUID"
  else
    echo "Client creation may have failed or client already exists."
  fi
fi

echo ""
echo "✅ Keycloak setup complete!"
echo ""
echo "Realm: $REALM_NAME"
echo "Client ID: $CLIENT_ID"
echo ""
echo "You can access Keycloak Admin Console at:"
echo "  $KEYCLOAK_URL"
echo "  Username: $KEYCLOAK_ADMIN"
echo "  Password: $KEYCLOAK_ADMIN_PASSWORD"
echo ""
echo "Frontend configuration:"
echo "  VITE_KEYCLOAK_URL=$KEYCLOAK_URL"
echo "  VITE_KEYCLOAK_REALM=$REALM_NAME"
echo "  VITE_KEYCLOAK_CLIENT_ID=$CLIENT_ID"

