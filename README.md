# ERPNext on Docker

## Introduction

This repository provides a Docker-based deployment solution for [ERPNext](https://erpnext.com/), an open-source ERP system built on the [Frappe Framework](https://frappeframework.com/). It simplifies the installation and initialization process using Docker Compose.

## System Requirements

The following are the minimal [recommended requirements](https://github.com/frappe/bench):

* **OS**: Red Hat, CentOS, Debian, Ubuntu or other Linux OS
* **Public Cloud**: AWS, Azure, Google Cloud, Alibaba Cloud, and other major cloud providers
* **Private Cloud**: KVM, VMware, VirtualBox, OpenStack
* **ARCH**: Linux x86-64, ARM 32/64, Windows x86-64, IBM POWER8, x86/i686
* **RAM**: 8 GB or more
* **CPU**: 2 cores or higher
* **HDD**: at least 20 GB of free space
* **Swap file**: at least 2 GB
* **Bandwidth**: more fluent experience over 100M

## QuickStart

### Prerequisites

Ensure you have Docker and Docker Compose installed. If not, you can install them using:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
sudo systemctl enable docker
sudo systemctl start docker

# Setup docker-compose alias for Docker Compose V2
alias docker-compose='docker compose'
echo "alias docker-compose='docker compose'" >> /etc/profile.d/docker-compose.sh
source /etc/profile.d/docker-compose.sh
```

### Install ERPNext

1. Clone the repository:
```bash
git clone --depth=1 https://github.com/98labs/docker-erpnext
cd docker-erpnext
```

2. Create the Docker network:
```bash
docker network create erpnext-local
```

3. Configure environment variables (optional):
Edit the `.env` file to customize your deployment:
- `POWER_PASSWORD`: Master password for all services (default: LocalDev123!)
- `APP_HTTP_PORT`: HTTP port for web access (default: 8080)
- `APP_VERSION`: ERPNext version - v12, v13, or v14 (default: v14)
- `APP_NAME`: Container name prefix (default: erpnext)
- `APP_NETWORK`: Docker network name (default: erpnext-local)

4. Start the services:
```bash
docker-compose up -d
```

## Usage

After deployment completes (may take a few minutes for initial setup), you can access ERPNext at: `http://localhost:8080` (or your configured port)

**Note**: The initial setup creates the site and configures the database. Monitor progress with:
```bash
docker-compose logs -f create-site
```

### Default Credentials

| Username | Password |
| -------- | -------- |
| Administrator | LocalDev123! |

### Services and Ports

| Service | Port | Use | Necessity |
| ------- | ---- | --- | --------- |
| ERPNext Web | 8080 | Browser access to ERPNext | Required |
| MariaDB | 3306 | Database access | Required |
| Redis | 6379 | Cache and queue management | Required |
| WebSocket | 9000 | Real-time communications | Required |

### Common Operations

#### Viewing Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
```

#### Accessing the Backend Shell
```bash
docker exec -it erpnext-backend /bin/bash
```

#### Bench Commands
From within the backend container:
```bash
# Access Frappe/ERPNext console
bench --site frontend console

# Clear cache
bench --site frontend clear-cache

# Run migrations
bench --site frontend migrate
```

## Troubleshooting

### Container fails to start
Check if the network exists:
```bash
docker network ls | grep erpnext-local
```
If not found, create it:
```bash
docker network create erpnext-local
```

### Cannot access the application
- Verify all containers are running: `docker-compose ps`
- Check logs for errors: `docker-compose logs`
- Ensure port 8080 is not blocked by firewall

## FAQ

### Do I need to change the password before docker-compose up?
Yes, you should modify all database passwords and application passwords in the `.env` file for production use.

### Docker running failed due to port conflict?
You should modify the `APP_HTTP_PORT` in the `.env` file and run `docker-compose up -d` again.

### Why does ERPNext use port 8000 internally?
Port 8000 is used internally for container communication. Changing it causes errors. The external port is configured via `APP_HTTP_PORT`.

### How do I run a different ERPNext version?
Change `APP_VERSION` in the `.env` file to v12, v13, or v14. Note: You must remove existing volumes before changing versions:
```bash
docker-compose down
docker volume prune
# Update .env
docker-compose up -d
```

## Architecture

This deployment uses a microservices architecture with the following containers:
- **backend**: Main ERPNext/Frappe worker service
- **frontend**: Nginx service for serving static assets
- **db**: MariaDB 10.6 database
- **redis**: Redis cache and queue management
- **websocket**: Socket.io for real-time features
- **queue-default/long/short**: Background job workers
- **scheduler**: Scheduled tasks
- **configurator**: Initial configuration (runs once)
- **create-site**: Site creation (runs once)

## Documentation

- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Documentation](https://frappeframework.com/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues related to:
- **This Docker setup**: Open an issue in this repository
- **ERPNext application**: Visit the [ERPNext Forum](https://discuss.erpnext.com/)
- **Frappe Framework**: Visit the [Frappe GitHub](https://github.com/frappe/frappe)

## License

This Docker deployment configuration is open source. ERPNext is licensed under the GNU GPLv3 License.