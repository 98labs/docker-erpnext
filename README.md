# ERPNext on Docker with Complete API Integration

## Introduction

This repository provides a comprehensive Docker-based deployment solution for [ERPNext](https://erpnext.com/), an open-source ERP system built on the [Frappe Framework](https://frappeframework.com/). 

### 🌟 **What's Included:**
- ✅ **Complete ERPNext Docker deployment**
- ✅ **771 documented API endpoints** across all modules
- ✅ **Production-ready API clients** (Python + Node.js/Axios)
- ✅ **Enterprise-grade security** practices
- ✅ **Comprehensive documentation** and examples

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

## 🚀 Quick Start

### Prerequisites

Ensure you have Docker and Docker Compose installed:

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

1. **Clone the repository:**
```bash
git clone --depth=1 https://github.com/98labs/docker-erpnext
cd docker-erpnext
```

2. **Create the Docker network:**
```bash
docker network create erpnext-local
```

3. **Configure environment variables (optional):**
Edit the `.env` file to customize your deployment:
- `POWER_PASSWORD`: Master password for all services (default: LocalDev123!)
- `APP_HTTP_PORT`: HTTP port for web access (default: 8080)
- `APP_VERSION`: ERPNext version - v12, v13, or v14 (default: v14)
- `APP_NAME`: Container name prefix (default: erpnext)
- `APP_NETWORK`: Docker network name (default: erpnext-local)

4. **Start the services:**
```bash
docker-compose up -d
```

## 📱 Usage

After deployment completes (may take a few minutes for initial setup), you can access ERPNext at: `http://localhost:8080` (or your configured port)

**Note**: The initial setup creates the site and configures the database. Monitor progress with:
```bash
docker-compose logs -f create-site
```

### Default Credentials

| Username | Password |
| -------- | -------- |
| Administrator | LocalDev123! |

## 🔌 Complete API Integration

ERPNext provides comprehensive REST APIs for integration with **771 DocTypes** across all modules.

### 📚 Documentation Files:
- **[API_ENDPOINTS.md](API_ENDPOINTS.md)** - Complete list of all API endpoints (771 DocTypes)
- **[API_GUIDE.md](API_GUIDE.md)** - Detailed usage guide with examples
- **[API_SECURITY.md](API_SECURITY.md)** - Security best practices and authentication methods
- **[NODEJS_API_CLIENT.md](NODEJS_API_CLIENT.md)** - Complete Node.js/Axios client guide

### 🔐 Security Recommendations:
- **Production**: Use API tokens (not cookies) - `Authorization: token key:secret`
- **Web Apps**: Use session cookies with CSRF protection
- **Mobile Apps**: Use OAuth 2.0
- **Always**: Use HTTPS, never HTTP

### 🚀 API Client Quick Start:

#### **Python Client:**
```bash
# Test secure API access (Python)
python3 secure_api_client.py

# Generate complete API documentation
python3 generate_api_docs.py

# Basic API testing
./test_api.sh
```

#### **Node.js/Axios Client:**
```bash
# Install dependencies
npm install axios dotenv

# Setup environment
cp .env.example .env  # Edit with your API keys

# Test secure API access (Node.js)
node secure_api_client.js

# Run practical examples
node examples/api_examples.js

# Test environment variables
node test_env_vars.js
```

### 🔑 **API Authentication Setup:**

1. **Generate API Keys:**
   - Login to ERPNext → Settings → My Settings
   - Scroll to "API Access" section → Generate Keys
   - Copy API Key and Secret

2. **Set Environment Variables:**
```bash
# Method 1: .env file (recommended)
echo 'ERPNEXT_API_KEY="your_key_here"' > .env
echo 'ERPNEXT_API_SECRET="your_secret_here"' >> .env

# Method 2: Export in terminal
export ERPNEXT_API_KEY="your_key_here"
export ERPNEXT_API_SECRET="your_secret_here"
```

3. **Use in your code:**
```javascript
// Node.js with Axios
const { ERPNextSecureClient } = require('./secure_api_client');
const client = new ERPNextSecureClient();
await client.authenticateWithToken(); // Uses env vars automatically
const customers = await client.get('/api/resource/Customer');
```

```python
# Python with requests
from secure_api_client import ERPNextSecureClient
client = ERPNextSecureClient()
client.authenticate_with_token()  # Uses env vars automatically
customers = client.get('/api/resource/Customer')
```

## 📊 Project Structure

### 📁 **Core Files:**
```
docker-erpnext/
├── docker-compose.yml          # Main orchestration
├── .env                        # Environment configuration
├── CLAUDE.md                   # Development guide
└── README.md                   # This file

📋 API Documentation:
├── API_ENDPOINTS.md            # All 771 DocTypes documented
├── API_GUIDE.md               # Usage guide with examples  
├── API_SECURITY.md            # Security best practices
└── NODEJS_API_CLIENT.md       # Node.js client documentation

🐍 Python API Client:
├── secure_api_client.py        # Production-ready Python client
├── generate_api_docs.py        # Auto-generate API docs
├── test_api.sh                # Basic API tests
└── discover_api_endpoints.sh   # API discovery

🟨 Node.js/Axios API Client:
├── secure_api_client.js        # Production-ready Node.js client
├── package.json               # NPM configuration
├── test_env_vars.js           # Environment variable testing
└── examples/
    ├── api_examples.js         # Comprehensive examples
    └── simple_usage.js         # Quick start example

📄 Configuration:
├── .env.example               # Environment template
├── variables.json             # Deployment metadata
└── src/                       # ERPNext configuration overrides
```

### 🔧 **Available Scripts:**

```bash
# Docker Operations
docker-compose up -d           # Start ERPNext
docker-compose down           # Stop ERPNext
docker-compose logs -f        # View logs

# API Documentation
python3 generate_api_docs.py  # Generate/update API docs
./discover_api_endpoints.sh   # Discover endpoints

# API Testing
./test_api.sh                 # Basic cURL tests
python3 secure_api_client.py  # Python client demo
node secure_api_client.js     # Node.js client demo
node examples/api_examples.js # Comprehensive examples
node test_env_vars.js         # Environment test

# NPM Scripts
npm install                   # Install Node.js dependencies
npm run demo                  # Run Node.js demo
npm run test-api             # Run API examples
```

## 🏗️ Architecture

This deployment uses a microservices architecture with the following containers:

### 🐳 **Docker Services:**
- **backend**: Main ERPNext/Frappe worker service
- **frontend**: Nginx service for serving static assets
- **db**: MariaDB 10.6 database
- **redis**: Redis cache and queue management
- **websocket**: Socket.io for real-time features
- **queue-default/long/short**: Background job workers
- **scheduler**: Scheduled tasks
- **configurator**: Initial configuration (runs once)
- **create-site**: Site creation (runs once)

All services communicate through the `erpnext-local` Docker network.

### 📡 **API Architecture:**
- **771 DocTypes** across 37 modules
- **RESTful endpoints** following standard conventions
- **Multiple authentication** methods (OAuth, Tokens, Sessions)
- **Comprehensive security** with audit logging
- **Rate limiting** and performance optimization

## 📋 Common Operations

### Docker Management

#### Viewing Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
```

#### Accessing Containers
```bash
# Access backend shell
docker exec -it erpnext-backend /bin/bash

# Access database
docker exec -it erpnext-db mysql -u root -p
```

#### Bench Commands (from within backend container)
```bash
# Access Frappe/ERPNext console
bench --site frontend console

# Clear cache
bench --site frontend clear-cache

# Run migrations
bench --site frontend migrate

# Backup site
bench --site frontend backup
```

### API Operations

#### Quick API Tests
```bash
# Test authentication
curl -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"usr":"Administrator","pwd":"LocalDev123!"}' \
  http://localhost:8080/api/method/login

# Get customers
curl -b cookies.txt http://localhost:8080/api/resource/Customer

# Get items with filters
curl -b cookies.txt \
  "http://localhost:8080/api/resource/Item?filters=[[\"disabled\",\"=\",0]]&limit_page_length=5"
```

## 🛠️ Troubleshooting

### Container Issues
**Container fails to start:**
```bash
# Check if network exists
docker network ls | grep erpnext-local

# Create network if missing
docker network create erpnext-local

# Check container status
docker-compose ps
```

**Cannot access the application:**
- Verify all containers are running: `docker-compose ps`
- Check logs for errors: `docker-compose logs`
- Ensure port 8080 is not blocked by firewall

### API Issues
**Authentication failed:**
```bash
# Generate new API keys in ERPNext UI
# Settings → My Settings → API Access → Generate Keys

# Test API keys
node test_env_vars.js
python3 secure_api_client.py
```

**404 errors on API calls:**
- Remember: No browsable API at `/api/`
- Use specific endpoints: `/api/resource/DocType`
- Check [API_ENDPOINTS.md](API_ENDPOINTS.md) for available DocTypes

### Network Issues
**Docker network problems:**
```bash
# Recreate network
docker network rm erpnext-local
docker network create erpnext-local
docker-compose up -d
```

## ❓ FAQ

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
docker volume prune  # WARNING: Removes all data
# Update .env
docker-compose up -d
```

### Which authentication method should I use for APIs?
- **API Tokens**: Best for server-to-server and mobile apps
- **Session Cookies**: Only for web applications (with CSRF protection)
- **OAuth 2.0**: Best for third-party integrations
- **Never use Basic Auth** in production

### How do I get API documentation for all endpoints?
Run the documentation generator:
```bash
python3 generate_api_docs.py
```
This creates `API_ENDPOINTS.md` with all 771 DocTypes documented.

## 📖 Documentation

### Official ERPNext/Frappe Documentation:
- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Documentation](https://frappeframework.com/docs)
- [Frappe REST API Documentation](https://frappeframework.com/docs/user/en/api/rest)

### Docker Documentation:
- [Docker Compose Documentation](https://docs.docker.com/compose/)

### This Repository's Documentation:
- [CLAUDE.md](CLAUDE.md) - Complete development guide
- [API_ENDPOINTS.md](API_ENDPOINTS.md) - All API endpoints (771 DocTypes)
- [API_GUIDE.md](API_GUIDE.md) - API usage guide with examples
- [API_SECURITY.md](API_SECURITY.md) - Security best practices
- [NODEJS_API_CLIENT.md](NODEJS_API_CLIENT.md) - Node.js client guide
- [Notes.md](Notes.md) - Architecture and deployment notes

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup:
```bash
# Clone and setup
git clone https://github.com/98labs/docker-erpnext
cd docker-erpnext

# Install API client dependencies
npm install axios dotenv

# Setup environment
cp .env.example .env  # Edit with your settings

# Start development environment
docker-compose up -d

# Test API clients
python3 secure_api_client.py
node secure_api_client.js
```

## 💬 Support

For issues related to:
- **This Docker setup**: Open an issue in this repository
- **ERPNext application**: Visit the [ERPNext Forum](https://discuss.erpnext.com/)
- **Frappe Framework**: Visit the [Frappe GitHub](https://github.com/frappe/frappe)
- **API Integration**: Check [API_GUIDE.md](API_GUIDE.md) and [API_SECURITY.md](API_SECURITY.md)

## 📄 License

This Docker deployment configuration is open source. ERPNext is licensed under the GNU GPLv3 License.

---

## 🎯 **Quick Summary**

This repository provides:
- ✅ **Complete ERPNext Docker deployment** with security best practices
- ✅ **771 documented API endpoints** with auto-discovery tools  
- ✅ **Production-ready API clients** in Python and Node.js/Axios
- ✅ **Enterprise-grade security** with token authentication
- ✅ **Comprehensive documentation** with real-world examples
- ✅ **Complete testing suite** for API integration

**Get started in 3 steps:**
1. `docker network create erpnext-local && docker-compose up -d`
2. `cp .env.example .env` (add your API keys)
3. `node secure_api_client.js` or `python3 secure_api_client.py`