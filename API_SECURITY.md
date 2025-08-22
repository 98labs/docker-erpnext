# ERPNext API Security Guide

## Authentication Methods

ERPNext supports multiple authentication methods, each with different use cases and security implications:

## 1. Session-Based Authentication (Cookies)

### How it works:
```bash
# Login and get session cookie
curl -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"usr":"Administrator","pwd":"LocalDev123!"}' \
  http://localhost:8080/api/method/login

# Use cookie for subsequent requests
curl -b cookies.txt http://localhost:8080/api/resource/Customer
```

### Pros:
- ✅ Simple to implement
- ✅ Works well for browser-based applications
- ✅ Session management handled by server
- ✅ Can implement session timeout

### Cons:
- ❌ Vulnerable to CSRF attacks without proper tokens
- ❌ Not ideal for mobile/API clients
- ❌ Requires cookie storage
- ❌ Session state on server

### Security Best Practices:
- Use HTTPS only
- Set HttpOnly flag
- Set Secure flag
- Implement CSRF tokens
- Set appropriate session timeouts

## 2. API Key & Secret (Token Authentication)

### How it works:
```bash
# Use API key and secret in Authorization header
curl -H "Authorization: token api_key:api_secret" \
  http://localhost:8080/api/resource/Customer
```

### Setup:
1. Login to ERPNext UI
2. Go to User Settings → API Access
3. Generate API Key and Secret
4. Store securely

### Example Implementation:
```python
import requests

headers = {
    'Authorization': 'token abc123:xyz789'
}
response = requests.get('http://localhost:8080/api/resource/Customer', headers=headers)
```

### Pros:
- ✅ Stateless authentication
- ✅ Better for API/mobile clients
- ✅ No CSRF vulnerability
- ✅ Can be revoked easily
- ✅ Per-user access control

### Cons:
- ❌ Keys must be stored securely
- ❌ No automatic expiration (unless implemented)
- ❌ Transmitted with every request

### Security Best Practices:
- **Never** commit API keys to version control
- Use environment variables
- Rotate keys regularly
- Use HTTPS only
- Implement IP whitelisting

## 3. OAuth 2.0 (Most Secure for Third-Party Apps)

### How it works:
ERPNext supports OAuth 2.0 for third-party integrations.

### Setup:
1. Register OAuth client in ERPNext
2. Implement OAuth flow
3. Use access tokens for API calls

### Example Flow:
```python
# 1. Redirect user to authorize
authorize_url = "http://localhost:8080/api/method/frappe.integrations.oauth2.authorize"

# 2. Exchange code for token
token_url = "http://localhost:8080/api/method/frappe.integrations.oauth2.get_token"

# 3. Use access token
headers = {'Authorization': 'Bearer access_token_here'}
```

### Pros:
- ✅ Industry standard
- ✅ Granular permissions
- ✅ Token expiration
- ✅ Refresh tokens
- ✅ No password sharing

### Cons:
- ❌ More complex to implement
- ❌ Requires OAuth server setup

## 4. Basic Authentication (Not Recommended)

### How it works:
```bash
curl -u Administrator:LocalDev123! \
  http://localhost:8080/api/resource/Customer
```

### Pros:
- ✅ Simple

### Cons:
- ❌ Credentials sent with every request
- ❌ Base64 encoding (not encryption)
- ❌ No session management
- ❌ Security risk

## Security Comparison Matrix

| Method | Security Level | Use Case | Implementation Complexity |
|--------|---------------|----------|--------------------------|
| OAuth 2.0 | ⭐⭐⭐⭐⭐ | Third-party apps, Mobile apps | High |
| API Key/Secret | ⭐⭐⭐⭐ | Server-to-server, CLI tools | Low |
| Session/Cookies | ⭐⭐⭐ | Web applications | Low |
| Basic Auth | ⭐⭐ | Testing only | Very Low |

## Recommended Security Architecture

### For Web Applications:
```javascript
// Use session cookies with CSRF tokens
fetch('/api/resource/Customer', {
    credentials: 'include',
    headers: {
        'X-CSRF-Token': getCsrfToken()
    }
})
```

### For Mobile Applications:
```swift
// Use API tokens with secure storage
let headers = [
    "Authorization": "token \(secureStorage.getApiKey()):\(secureStorage.getApiSecret())"
]
```

### For Server-to-Server:
```python
# Use API tokens with environment variables
import os
import requests

headers = {
    'Authorization': f'token {os.environ["ERPNEXT_API_KEY"]}:{os.environ["ERPNEXT_API_SECRET"]}'
}
```

### For Third-Party Integrations:
```javascript
// Implement OAuth 2.0 flow
const accessToken = await getOAuthToken();
const response = await fetch('/api/resource/Customer', {
    headers: {
        'Authorization': `Bearer ${accessToken}`
    }
});
```

## Additional Security Measures

### 1. Rate Limiting
```nginx
# nginx configuration
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
location /api {
    limit_req zone=api burst=10 nodelay;
}
```

### 2. IP Whitelisting
```python
# In ERPNext site_config.json
{
    "api_ip_whitelist": ["192.168.1.0/24", "10.0.0.0/8"]
}
```

### 3. HTTPS Configuration
```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
}
```

### 4. API Monitoring
```python
# Log all API access
import frappe

@frappe.whitelist()
def log_api_access():
    frappe.log_error(
        title="API Access",
        message=f"User: {frappe.session.user}, IP: {frappe.request.remote_addr}"
    )
```

### 5. Field-Level Permissions
```python
# Restrict sensitive fields
{
    "doctype": "Customer",
    "field_permissions": {
        "credit_limit": ["Sales Manager"],
        "tax_id": ["Accounts Manager"]
    }
}
```

## Security Checklist

### Development:
- [ ] Use HTTPS in production
- [ ] Store credentials in environment variables
- [ ] Implement proper error handling (don't leak info)
- [ ] Validate all inputs
- [ ] Use parameterized queries

### API Keys:
- [ ] Generate strong keys (min 32 characters)
- [ ] Rotate keys regularly (every 90 days)
- [ ] Implement key expiration
- [ ] Log key usage
- [ ] Revoke compromised keys immediately

### Network Security:
- [ ] Enable firewall
- [ ] Implement rate limiting
- [ ] Use IP whitelisting where possible
- [ ] Enable DDoS protection
- [ ] Monitor unusual patterns

### Authentication:
- [ ] Enforce strong passwords
- [ ] Implement 2FA for admin accounts
- [ ] Use OAuth for third-party apps
- [ ] Session timeout (15-30 minutes)
- [ ] Logout on suspicious activity

## Example: Secure API Clients

### Python Client

```python
"""
Secure ERPNext API Client - Python
"""
import os
import requests
from datetime import datetime, timedelta
import hashlib
import hmac

class SecureERPNextClient:
    def __init__(self):
        self.base_url = os.environ.get('ERPNEXT_URL', 'https://erp.example.com')
        self.api_key = os.environ.get('ERPNEXT_API_KEY')
        self.api_secret = os.environ.get('ERPNEXT_API_SECRET')
        self.session = requests.Session()
        self.token_expiry = None
        
        # Security headers
        self.session.headers.update({
            'User-Agent': 'ERPNext-API-Client/1.0',
            'X-Requested-With': 'XMLHttpRequest'
        })
        
    def _generate_signature(self, method, endpoint, timestamp):
        """Generate HMAC signature for request"""
        message = f"{method}:{endpoint}:{timestamp}"
        signature = hmac.new(
            self.api_secret.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()
        return signature
    
    def _make_request(self, method, endpoint, **kwargs):
        """Make secure API request"""
        timestamp = datetime.utcnow().isoformat()
        signature = self._generate_signature(method, endpoint, timestamp)
        
        headers = {
            'Authorization': f'token {self.api_key}:{self.api_secret}',
            'X-Timestamp': timestamp,
            'X-Signature': signature
        }
        
        response = self.session.request(
            method,
            f"{self.base_url}{endpoint}",
            headers=headers,
            **kwargs
        )
        
        # Log for audit
        self._log_request(method, endpoint, response.status_code)
        
        response.raise_for_status()
        return response.json()
    
    def _log_request(self, method, endpoint, status_code):
        """Log API requests for audit"""
        with open('api_audit.log', 'a') as f:
            f.write(f"{datetime.utcnow().isoformat()} - {method} {endpoint} - {status_code}\n")
    
    def get(self, endpoint, params=None):
        return self._make_request('GET', endpoint, params=params)
    
    def post(self, endpoint, data=None):
        return self._make_request('POST', endpoint, json=data)
    
    def put(self, endpoint, data=None):
        return self._make_request('PUT', endpoint, json=data)
    
    def delete(self, endpoint):
        return self._make_request('DELETE', endpoint)

# Usage
if __name__ == "__main__":
    client = SecureERPNextClient()
    
    # Get customers securely
    customers = client.get('/api/resource/Customer')
    
    # Create customer securely
    new_customer = client.post('/api/resource/Customer', {
        'customer_name': 'Test Customer',
        'customer_type': 'Company'
    })
```

### Node.js/Axios Client (Production-Ready)

```javascript
/**
 * Secure ERPNext API Client - Node.js/Axios
 */
const axios = require('axios');
const fs = require('fs').promises;
const crypto = require('crypto');

class SecureERPNextClient {
    constructor(baseUrl = 'https://erp.example.com') {
        this.baseUrl = baseUrl;
        this.apiKey = process.env.ERPNEXT_API_KEY;
        this.apiSecret = process.env.ERPNEXT_API_SECRET;
        
        // Create secure axios instance
        this.client = axios.create({
            baseURL: this.baseUrl,
            timeout: 30000,
            headers: {
                'User-Agent': 'ERPNext-Secure-Client/1.0',
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            }
        });

        // Set authentication header
        if (this.apiKey && this.apiSecret) {
            this.client.defaults.headers.common['Authorization'] = 
                `token ${this.apiKey}:${this.apiSecret}`;
        }

        // Add security interceptors
        this.setupSecurityInterceptors();
    }

    setupSecurityInterceptors() {
        // Request interceptor
        this.client.interceptors.request.use(
            (config) => {
                // Add security headers
                config.headers['X-Request-Time'] = new Date().toISOString();
                config.headers['X-Request-ID'] = crypto.randomBytes(8).toString('hex');
                
                // Generate signature for extra security
                const signature = this.generateSignature(
                    config.method.toUpperCase(), 
                    config.url, 
                    config.headers['X-Request-Time']
                );
                config.headers['X-Signature'] = signature;
                
                return config;
            },
            (error) => {
                this.logRequest('REQUEST_ERROR', '', 0, error.message);
                return Promise.reject(error);
            }
        );

        // Response interceptor
        this.client.interceptors.response.use(
            (response) => {
                this.logRequest(
                    response.config.method.toUpperCase(),
                    response.config.url,
                    response.status
                );
                return response;
            },
            (error) => {
                const status = error.response?.status || 0;
                const method = error.config?.method?.toUpperCase() || 'UNKNOWN';
                const url = error.config?.url || '';

                // Handle auth errors
                if (status === 401) {
                    console.error('🔒 Authentication failed - check API credentials');
                } else if (status === 403) {
                    console.error('🚫 Access forbidden - insufficient permissions');
                } else if (status === 429) {
                    console.error('⏳ Rate limit exceeded - please wait');
                }

                this.logRequest(method, url, status, error.message);
                return Promise.reject(error);
            }
        );
    }

    generateSignature(method, endpoint, timestamp) {
        const message = `${method}:${endpoint}:${timestamp}`;
        return crypto
            .createHmac('sha256', this.apiSecret)
            .update(message)
            .digest('hex');
    }

    async logRequest(method, endpoint, statusCode, error = '') {
        const timestamp = new Date().toISOString();
        const logEntry = `${timestamp} - ${method} ${endpoint} - ${statusCode} - ${error}\n`;
        
        try {
            await fs.appendFile('api_security.log', logEntry);
        } catch (logError) {
            // Don't fail if logging fails
        }
    }

    // Secure API methods
    async get(endpoint, params = {}) {
        const response = await this.client.get(endpoint, { params });
        return response.data;
    }

    async post(endpoint, data = {}) {
        const response = await this.client.post(endpoint, data);
        return response.data;
    }

    async put(endpoint, data = {}) {
        const response = await this.client.put(endpoint, data);
        return response.data;
    }

    async delete(endpoint) {
        const response = await this.client.delete(endpoint);
        return response.data;
    }
}

// Usage Example
async function example() {
    const client = new SecureERPNextClient();
    
    try {
        // Get customers securely
        const customers = await client.get('/api/resource/Customer');
        console.log('Customers:', customers.data.length);
        
        // Create customer securely
        const newCustomer = await client.post('/api/resource/Customer', {
            customer_name: 'Secure API Customer',
            customer_type: 'Company'
        });
        console.log('Created:', newCustomer.data.name);
        
    } catch (error) {
        console.error('API Error:', error.response?.data?.message || error.message);
    }
}

module.exports = { SecureERPNextClient };
```

### Advanced Security Features (Node.js)

```javascript
/**
 * Advanced Security Features for ERPNext API Client
 */

// 1. Rate Limiting Implementation
class RateLimitedClient extends SecureERPNextClient {
    constructor(baseUrl, options = {}) {
        super(baseUrl);
        this.requestsPerMinute = options.requestsPerMinute || 60;
        this.requestQueue = [];
        this.setupRateLimit();
    }

    setupRateLimit() {
        this.client.interceptors.request.use(async (config) => {
            await this.checkRateLimit();
            return config;
        });
    }

    async checkRateLimit() {
        const now = Date.now();
        const oneMinuteAgo = now - 60000;
        
        // Remove old requests
        this.requestQueue = this.requestQueue.filter(time => time > oneMinuteAgo);
        
        // Check if we're at the limit
        if (this.requestQueue.length >= this.requestsPerMinute) {
            const waitTime = this.requestQueue[0] + 60000 - now;
            console.log(`⏳ Rate limit reached. Waiting ${waitTime}ms...`);
            await new Promise(resolve => setTimeout(resolve, waitTime));
        }
        
        this.requestQueue.push(now);
    }
}

// 2. Request Retry with Exponential Backoff
class RetryClient extends RateLimitedClient {
    constructor(baseUrl, options = {}) {
        super(baseUrl, options);
        this.maxRetries = options.maxRetries || 3;
        this.retryDelay = options.retryDelay || 1000;
        this.setupRetry();
    }

    setupRetry() {
        this.client.interceptors.response.use(
            response => response,
            async (error) => {
                const config = error.config;
                
                if (!config || config.retry >= this.maxRetries) {
                    return Promise.reject(error);
                }

                // Only retry on network errors or 5xx responses
                const shouldRetry = !error.response || 
                    (error.response.status >= 500 && error.response.status < 600);

                if (!shouldRetry) {
                    return Promise.reject(error);
                }

                config.retry = (config.retry || 0) + 1;
                
                const delay = this.retryDelay * Math.pow(2, config.retry - 1);
                console.log(`🔄 Retrying request (${config.retry}/${this.maxRetries}) in ${delay}ms`);
                
                await new Promise(resolve => setTimeout(resolve, delay));
                return this.client(config);
            }
        );
    }
}

// 3. Request Caching
class CachedClient extends RetryClient {
    constructor(baseUrl, options = {}) {
        super(baseUrl, options);
        this.cache = new Map();
        this.cacheTimeout = options.cacheTimeout || 300000; // 5 minutes
    }

    async get(endpoint, params = {}) {
        const cacheKey = `GET:${endpoint}:${JSON.stringify(params)}`;
        const cached = this.cache.get(cacheKey);
        
        if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
            console.log('📦 Cache hit:', endpoint);
            return cached.data;
        }
        
        const result = await super.get(endpoint, params);
        
        this.cache.set(cacheKey, {
            data: result,
            timestamp: Date.now()
        });
        
        return result;
    }

    clearCache() {
        this.cache.clear();
        console.log('🗑️  Cache cleared');
    }
}
```

## Docker Security Configuration

### Environment Variables (.env)
```bash
# Never commit .env files
ERPNEXT_API_KEY=your_api_key_here
ERPNEXT_API_SECRET=your_api_secret_here
ERPNEXT_URL=https://localhost:8080

# Use Docker secrets in production
docker secret create erpnext_api_key api_key.txt
docker secret create erpnext_api_secret api_secret.txt
```

### Docker Compose with Secrets
```yaml
version: '3.8'

services:
  app:
    image: frappe/erpnext:v14
    secrets:
      - erpnext_api_key
      - erpnext_api_secret
    environment:
      API_KEY_FILE: /run/secrets/erpnext_api_key
      API_SECRET_FILE: /run/secrets/erpnext_api_secret

secrets:
  erpnext_api_key:
    external: true
  erpnext_api_secret:
    external: true
```

## Conclusion

### Best Practices Summary:

1. **For Production APIs**: Use API Key/Secret or OAuth 2.0
2. **For Web Apps**: Use session cookies with CSRF protection
3. **For Mobile Apps**: Use OAuth 2.0 with secure token storage
4. **For Testing**: Use session cookies (never Basic Auth in production)

### Security Priority:
1. Always use HTTPS
2. Implement rate limiting
3. Use strong authentication
4. Monitor and log access
5. Regular security audits

### Remember:
- **Cookies alone are NOT the most secure** - they need CSRF protection
- **API tokens are better for APIs** - stateless and no CSRF risk
- **OAuth 2.0 is best for third-party** - industry standard
- **Never use Basic Auth in production** - credentials exposed

The choice depends on your use case, but for pure API access, **token-based authentication (API Key/Secret or OAuth)** is generally more secure than cookies.