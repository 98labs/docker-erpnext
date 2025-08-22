# ERPNext Secure API Client - Node.js/Axios Version

A production-ready, secure API client for ERPNext built with Node.js and Axios, featuring comprehensive security practices, error handling, and performance optimizations.

## 🚀 Quick Start

### Installation

```bash
# Install dependencies
npm install axios dotenv

# Copy environment template
cp .env.example .env

# Edit .env with your credentials
nano .env
```

### Basic Usage

```javascript
const { ERPNextSecureClient } = require('./secure_api_client');

async function example() {
    const client = new ERPNextSecureClient('http://localhost:8080');
    
    // Authenticate with API token (recommended)
    await client.authenticateWithToken();
    
    // Get customers
    const customers = await client.get('/api/resource/Customer');
    console.log(customers.data);
    
    // Create new customer
    const newCustomer = await client.post('/api/resource/Customer', {
        customer_name: 'Test Customer',
        customer_type: 'Individual'
    });
    
    await client.logout();
}
```

## 🔐 Authentication Methods

### 1. API Token Authentication (Recommended)

```javascript
// Using environment variables (.env file)
const client = new ERPNextSecureClient();
await client.authenticateWithToken(); // Uses ERPNEXT_API_KEY and ERPNEXT_API_SECRET

// Or pass credentials directly
await client.authenticateWithToken('your_api_key', 'your_api_secret');
```

### 2. Session Authentication (Web Apps)

```javascript
await client.loginWithCredentials('username', 'password');
```

## 🛡️ Security Features

### Built-in Security
- ✅ **HTTPS Enforcement**: Warns about HTTP usage
- ✅ **Request/Response Logging**: Audit trail for security
- ✅ **Error Handling**: Secure error messages without data leakage
- ✅ **Rate Limiting**: Prevents API abuse
- ✅ **Request Timeouts**: Prevents hanging requests
- ✅ **Input Validation**: Validates all inputs

### Authentication Security
- ✅ **Token-based Auth**: Stateless and secure
- ✅ **Session Management**: Proper session handling for web apps
- ✅ **Credential Protection**: Never logs sensitive data
- ✅ **Auto-logout**: Cleans up sessions

## 📊 Advanced Features

### Advanced Client with Caching and Retry Logic

```javascript
const { ERPNextAdvancedSecureClient } = require('./secure_api_client');

const client = new ERPNextAdvancedSecureClient('http://localhost:8080', {
    retryAttempts: 3,           // Retry failed requests
    retryDelay: 1000,          // Delay between retries (ms)
    enableCache: true,         // Enable response caching
    cacheTimeout: 300000,      // Cache timeout (5 minutes)
    rateLimitPerMinute: 60     // Rate limit requests
});

await client.authenticateWithToken();

// First call hits API
await client.get('/api/resource/Customer');

// Second call uses cache
await client.get('/api/resource/Customer');
```

### Performance Features
- 🚀 **Response Caching**: Reduces API calls
- 🔄 **Automatic Retries**: Handles temporary failures
- ⏱️ **Rate Limiting**: Respects API limits
- 📈 **Request Tracking**: Performance monitoring

## 📋 Practical Examples

### Customer Management

```javascript
// Get all active customers
const customers = await client.get('/api/resource/Customer', {
    filters: JSON.stringify([['disabled', '=', 0]]),
    fields: JSON.stringify(['name', 'customer_name', 'customer_type']),
    limit_page_length: 10
});

// Create new customer
const newCustomer = await client.post('/api/resource/Customer', {
    customer_name: 'API Test Customer',
    customer_type: 'Company',
    customer_group: 'All Customer Groups',
    territory: 'All Territories'
});

// Update customer
await client.put(`/api/resource/Customer/${newCustomer.data.name}`, {
    customer_type: 'Individual'
});
```

### Item Management

```javascript
// Get items with stock info
const items = await client.get('/api/resource/Item', {
    fields: JSON.stringify(['item_code', 'item_name', 'standard_rate']),
    filters: JSON.stringify([['is_stock_item', '=', 1]]),
    order_by: 'item_name asc'
});

// Create new item
const newItem = await client.post('/api/resource/Item', {
    item_code: 'API-ITEM-001',
    item_name: 'API Test Item',
    item_group: 'All Item Groups',
    stock_uom: 'Nos',
    standard_rate: 100.00
});
```

### Sales Orders

```javascript
// Get recent sales orders
const salesOrders = await client.get('/api/resource/Sales Order', {
    fields: JSON.stringify(['name', 'customer', 'status', 'grand_total']),
    filters: JSON.stringify([['docstatus', '=', 1]]),
    order_by: 'creation desc',
    limit_page_length: 5
});

// Create sales order
const salesOrder = await client.post('/api/resource/Sales Order', {
    customer: 'CUST-00001',
    delivery_date: '2024-12-31',
    items: [{
        item_code: 'ITEM-001',
        qty: 10,
        rate: 100.00
    }]
});
```

## 🎯 Error Handling

### Comprehensive Error Handling

```javascript
try {
    const result = await client.get('/api/resource/Customer');
    console.log(result.data);
} catch (error) {
    if (error.response) {
        // Server responded with error status
        const status = error.response.status;
        const message = error.response.data.message;
        
        switch (status) {
            case 401:
                console.error('Authentication failed');
                break;
            case 403:
                console.error('Access forbidden');
                break;
            case 404:
                console.error('Resource not found');
                break;
            case 429:
                console.error('Rate limit exceeded');
                break;
            default:
                console.error(`API error: ${status} - ${message}`);
        }
    } else if (error.request) {
        // Network error
        console.error('Network error:', error.message);
    } else {
        // Other error
        console.error('Error:', error.message);
    }
}
```

### Built-in Error Handling

The client automatically handles:
- **401 Unauthorized**: Token expired/invalid
- **403 Forbidden**: Insufficient permissions
- **429 Rate Limited**: Automatic retry after delay
- **5xx Server Errors**: Automatic retry with backoff
- **Network Timeouts**: Configurable timeout handling

## ⚙️ Configuration Options

### Environment Variables (.env)

```bash
# Required
ERPNEXT_URL=https://your-domain.com
ERPNEXT_API_KEY=your_api_key_here
ERPNEXT_API_SECRET=your_api_secret_here

# Optional Performance Settings
RATE_LIMIT_PER_MINUTE=60
REQUEST_TIMEOUT=30000
ENABLE_CACHE=true
CACHE_TIMEOUT=300000
RETRY_ATTEMPTS=3
RETRY_DELAY=1000
```

### Client Configuration

```javascript
const client = new ERPNextAdvancedSecureClient(baseUrl, {
    retryAttempts: 3,           // Number of retry attempts
    retryDelay: 1000,          // Delay between retries (ms)
    enableCache: true,         // Enable response caching
    cacheTimeout: 300000,      // Cache expiration (ms)
    rateLimitPerMinute: 60     // Requests per minute limit
});
```

## 📚 Available Scripts

```bash
# Run demo with all features
npm run demo

# Run practical examples
npm run test-api

# Simple usage example
node examples/simple_usage.js

# Advanced examples
node examples/api_examples.js
```

## 🔍 Logging and Monitoring

### Security Logging

The client automatically logs to files:
- **`api_security.log`**: Authentication events
- **`api_requests.log`**: All API requests with status codes

### Example Log Entries

```
2024-08-22T09:15:30.123Z - TOKEN_AUTH_SUCCESS - User: abcd1234...
2024-08-22T09:15:31.456Z - GET /api/resource/Customer - 200 - User: admin
2024-08-22T09:15:32.789Z - POST /api/resource/Customer - 201 - User: admin
```

### Performance Monitoring

```javascript
// Track request performance
console.time('API Request');
const result = await client.get('/api/resource/Customer');
console.timeEnd('API Request');

// Cache hit/miss tracking
const cachedResult = await client.get('/api/resource/Customer'); // Cache hit logged
```

## 🚨 Security Best Practices

### Production Checklist

- [ ] ✅ Use HTTPS URLs only
- [ ] ✅ Store API keys in environment variables
- [ ] ✅ Enable request logging for audit trails
- [ ] ✅ Implement rate limiting
- [ ] ✅ Use token authentication (not sessions)
- [ ] ✅ Set appropriate timeouts
- [ ] ✅ Handle errors gracefully
- [ ] ✅ Monitor API usage patterns
- [ ] ✅ Rotate API keys regularly
- [ ] ✅ Validate all inputs

### Development Tips

```javascript
// ✅ Good: Use environment variables
const client = new ERPNextSecureClient(process.env.ERPNEXT_URL);
await client.authenticateWithToken(); // Uses env vars

// ❌ Bad: Hardcode credentials
const client = new ERPNextSecureClient('http://localhost:8080');
await client.authenticateWithToken('hardcoded-key', 'hardcoded-secret');

// ✅ Good: Handle errors
try {
    const result = await client.get('/api/resource/Customer');
    return result.data;
} catch (error) {
    logger.error('Customer fetch failed:', error.message);
    throw new APIError('Failed to fetch customers');
}

// ❌ Bad: Ignore errors
const result = await client.get('/api/resource/Customer');
return result.data; // Will crash if API fails
```

## 📖 Integration Examples

### Express.js API

```javascript
const express = require('express');
const { ERPNextSecureClient } = require('./secure_api_client');

const app = express();
const erpClient = new ERPNextSecureClient();

app.get('/customers', async (req, res) => {
    try {
        await erpClient.authenticateWithToken();
        const customers = await erpClient.get('/api/resource/Customer', {
            limit_page_length: 10
        });
        res.json(customers.data);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch customers' });
    } finally {
        await erpClient.logout();
    }
});
```

### React/Next.js Frontend

```javascript
// api/erpnext.js
import { ERPNextSecureClient } from '../lib/secure_api_client';

export async function getCustomers() {
    const client = new ERPNextSecureClient(process.env.NEXT_PUBLIC_ERPNEXT_URL);
    await client.authenticateWithToken(
        process.env.ERPNEXT_API_KEY,
        process.env.ERPNEXT_API_SECRET
    );
    
    const customers = await client.get('/api/resource/Customer');
    await client.logout();
    return customers.data;
}
```

### CLI Tool

```javascript
#!/usr/bin/env node
const { ERPNextSecureClient } = require('./secure_api_client');

async function cli() {
    const client = new ERPNextSecureClient();
    await client.authenticateWithToken();
    
    const command = process.argv[2];
    
    switch (command) {
        case 'customers':
            const customers = await client.get('/api/resource/Customer');
            console.table(customers.data);
            break;
        case 'items':
            const items = await client.get('/api/resource/Item');
            console.table(items.data);
            break;
        default:
            console.log('Available commands: customers, items');
    }
    
    await client.logout();
}

cli().catch(console.error);
```

## 🔧 Troubleshooting

### Common Issues

**Authentication Failed**
```bash
# Check API key generation
# 1. Login to ERPNext → Settings → My Settings
# 2. Scroll to "API Access" section
# 3. Generate new keys if needed
# 4. Update .env file
```

**Connection Refused**
```bash
# Make sure ERPNext is running
docker-compose ps
docker-compose up -d
```

**Rate Limit Exceeded**
```javascript
// Use advanced client with rate limiting
const client = new ERPNextAdvancedSecureClient(url, {
    rateLimitPerMinute: 30  // Reduce rate limit
});
```

**Timeout Errors**
```javascript
// Increase timeout
const client = new ERPNextSecureClient(url);
client.client.defaults.timeout = 60000; // 60 seconds
```

## 📦 Dependencies

```json
{
  "dependencies": {
    "axios": "^1.6.0",     // HTTP client
    "dotenv": "^16.0.0"    // Environment variables
  },
  "devDependencies": {
    "nodemon": "^3.0.0"    // Development auto-reload
  }
}
```

## 🎉 Complete Example

Here's a complete working example:

```javascript
const { ERPNextAdvancedSecureClient } = require('./secure_api_client');
require('dotenv').config();

async function completeExample() {
    // 1. Initialize client with advanced features
    const client = new ERPNextAdvancedSecureClient(process.env.ERPNEXT_URL, {
        enableCache: true,
        retryAttempts: 3,
        rateLimitPerMinute: 60
    });

    try {
        // 2. Authenticate
        await client.authenticateWithToken();
        console.log('✅ Authenticated successfully');

        // 3. Get system info (cached)
        const systemInfo = await client.get('/api/resource/System Settings/System Settings');
        console.log(`System: ${systemInfo.data.country} (${systemInfo.data.time_zone})`);

        // 4. Create customer with error handling
        try {
            const customer = await client.post('/api/resource/Customer', {
                customer_name: `API Customer ${Date.now()}`,
                customer_type: 'Individual',
                customer_group: 'All Customer Groups',
                territory: 'All Territories'
            });
            console.log(`✅ Created customer: ${customer.data.name}`);

            // 5. Update the customer
            await client.put(`/api/resource/Customer/${customer.data.name}`, {
                customer_type: 'Company'
            });
            console.log('✅ Updated customer');

        } catch (error) {
            console.log('⚠️ Customer operations skipped:', error.response?.data?.message);
        }

        // 6. Get performance metrics
        console.log('📊 Performance test - making 5 rapid requests...');
        const promises = Array(5).fill().map(() => 
            client.get('/api/resource/Company', { limit_page_length: 1 })
        );
        await Promise.all(promises);
        console.log('✅ All requests completed (rate limited automatically)');

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        // 7. Always logout
        await client.logout();
        console.log('🔒 Logged out');
    }
}

completeExample();
```

This Node.js/Axios client provides enterprise-grade security, performance, and reliability for ERPNext API integration!