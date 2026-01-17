# Important Notes for Azure Deployment

## Service Discovery in Azure Container Apps

Unlike Docker Compose, Azure Container Apps don't use service names for internal communication. Instead:

1. **Internal Ingress**: Services with internal ingress can be accessed via their FQDN within the same environment
2. **External Ingress**: Services with external ingress are publicly accessible
3. **Service-to-Service**: Use the Container App FQDN or internal ingress URL

## Frontend Nginx Configuration

The frontend nginx needs to proxy to backend services. In Azure:

- **Option 1**: Use Container App FQDNs (requires services to have ingress enabled)
- **Option 2**: Use Azure Application Gateway or Front Door as a reverse proxy
- **Option 3**: Use Azure API Management

For the simplest setup, we use Container App FQDNs with internal ingress.

## Database Connections

### MongoDB (Cosmos DB)
- Use the connection string from Azure Portal
- Format: `mongodb://account:password@account.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb`
- The connection string includes SSL requirements

### PostgreSQL
- Use the FQDN: `server-name.postgres.database.azure.com`
- Username format: `username@server-name` (for flexible server)
- Enable SSL: Add `?sslmode=require` to connection string

## Keycloak Configuration

Keycloak needs:
1. **Public URL** for OAuth redirects
2. **Database connection** to PostgreSQL
3. **Hostname** set to the Container App FQDN

After deployment:
1. Get Keycloak URL
2. Update client redirect URIs in Keycloak admin console
3. Run initialization script (manually or via job)

## Environment Variables

Critical variables that must be set correctly:

### Backend
- `KEYCLOAK_URL`: Full URL including https://
- `VAPI_API_KEY`: Your VAPI API key
- `SERVICE_AUTH_TOKEN`: For service-to-service auth

### Usecases
- `MONGO_URI`: Full Cosmos DB connection string
- `API_URL`: Backend internal URL
- `KEYCLOAK_URL`: Keycloak URL

### Frontend (Build-time)
- `VITE_KEYCLOAK_URL`: Keycloak public URL
- `VITE_KEYCLOAK_REALM`: Realm name
- `VITE_KEYCLOAK_CLIENT_ID`: Client ID

## Networking Considerations

1. **Internal vs External Ingress**:
   - Frontend: External (public access)
   - Keycloak: External (for OAuth)
   - Backend: Internal (private)
   - Usecases: Internal (private)

2. **CORS Configuration**:
   - Keycloak needs to allow your frontend domain
   - Backend services need proper CORS headers

3. **SSL/TLS**:
   - Container Apps provide automatic SSL for external ingress
   - Internal ingress uses HTTP by default
   - Consider using Application Gateway for custom domains

## Cost Optimization Tips

1. **Use appropriate SKU sizes**:
   - Start with smaller sizes and scale up as needed
   - Use Burstable tier for PostgreSQL (cheaper)

2. **Enable auto-scaling**:
   - Set min-replicas to 0 for non-critical services
   - Use scale-to-zero for cost savings

3. **Monitor usage**:
   - Set up cost alerts
   - Review usage regularly
   - Use Azure Cost Management

## Security Best Practices

1. **Secrets Management**:
   - Use Azure Key Vault for sensitive data
   - Don't hardcode secrets in scripts
   - Use Managed Identity where possible

2. **Network Security**:
   - Use Private Endpoints for databases
   - Restrict public access where possible
   - Use Network Security Groups

3. **Authentication**:
   - Enable MFA for Azure accounts
   - Use role-based access control (RBAC)
   - Regularly rotate passwords and keys

## Troubleshooting

### Service can't connect to database
- Check firewall rules
- Verify connection string format
- Check SSL requirements

### Frontend can't reach backend
- Verify internal ingress is enabled
- Check Container App FQDN
- Verify nginx configuration

### Keycloak redirect issues
- Check redirect URIs in Keycloak
- Verify frontend URL matches
- Check CORS configuration

## Support Resources

- Azure Container Apps Documentation: https://docs.microsoft.com/azure/container-apps/
- Azure CLI Reference: https://docs.microsoft.com/cli/azure/
- Azure Support: https://azure.microsoft.com/support/

