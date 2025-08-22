# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based deployment of ERPNext, an open-source ERP system built on the Frappe framework. The repository provides a containerized solution for simplified installation and management of ERPNext using Docker Compose.

**Repository**: https://github.com/98labs/docker-erpnext

## Architecture

The application uses a microservices architecture with the following key services:

- **backend**: Main ERPNext/Frappe worker service (frappe/erpnext-worker)
- **frontend**: Nginx service for serving static assets and proxying requests (frappe/erpnext-nginx)
- **db**: MariaDB 10.6 database service
- **redis**: Redis service for caching and queue management
- **websocket**: Socket.io service for real-time communications (frappe/frappe-socketio)
- **queue-default/long/short**: Worker services for handling different job queues
- **scheduler**: Service for scheduled tasks
- **configurator**: One-time service that sets up common site configuration
- **create-site**: One-time service that creates the initial ERPNext site

All services connect through a Docker network specified by `APP_NETWORK` (default: erpnext-local).

## Key Configuration Files

- **docker-compose.yml**: Main orchestration file defining all services
- **.env**: Environment configuration (contains passwords and ports)
- **variables.json**: Deployment metadata and requirements
- **src/compose.yaml**: Base Frappe compose configuration template
- **src/overrides/**: Contains specific override configurations for different components

## Environment Variables

Critical variables in `.env`:
- `POWER_PASSWORD`: Master password used by other services (default: LocalDev123!)
- `APP_VERSION`: ERPNext version (v12, v13, v14)
- `APP_PASSWORD`: Administrator password (uses $POWER_PASSWORD)
- `APP_HTTP_PORT`: HTTP port for web access (default: 8080)
- `DB_MARIA_PASSWORD`: MariaDB root password (uses $POWER_PASSWORD)
- `APP_NAME`: Container name prefix (default: erpnext)
- `APP_NETWORK`: Docker network name (default: erpnext-local)
- `APP_DB_PARAM`: Database parameter (v12 uses "mariadb", v13+ uses "db")
- `APP_URL`: Application URL (default: localhost)
- `APP_USER`: Administrator username (default: Administrator)

## Common Development Commands

### Initial Setup
```bash
# Create the Docker network (first time only)
docker network create erpnext-local

# Start the application
docker-compose up -d
```

### Stopping the Application
```bash
docker-compose down
```

### Viewing Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
```

### Accessing the Database
```bash
docker exec -it erpnext-db mysql -u root -p
```

### Accessing the Backend Shell
```bash
docker exec -it erpnext-backend /bin/bash
```

### Bench Commands (from within backend container)
```bash
# Access Frappe/ERPNext console
bench --site frontend console

# Run migrations
bench --site frontend migrate

# Clear cache
bench --site frontend clear-cache

# Backup site
bench --site frontend backup
```

### Rebuilding After Version Change
When changing `APP_VERSION` in `.env`:
1. Stop containers: `docker-compose down`
2. Remove volumes: `docker volume prune` (CAUTION: This removes data)
3. Update `.env` with new version
4. Start containers: `docker-compose up -d`

## Important Notes

- **Internal Port**: Port 8000 is used internally for container communication - do not change this
- **External Port**: The external HTTP port is configured via `APP_HTTP_PORT` in `.env` (default: 8080)
- **Default Site**: The default site name is "frontend" (created by create-site service)
- **Database Parameter**: Changes based on version - v12 uses "mariadb", v13+ uses "db"
- **Restart Policy**: All containers use "on-failure" restart policy for resilience
- **Data Persistence**: Site data is persisted in Docker volumes (sites, assets, db-data, redis-data)
- **Network**: All services communicate through the `erpnext-local` Docker network
- **Default Credentials**: Administrator / LocalDev123!

## API Development

### Accessing APIs
ERPNext provides REST APIs accessible at `http://localhost:8080/api/`

### Common API Endpoints
- **Login**: `POST /api/method/login`
- **Resources**: `/api/resource/{DocType}`
- **Methods**: `/api/method/{method_path}`

### Testing APIs
```bash
# Login and get session
curl -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"usr":"Administrator","pwd":"LocalDev123!"}' \
  http://localhost:8080/api/method/login

# Use session for API calls
curl -b cookies.txt http://localhost:8080/api/resource/Item
```

### API Documentation
See [API_GUIDE.md](API_GUIDE.md) for comprehensive API documentation.

## Troubleshooting

### Port Conflicts
If port 8080 is already in use, modify `APP_HTTP_PORT` in `.env` to a different port.

### Network Issues
Ensure the Docker network exists:
```bash
docker network ls | grep erpnext-local
# If not found, create it:
docker network create erpnext-local
```

### Version Changes
When changing ERPNext versions, you must remove existing data:
```bash
docker-compose down
docker volume prune  # WARNING: Removes all data
# Update APP_VERSION in .env
docker-compose up -d
```