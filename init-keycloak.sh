#!/bin/bash

# Keycloak initialization script
# This script waits for Keycloak to be ready and then sets up the realm and client

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8081}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="${REALM_NAME:-vapi}"
CLIENT_ID="${CLIENT_ID:-vapi-frontend}"

echo "Waiting for Keycloak to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=0

until curl -f -s "$KEYCLOAK_URL/realms/master/.well-known/openid-configuration" > /dev/null 2>&1; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "Keycloak did not become ready after $MAX_ATTEMPTS attempts. Exiting..."
    exit 1
  fi
  echo "Waiting for Keycloak... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 2
done

echo "Keycloak is ready! Setting up realm and client..."

# Wait a bit more for Keycloak to fully initialize
sleep 5

# Get access token
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

# Check if realm already exists
REALM_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -o /dev/null -w "%{http_code}")

if [ "$REALM_EXISTS" != "200" ]; then
  echo "Creating realm '$REALM_NAME'..."
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
      \"bruteForceProtected\": false,
      \"defaultRoles\": [\"default-roles-$REALM_NAME\"]
    }" > /dev/null
  echo "Realm created."
else
  echo "Realm '$REALM_NAME' already exists. Updating configuration..."
  # Update realm to ensure default roles are set
  curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"defaultRoles\": [\"default-roles-$REALM_NAME\"]
    }" > /dev/null
  echo "Realm configuration updated."
fi

# Get fresh token for client operations
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KEYCLOAK_ADMIN" \
  -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

# Check if client already exists
CLIENT_LIST=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_LIST" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//' || echo "")

if [ -z "$CLIENT_UUID" ]; then
  echo "Creating client '$CLIENT_ID'..."
  
  # Create client (without postLogoutRedirectUris in initial creation)
  CLIENT_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
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
    }")
  
  # Get client UUID after creation
  CLIENT_UUID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//' || echo "")
  
  if [ -n "$CLIENT_UUID" ]; then
    echo "Client created with UUID: $CLIENT_UUID"
  else
    echo "Warning: Client creation may have failed."
  fi
else
  echo "Client '$CLIENT_ID' already exists. Updating configuration..."
  
  # Update existing client
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
  echo "Client updated."
fi

# Get fresh token for role operations
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KEYCLOAK_ADMIN" \
  -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

# Create roles if they don't exist
echo "Creating roles..."

# Check if admin role exists
ADMIN_ROLE_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/admin" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -o /dev/null -w "%{http_code}")

if [ "$ADMIN_ROLE_EXISTS" != "200" ]; then
  echo "Creating 'admin' role..."
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "admin",
      "description": "Administrator with full access to all services",
      "composite": false,
      "clientRole": false
    }' > /dev/null
  echo "Admin role created."
else
  echo "Admin role already exists."
fi

# Check if tenant role exists
TENANT_ROLE_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/tenant" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -o /dev/null -w "%{http_code}")

if [ "$TENANT_ROLE_EXISTS" != "200" ]; then
  echo "Creating 'tenant' role..."
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "tenant",
      "description": "Tenant with access limited to usecases APIs",
      "composite": false,
      "clientRole": false
    }' > /dev/null
  echo "Tenant role created."
else
  echo "Tenant role already exists."
fi

# Configure default roles - add tenant role to default-roles-vapi composite role
echo "Configuring default roles for new users..."
DEFAULT_ROLES_ROLE="default-roles-$REALM_NAME"

# Get the tenant role details to get its ID
TENANT_ROLE_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/tenant" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

TENANT_ROLE_ID=$(echo "$TENANT_ROLE_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//' || echo "")

if [ -z "$TENANT_ROLE_ID" ]; then
  echo "Warning: Could not get tenant role ID. Trying to extract from roles list..."
  # Alternative: get from roles list
  ROLES_LIST=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  TENANT_ROLE_ID=$(echo "$ROLES_LIST" | grep -o '"id":"[^"]*"[^}]*"name":"tenant"' | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)
fi

if [ -n "$TENANT_ROLE_ID" ]; then
  echo "Tenant role ID: $TENANT_ROLE_ID"
  
  # Check if default-roles-vapi role exists
  DEFAULT_ROLES_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$DEFAULT_ROLES_ROLE" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -o /dev/null -w "%{http_code}")
  
  if [ "$DEFAULT_ROLES_EXISTS" != "200" ]; then
    echo "Warning: Default roles composite role '$DEFAULT_ROLES_ROLE' does not exist."
    echo "This should be created automatically by Keycloak. You may need to restart Keycloak."
  else
    # Get current composites
    COMPOSITES_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$DEFAULT_ROLES_ROLE/composites" \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Check if tenant role is already in default roles
    if echo "$COMPOSITES_RESPONSE" | grep -q "\"id\":\"$TENANT_ROLE_ID\"" || echo "$COMPOSITES_RESPONSE" | grep -q "\"name\":\"tenant\""; then
      echo "Tenant role is already in default roles."
    else
      echo "Adding tenant role to default roles..."
      ADD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$DEFAULT_ROLES_ROLE/composites" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "[{\"id\":\"$TENANT_ROLE_ID\",\"name\":\"tenant\",\"composite\":false,\"clientRole\":false}]")
      
      HTTP_CODE=$(echo "$ADD_RESPONSE" | tail -1)
      if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "Tenant role added to default roles (HTTP $HTTP_CODE)."
      else
        echo "Warning: Unexpected response when adding tenant role: HTTP $HTTP_CODE"
        echo "Response: $(echo "$ADD_RESPONSE" | head -n -1)"
      fi
      
      # Verify it was added
      VERIFY_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles/$DEFAULT_ROLES_ROLE/composites" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
      if echo "$VERIFY_RESPONSE" | grep -q "\"name\":\"tenant\"" || echo "$VERIFY_RESPONSE" | grep -q "\"id\":\"$TENANT_ROLE_ID\""; then
        echo "✅ Verified: Tenant role is now in default roles composite."
      else
        echo "⚠️  Warning: Could not verify tenant role was added. Response: $VERIFY_RESPONSE"
      fi
    fi
  fi
else
  echo "Warning: Could not find tenant role ID. Skipping default role configuration."
fi

echo "✅ Keycloak initialization complete!"

