# Using Local Docker Endpoints as VAPI Webhooks

This guide explains how to use your local Docker deployment endpoints as webhooks for VAPI.

## Understanding the Architecture

**Important**: The webhook endpoint is on the **Backend API** service, not the Usecases service:

- **Backend API**: Receives webhooks from VAPI at `/webhook` (port 8080)
- **Usecases Service**: Receives forwarded webhooks from Backend API internally

When VAPI sends a webhook, it goes to:
```
VAPI → Backend API (/webhook) → Usecases Service (internal forwarding)
```

**Note**: Even though you might want to use the "usecases endpoint", VAPI webhooks must go to the Backend API. The Backend API then forwards relevant webhooks to the Usecases service internally. This is by design - the Backend API acts as the entry point for all external webhooks.

## The Challenge

VAPI is an **external service** that needs to reach your local machine. Since `localhost` or Docker service names aren't accessible from the internet, you need a **tunnel** to expose your local service.

## Solution: Use a Tunnel Service

### Option 1: ngrok (Recommended)

**ngrok** creates a secure tunnel to your local machine.

#### Installation

```bash
# macOS
brew install ngrok

# Linux
# Download from https://ngrok.com/download
# Or use snap: snap install ngrok

# Windows
# Download from https://ngrok.com/download
```

#### Setup

1. **Sign up for free account** at https://ngrok.com (free tier allows 1 tunnel)

2. **Get your authtoken** from https://dashboard.ngrok.com/get-started/your-authtoken

3. **Configure ngrok**:
   ```bash
   ngrok config add-authtoken YOUR_AUTH_TOKEN
   ```

4. **Start your Docker services**:
   ```bash
   cd infra
   docker-compose up
   ```

5. **Create tunnel to Backend API** (port 8080):
   ```bash
   ngrok http 8080
   ```

   This will output something like:
   ```
   Forwarding  https://abc123.ngrok-free.app -> http://localhost:8080
   ```

6. **Use the ngrok URL as webhook**:
   ```
   https://abc123.ngrok-free.app/webhook
   ```

#### For Usecases Service (if needed directly)

If you need to expose usecases service directly (port 8082):
```bash
ngrok http 8082
```

### Option 2: localtunnel (Free, No Signup)

**localtunnel** is free and doesn't require signup, but URLs change each time.

#### Installation

```bash
npm install -g localtunnel
```

#### Usage

```bash
# Expose Backend API (port 8080)
lt --port 8080

# This will output:
# your url is: https://random-name.loca.lt
```

**Note**: URLs change each time you restart, so you'll need to update webhook URLs.

### Option 3: Cloudflare Tunnel (Free, Persistent URLs)

**Cloudflare Tunnel** provides persistent URLs and is free.

#### Installation

```bash
# Download cloudflared from https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
```

#### Usage

```bash
# Expose Backend API
cloudflared tunnel --url http://localhost:8080
```

## Configuration Steps

### 1. Start Local Services

```bash
cd infra
docker-compose up
```

Verify services are running:
- Backend API: http://localhost:8080
- Usecases Service: http://localhost:8082
- Frontend: http://localhost:3000

### 2. Start Tunnel

Using ngrok (example):
```bash
ngrok http 8080
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok-free.app`)

### 3. Configure Webhook URL

You have two options:

#### Option A: Set in Environment Variable (for default)

Update `infra/.env`:
```bash
WEBHOOK_URL=https://abc123.ngrok-free.app/webhook
WEBHOOK_SECRET=your-webhook-secret-here
```

Then restart backend:
```bash
docker-compose restart backend
```

#### Option B: Set Per Assistant (Recommended for Testing)

When creating an assistant via API, include `serverUrl` and `serverUrlSecret`:

```json
{
  "name": "My Assistant",
  "model": { ... },
  "voice": { ... },
  "serverUrl": "https://abc123.ngrok-free.app/webhook",
  "serverUrlSecret": "your-webhook-secret-here"
}
```

### 4. Update Assistant Webhook (if already created)

If you already created an assistant, update it via the VAPI API or your frontend to set the webhook URL.

## Testing the Setup

### 1. Test Webhook Endpoint Directly

```bash
curl -X POST https://abc123.ngrok-free.app/webhook \
  -H "Content-Type: application/json" \
  -H "X-Vapi-Signature: test-signature" \
  -d '{"message": {"type": "status-update"}}'
```

### 2. Check Backend Logs

```bash
docker-compose logs -f backend
```

You should see webhook requests being received.

### 3. Check Usecases Logs

```bash
docker-compose logs -f usecases
```

You should see forwarded webhook requests.

## Important Notes

### Webhook Secret

The webhook secret must match between:
- What you set in `WEBHOOK_SECRET` environment variable
- What you set in `serverUrlSecret` when creating assistants
- What VAPI uses to sign webhooks

Generate a secure secret:
```bash
openssl rand -hex 32
```

### ngrok Free Tier Limitations

- **1 tunnel at a time**
- **URLs change** when you restart (unless you use paid plan)
- **Request inspection** available in dashboard
- **HTTPS included** (free)

### Persistent URLs

For persistent URLs (same URL every time):
- Use **ngrok paid plan** (~$8/month)
- Use **Cloudflare Tunnel** (free, but more setup)
- Use **localtunnel** with custom subdomain (paid)

### Security Considerations

1. **Webhook Secret**: Always use a strong secret
2. **HTTPS**: ngrok provides HTTPS automatically
3. **IP Whitelisting**: Not possible with tunnels (use secret verification)
4. **Rate Limiting**: Consider rate limiting on your backend

## Troubleshooting

### Webhook Not Received

1. **Check tunnel is running**:
   ```bash
   curl https://abc123.ngrok-free.app/healthz
   ```

2. **Check backend is running**:
   ```bash
   curl http://localhost:8080/healthz
   ```

3. **Check ngrok dashboard**: https://dashboard.ngrok.com/status/tunnels

4. **Check backend logs**:
   ```bash
   docker-compose logs backend | grep webhook
   ```

### Signature Verification Failing

1. **Verify secret matches**:
   - Check `WEBHOOK_SECRET` in `.env`
   - Check `serverUrlSecret` in assistant config
   - Check VAPI dashboard webhook secret

2. **Check signature header**:
   ```bash
   docker-compose logs backend | grep signature
   ```

### Usecases Not Receiving Webhooks

1. **Check backend forwards to usecases**:
   ```bash
   docker-compose logs backend | grep usecases
   ```

2. **Check usecases is running**:
   ```bash
   curl http://localhost:8082/health
   ```

3. **Check internal network**:
   ```bash
   docker-compose exec backend ping usecases
   ```

## Alternative: Use Azure Deployment for Webhooks

If you need persistent webhooks without tunnels:

1. Deploy to Azure (see `infra/azure/` documentation)
2. Use Azure Container Apps FQDN as webhook URL
3. No tunnel needed, always accessible

## Quick Start Script

Create `infra/start-with-webhook.sh`:

```bash
#!/bin/bash

# Start Docker services
cd infra
docker-compose up -d

# Wait for services to be ready
sleep 5

# Start ngrok tunnel
echo "Starting ngrok tunnel..."
echo "Your webhook URL will be: https://YOUR_NGROK_URL.ngrok-free.app/webhook"
ngrok http 8080
```

Then:
```bash
chmod +x infra/start-with-webhook.sh
./infra/start-with-webhook.sh
```

