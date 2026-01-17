#!/bin/bash

# Start Docker services and provide instructions for webhook setup
# This script helps set up local development with VAPI webhooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting VAPI local development environment..."
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "⚠️  ngrok is not installed."
    echo ""
    echo "To use local endpoints as VAPI webhooks, you need a tunnel service."
    echo "Install ngrok:"
    echo "  macOS: brew install ngrok"
    echo "  Linux: Download from https://ngrok.com/download"
    echo "  Or use: snap install ngrok"
    echo ""
    echo "After installation, sign up at https://ngrok.com and configure:"
    echo "  ngrok config add-authtoken YOUR_AUTH_TOKEN"
    echo ""
    read -p "Press Enter to continue without ngrok, or Ctrl+C to install it first..."
fi

# Start Docker services
echo "📦 Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Check if services are healthy
echo "🔍 Checking service health..."

BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthz || echo "000")
if [ "$BACKEND_HEALTH" = "200" ]; then
    echo "✅ Backend API is running on http://localhost:8080"
else
    echo "⚠️  Backend API may not be ready yet (HTTP $BACKEND_HEALTH)"
fi

USECASES_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/health || echo "000")
if [ "$USECASES_HEALTH" = "200" ]; then
    echo "✅ Usecases Service is running on http://localhost:8082"
else
    echo "⚠️  Usecases Service may not be ready yet (HTTP $USECASES_HEALTH)"
fi

echo ""
echo "📋 Service URLs:"
echo "  Backend API:    http://localhost:8080"
echo "  Usecases:       http://localhost:8082"
echo "  Frontend:       http://localhost:3000"
echo "  Keycloak:       http://localhost:8081"
echo ""

# Check if ngrok is available
if command -v ngrok &> /dev/null; then
    echo "🌐 To expose Backend API for VAPI webhooks:"
    echo ""
    echo "  1. Start ngrok tunnel:"
    echo "     ngrok http 8080"
    echo ""
    echo "  2. Copy the HTTPS URL (e.g., https://abc123.ngrok-free.app)"
    echo ""
    echo "  3. Use as webhook URL when creating assistants:"
    echo "     https://abc123.ngrok-free.app/webhook"
    echo ""
    echo "  4. Set WEBHOOK_SECRET in .env file (generate with: openssl rand -hex 32)"
    echo ""
    echo "💡 Tip: You can also set serverUrl and serverUrlSecret per assistant"
    echo "   when creating them via the API."
    echo ""
    read -p "Start ngrok tunnel now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Starting ngrok tunnel..."
        echo "Your webhook URL will be shown below. Use: https://YOUR_URL/webhook"
        echo ""
        ngrok http 8080
    fi
else
    echo "📖 For webhook setup instructions, see: infra/LOCAL_WEBHOOK_SETUP.md"
    echo ""
    echo "Alternative tunnel services:"
    echo "  - localtunnel: npm install -g localtunnel && lt --port 8080"
    echo "  - Cloudflare Tunnel: cloudflared tunnel --url http://localhost:8080"
fi

echo ""
echo "✅ Local development environment is ready!"
echo ""
echo "📝 Useful commands:"
echo "  View logs:        docker-compose logs -f [service-name]"
echo "  Stop services:   docker-compose down"
echo "  Restart service: docker-compose restart [service-name]"

