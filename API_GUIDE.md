# ERPNext API Access Guide

## Overview
ERPNext provides comprehensive REST APIs for all its modules. The APIs follow RESTful conventions and return JSON responses.

**Important**: There is no browsable API index page at `/api/`. You must access specific endpoints directly.

## API Endpoints

### Base URL
```
http://localhost:8080
```

### Common API Endpoints

#### 1. **Authentication**
```bash
# Login
POST http://localhost:8080/api/method/login
{
  "usr": "Administrator",
  "pwd": "LocalDev123!"
}
```

#### 2. **Resource APIs**
All DocTypes (database tables) in ERPNext are accessible via REST:

```bash
# Get list of items
GET http://localhost:8080/api/resource/Item

# Get specific item
GET http://localhost:8080/api/resource/Item/{item_name}

# Create new item
POST http://localhost:8080/api/resource/Item

# Update item
PUT http://localhost:8080/api/resource/Item/{item_name}

# Delete item
DELETE http://localhost:8080/api/resource/Item/{item_name}
```

#### 3. **Method APIs**
Custom server methods can be called:
```bash
POST http://localhost:8080/api/method/{method_path}
```

## Authentication Methods

### 1. **Session-based Authentication**
After login, a session cookie is set which is used for subsequent requests.

### 2. **Token-based Authentication**
Generate API keys from the user settings:

1. Login to ERPNext UI
2. Go to Settings → My Settings
3. Scroll to "API Access" section
4. Generate API Secret
5. Use in requests:

```bash
curl -H "Authorization: token api_key:api_secret" \
     http://localhost:8080/api/resource/Item
```

### 3. **Basic Authentication**
```bash
curl -u Administrator:LocalDev123! \
     http://localhost:8080/api/resource/Item
```

## Live API Documentation

### 1. **Exploring Available DocTypes**
Get a list of all available DocTypes (tables/resources):
```bash
# After login
curl -b cookies.txt http://localhost:8080/api/resource/DocType
```

### 2. **Swagger/OpenAPI Documentation**
While ERPNext doesn't have built-in Swagger, you can explore APIs through:

- **Frappe Web UI**: After logging in, press `Ctrl+G` (or `Cmd+G` on Mac) to open the awesome bar and type any DocType name
- **Developer Console**: Access via browser DevTools to see API calls made by the UI

### 3. **Interactive Console**
Access the Python console to explore APIs:

```bash
# Enter the backend container
docker exec -it erpnext /bin/bash

# Start bench console
bench --site frontend console

# Example commands in console:
>>> frappe.get_all('Item')
>>> frappe.get_doc('Item', 'ITEM-001')
```

## Common API Operations

### Customer Management
```bash
# List customers
GET /api/resource/Customer

# Create customer
POST /api/resource/Customer
{
  "customer_name": "Test Customer",
  "customer_type": "Company",
  "customer_group": "All Customer Groups",
  "territory": "All Territories"
}
```

### Item Management
```bash
# List items
GET /api/resource/Item

# Create item
POST /api/resource/Item
{
  "item_code": "TEST-001",
  "item_name": "Test Item",
  "item_group": "All Item Groups",
  "stock_uom": "Nos"
}
```

### Sales Order
```bash
# Create sales order
POST /api/resource/Sales%20Order
{
  "customer": "Test Customer",
  "delivery_date": "2024-12-31",
  "items": [
    {
      "item_code": "TEST-001",
      "qty": 10,
      "rate": 100
    }
  ]
}
```

## API Response Format

### Success Response
```json
{
  "data": {
    // Response data
  }
}
```

### Error Response
```json
{
  "exc_type": "ValidationError",
  "exception": "Error details",
  "_server_messages": "..."
}
```

## Testing APIs

### Using cURL
```bash
# Login and save cookies
curl -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"usr":"Administrator","pwd":"LocalDev123!"}' \
  http://localhost:8080/api/method/login

# Use cookies for subsequent requests
curl -b cookies.txt \
  http://localhost:8080/api/resource/Item
```

### Using Postman
1. Import ERPNext collection (create your own based on endpoints above)
2. Set base URL to `http://localhost:8080`
3. Configure authentication in collection settings

### Using Python
```python
import requests

# Login
session = requests.Session()
login_response = session.post(
    'http://localhost:8080/api/method/login',
    json={'usr': 'Administrator', 'pwd': 'LocalDev123!'}
)

# Get items
items = session.get('http://localhost:8080/api/resource/Item')
print(items.json())
```

### Using Node.js/Axios (Recommended)

#### Simple Usage
```javascript
const { ERPNextSecureClient } = require('./secure_api_client');

async function example() {
    const client = new ERPNextSecureClient('http://localhost:8080');
    
    // Authenticate with API token (uses environment variables)
    await client.authenticateWithToken();
    
    // Get customers
    const customers = await client.get('/api/resource/Customer');
    console.log(customers.data);
    
    // Create new customer
    const newCustomer = await client.post('/api/resource/Customer', {
        customer_name: 'API Test Customer',
        customer_type: 'Individual'
    });
    
    await client.logout();
}

example().catch(console.error);
```

#### Advanced Usage with Caching and Retry
```javascript
const { ERPNextAdvancedSecureClient } = require('./secure_api_client');

async function advancedExample() {
    const client = new ERPNextAdvancedSecureClient('http://localhost:8080', {
        enableCache: true,        // Response caching
        retryAttempts: 3,        // Auto-retry failures  
        rateLimitPerMinute: 60   // Rate limiting
    });
    
    await client.authenticateWithToken();
    
    // First call hits API
    const customers = await client.get('/api/resource/Customer');
    
    // Second call uses cache (faster)
    const cachedCustomers = await client.get('/api/resource/Customer');
    
    await client.logout();
}
```

#### Environment Variables Setup
```bash
# Create .env file
echo 'ERPNEXT_API_KEY="your_key_here"' > .env
echo 'ERPNEXT_API_SECRET="your_secret_here"' >> .env

# Test environment variables
node test_env_vars.js
```

## Advanced Features

### 1. **Filters**
```bash
# Filter with conditions
GET /api/resource/Item?filters=[["item_group","=","Products"]]

# Multiple filters
GET /api/resource/Item?filters=[["item_group","=","Products"],["disabled","=",0]]
```

### 2. **Field Selection**
```bash
# Select specific fields
GET /api/resource/Item?fields=["item_code","item_name","standard_rate"]
```

### 3. **Pagination**
```bash
# Limit and offset
GET /api/resource/Item?limit_start=0&limit_page_length=20
```

### 4. **Sorting**
```bash
# Order by field
GET /api/resource/Item?order_by=modified%20desc
```

## WebSocket API

ERPNext also provides WebSocket connections for real-time updates:

```javascript
// Connect to WebSocket
const socket = io('http://localhost:8080', {
  withCredentials: true
});

// Listen for events
socket.on('connect', () => {
  console.log('Connected to ERPNext WebSocket');
});
```

## Rate Limiting

ERPNext implements rate limiting for API calls:
- Default: 60 requests per minute per IP
- Can be configured in site_config.json

## Security Best Practices

1. **Always use HTTPS in production**
2. **Generate and use API tokens instead of passwords**
3. **Implement IP whitelisting for API access**
4. **Regular token rotation**
5. **Monitor API usage logs**

## Debugging

### Enable Debug Mode
```bash
# In the backend container
bench --site frontend set-config developer_mode 1
bench --site frontend clear-cache
```

### View API Logs
```bash
# Check frappe logs
docker exec -it erpnext tail -f sites/frontend/logs/frappe.log
```

## References

- [Frappe REST API Documentation](https://frappeframework.com/docs/user/en/api/rest)
- [ERPNext API Reference](https://docs.erpnext.com/docs/user/manual/en/api)
- [Frappe Client Scripts](https://frappeframework.com/docs/user/en/desk/scripting/client-script)

## Need Help?

- Check the logs: `docker compose logs -f backend`
- Access the console: `docker exec -it erpnext bench --site frontend console`
- Visit the [ERPNext Forum](https://discuss.erpnext.com/) for community support