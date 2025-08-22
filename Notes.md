# ERPNext Docker Deployment Notes

## Architecture Overview

ERPNext uses a microservices architecture with multiple containers working together:
- Backend worker services (Frappe/ERPNext)
- Frontend Nginx service
- MariaDB database
- Redis for caching and queues
- WebSocket service for real-time features
- Queue workers for background jobs
- Scheduler for periodic tasks

## Installation Process

The installation is automated through Docker Compose:

1. **Environment Configuration**: The `.env` file contains all necessary configuration variables
2. **Network Setup**: Uses a dedicated Docker network (`erpnext-local`) for container communication
3. **Service Orchestration**: The `docker-compose.yml` file orchestrates all services
4. **Initial Setup**: The `configurator` and `create-site` services handle initial configuration

## Key Configuration Files

### docker-compose.yml
Main orchestration file that defines all services and their relationships.

### .env
Environment variables including:
- `POWER_PASSWORD`: Master password
- `APP_VERSION`: ERPNext version (v12, v13, v14)
- `APP_HTTP_PORT`: External HTTP port
- `APP_NETWORK`: Docker network name

### src/compose.yaml
Base Frappe compose configuration template.

### src/overrides/
Contains specific override configurations for different components:
- `compose.erpnext.yaml`: ERPNext-specific overrides
- `compose.redis.yaml`: Redis configuration
- `compose.mariadb.yaml`: MariaDB configuration

## Common Operations

### Creating a New Site (Manual)
If you need to create additional sites:
```bash
docker compose exec backend bench new-site <site-name> --mariadb-root-password <password> --admin-password <admin-password>
```

### Backup and Restore
```bash
# Backup
docker compose exec backend bench --site frontend backup

# Restore
docker compose exec backend bench --site frontend restore <backup-file>
```

## Version Differences

### v12
- Uses `mariadb` as database parameter
- Older UI and features

### v13+
- Uses `db` as database parameter
- Modern UI with improved features
- Better performance

## Troubleshooting

### Image Issues
If images appear broken, ensure the frontend service is running and properly configured.

### Port 8000
Internal port 8000 is hardcoded in ERPNext - do not change it. Use `APP_HTTP_PORT` for external access.

### Site Creation
The default site is named "frontend" and is created automatically by the `create-site` service.

## Performance Tuning

### Memory Requirements
- Minimum: 4GB RAM
- Recommended: 8GB+ RAM for production

### Database Optimization
MariaDB configuration can be tuned via environment variables or custom configuration files.

### Redis Configuration
Redis is used for caching and queue management. Default configuration is suitable for most deployments.

## Security Considerations

1. **Change Default Passwords**: Always change the default `POWER_PASSWORD` in production
2. **Network Isolation**: The `erpnext-local` network provides isolation between containers
3. **SSL/TLS**: Consider using a reverse proxy (nginx/traefik) for SSL termination in production
4. **Firewall Rules**: Only expose necessary ports (typically just the HTTP port)

## References

- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework](https://frappeframework.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)