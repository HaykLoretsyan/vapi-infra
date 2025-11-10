# VAPI Infrastructure

This directory contains the Docker Compose configuration for the VAPI application stack.

## Services

- **Backend**: Go-based REST API service (port 8080)
- **Frontend**: React/Vite application served via Nginx (port 3000)
- **Keycloak**: Identity and access management (port 8081)
- **PostgreSQL**: Database for Keycloak

## Quick Start

1. Copy the example environment file:
   ```bash
   cp env.example .env
   ```

2. Edit `.env` and set your configuration values, especially:
   - `VAPI_API_KEY`: Your VAPI API key (required)

3. Start all services:
   ```bash
   docker-compose up -d
   ```

4. Access the services:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8080
   - Keycloak Admin Console: http://localhost:8081
     - Username: admin (or value from `KEYCLOAK_ADMIN`)
     - Password: admin (or value from `KEYCLOAK_ADMIN_PASSWORD`)

## Commands

### Start services
```bash
docker-compose up -d
```

### Stop services
```bash
docker-compose stop
```

### Stop and remove services
```bash
docker-compose down
```

### Stop and remove services with volumes
```bash
docker-compose down -v
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f keycloak
```

### Rebuild services
```bash
# Rebuild all services
docker-compose build

# Rebuild specific service
docker-compose build backend
docker-compose build frontend
```

### Check service status
```bash
docker-compose ps
```

## Keycloak Setup

After starting Keycloak, you need to set up the realm and client for authentication:

### Automatic Setup (Recommended)

Run the setup script to automatically configure Keycloak:

```bash
# Wait for Keycloak to be ready (about 30-60 seconds after starting)
sleep 60

# Run the setup script
./setup-keycloak.sh
```

The script will:
- Create a realm named `vapi`
- Create a client named `vapi-frontend`
- Configure redirect URIs and web origins
- Enable registration and login

### Manual Setup

Alternatively, you can set up Keycloak manually:

1. Access the admin console at http://localhost:8081
2. Login with username `admin` and password `admin` (or values from your `.env`)
3. Create a new realm:
   - Click "Create Realm"
   - Name it `vapi` (or your preferred realm name)
   - Enable "User registration"
   - Save
4. Create a client:
   - Go to "Clients" → "Create client"
   - Client ID: `vapi-frontend`
   - Client authentication: OFF (public client)
   - Authorization: OFF
   - Next → Enable "Standard flow" and "Direct access grants"
   - Valid redirect URIs: `http://localhost:3000/*`
   - Web origins: `http://localhost:3000`
   - Save

### Environment Variables

Make sure your frontend has the correct Keycloak configuration in `.env`:

```bash
VITE_KEYCLOAK_URL=http://localhost:8081
VITE_KEYCLOAK_REALM=vapi
VITE_KEYCLOAK_CLIENT_ID=vapi-frontend
```

Rebuild the frontend after setting these variables:
```bash
docker-compose build frontend
docker-compose up -d frontend
```

## Google Sign-In Setup

To enable Google sign-in, you need to:

1. **Get Google OAuth Credentials:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable Google+ API
   - Go to "Credentials" → "Create Credentials" → "OAuth client ID"
   - Choose "Web application"
   - Add authorized redirect URI: `http://localhost:8081/realms/vapi/broker/google/endpoint`
   - Copy the Client ID and Client Secret

2. **Set environment variables:**
   ```bash
   GOOGLE_CLIENT_ID=your-google-client-id
   GOOGLE_CLIENT_SECRET=your-google-client-secret
   ```

3. **Run the setup script:**
   ```bash
   ./setup-keycloak-google.sh
   ```

   Or set the variables inline:
   ```bash
   GOOGLE_CLIENT_ID=your-id GOOGLE_CLIENT_SECRET=your-secret ./setup-keycloak-google.sh
   ```

4. **Test Google Sign-In:**
   - Go to http://localhost:3000
   - Click "Continue with Google" button
   - You should be redirected to Google's login page

## Environment Variables

See `.env.example` for all available configuration options.

## Troubleshooting

### Backend fails to start
- Ensure `VAPI_API_KEY` is set in `.env`
- Check backend logs: `docker-compose logs backend`

### Frontend can't connect to backend
- Verify backend is running: `docker-compose ps`
- Check network connectivity: services should be on the same Docker network

### Keycloak not accessible
- Wait for Keycloak to fully start (can take 30-60 seconds)
- Check Keycloak logs: `docker-compose logs keycloak`
- Verify PostgreSQL is healthy: `docker-compose ps postgres`

## Development

For local development, you may want to mount source code as volumes for hot-reloading. This can be added to the docker-compose.yml file if needed.

