# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based deployment of ERPNext, an open-source ERP system built on the Frappe framework. The repository provides a Cloud Native solution for simplified installation and management of ERPNext using Docker Compose.

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
- `APP_VERSION`: ERPNext version (v12, v13, v14)
- `APP_PASSWORD`: Administrator password
- `APP_HTTP_PORT`: HTTP port for web access (default: 9001)
- `DB_MARIA_PASSWORD`: MariaDB root password
- `APP_NAME`: Container name prefix (default: erpnext)
- `APP_NETWORK`: Docker network name (default: erpnext-local)

## Common Development Commands

### Starting the Application
```bash
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
docker exec -it erpnext /bin/bash
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

- Port 8000 is used internally despite appearing non-standard - changing it causes container communication errors
- The default site name is "frontend" (created by create-site service)
- Database parameter changes based on version: v12 uses "mariadb", v13+ uses "db"
- All containers use restart policy "on-failure" for resilience
- Site data is persisted in Docker volumes (sites, assets, db-data, redis-data)