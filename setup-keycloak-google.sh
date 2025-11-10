#!/bin/bash

# Keycloak Google Identity Provider setup script for VAPI
# This script configures Google as an identity provider in Keycloak

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8081}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="${REALM_NAME:-vapi}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}"

if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
  echo "❌ Error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set"
  echo ""
  echo "To get Google OAuth credentials:"
  echo "1. Go to https://console.cloud.google.com/"
  echo "2. Create a new project or select an existing one"
  echo "3. Enable Google+ API"
  echo "4. Go to 'Credentials' → 'Create Credentials' → 'OAuth client ID'"
  echo "5. Choose 'Web application'"
  echo "6. Add authorized redirect URI: $KEYCLOAK_URL/realms/$REALM_NAME/broker/google/endpoint"
  echo "7. Copy the Client ID and Client Secret"
  echo ""
  echo "Then run:"
  echo "  GOOGLE_CLIENT_ID=your-client-id GOOGLE_CLIENT_SECRET=your-secret ./setup-keycloak-google.sh"
  exit 1
fi

echo "Setting up Google Identity Provider for Keycloak..."
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Realm: $REALM_NAME"
echo "Google Client ID: $GOOGLE_CLIENT_ID"

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

# Check if Google identity provider already exists
IDP_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/identity-provider/instances/google" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -o /dev/null -w "%{http_code}")

if [ "$IDP_EXISTS" = "200" ]; then
  echo "Google Identity Provider already exists. Updating..."
  
  # Update existing Google identity provider
  curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME/identity-provider/instances/google" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"alias\": \"google\",
      \"displayName\": \"Google\",
      \"providerId\": \"google\",
      \"enabled\": true,
      \"updateProfileFirstLoginMode\": \"on\",
      \"trustEmail\": true,
      \"storeToken\": false,
      \"addReadTokenRoleOnCreate\": false,
      \"authenticateByDefault\": false,
      \"linkOnly\": false,
      \"firstBrokerLoginFlowAlias\": \"first broker login\",
      \"config\": {
        \"clientId\": \"$GOOGLE_CLIENT_ID\",
        \"clientSecret\": \"$GOOGLE_CLIENT_SECRET\",
        \"hostedDomain\": \"\",
        \"useJwksUrl\": \"true\",
        \"acceptsPromptNoneForwardFromClient\": \"true\",
        \"disableUserInfo\": \"false\"
      }
    }" > /dev/null
  
  echo "Google Identity Provider updated."
else
  echo "Creating Google Identity Provider..."
  
  # Create Google identity provider
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/identity-provider/instances" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"alias\": \"google\",
      \"displayName\": \"Google\",
      \"providerId\": \"google\",
      \"enabled\": true,
      \"updateProfileFirstLoginMode\": \"on\",
      \"trustEmail\": true,
      \"storeToken\": false,
      \"addReadTokenRoleOnCreate\": false,
      \"authenticateByDefault\": false,
      \"linkOnly\": false,
      \"firstBrokerLoginFlowAlias\": \"first broker login\",
      \"config\": {
        \"clientId\": \"$GOOGLE_CLIENT_ID\",
        \"clientSecret\": \"$GOOGLE_CLIENT_SECRET\",
        \"hostedDomain\": \"\",
        \"useJwksUrl\": \"true\",
        \"acceptsPromptNoneForwardFromClient\": \"true\",
        \"disableUserInfo\": \"false\"
      }
    }" > /dev/null
  
  echo "Google Identity Provider created."
fi

echo ""
echo "✅ Google Identity Provider setup complete!"
echo ""
echo "Users can now sign in with Google on the Keycloak login page."
echo "The Google sign-in button will appear automatically on the login page."
echo ""
echo "To test:"
echo "1. Go to http://localhost:3000"
echo "2. Click 'Sign In'"
echo "3. You should see a 'Google' button on the Keycloak login page"

