#!/usr/bin/env node

/**
 * Secure ERPNext API Client - Node.js/Axios Version
 * Demonstrates best practices for API authentication and security
 */

const axios = require('axios');
const fs = require('fs').promises;
const readline = require('readline');
const crypto = require('crypto');
const { URL } = require('url');

class ERPNextSecureClient {
    constructor(baseUrl = 'http://localhost:8080') {
        this.baseUrl = baseUrl.replace(/\/$/, ''); // Remove trailing slash
        this.authMethod = null;
        this.currentUser = 'unknown';
        
        // Create axios instance with security defaults
        this.client = axios.create({
            baseURL: this.baseUrl,
            timeout: 30000, // 30 second timeout
            headers: {
                'User-Agent': 'ERPNext-Secure-Client-JS/1.0',
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            }
        });

        // Security check
        const url = new URL(this.baseUrl);
        if (url.protocol === 'http:' && !url.hostname.includes('localhost')) {
            console.warn('⚠️  WARNING: Using HTTP with non-localhost. Use HTTPS in production!');
        }

        // Add request/response interceptors for security
        this.setupInterceptors();
    }

    setupInterceptors() {
        // Request interceptor - add security headers and logging
        this.client.interceptors.request.use(
            (config) => {
                // Add timestamp for audit
                config.headers['X-Request-Time'] = new Date().toISOString();
                
                // Add request ID for tracing
                config.headers['X-Request-ID'] = this.generateRequestId();
                
                return config;
            },
            (error) => {
                this.logRequest('REQUEST_ERROR', '', 0, error.message);
                return Promise.reject(error);
            }
        );

        // Response interceptor - handle auth errors and logging
        this.client.interceptors.response.use(
            (response) => {
                // Log successful requests
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

                // Handle specific error cases
                if (status === 401) {
                    console.error('❌ Authentication failed. Token may be expired.');
                } else if (status === 403) {
                    console.error('❌ Access forbidden. Check permissions.');
                } else if (status === 429) {
                    console.error('❌ Rate limit exceeded. Please wait.');
                }

                this.logRequest(method, url, status, error.message);
                return Promise.reject(error);
            }
        );
    }

    generateRequestId() {
        return crypto.randomBytes(8).toString('hex');
    }

    /**
     * Login using username/password (creates session cookie)
     * SECURITY: Use only for web applications, not for API clients
     */
    async loginWithCredentials(username, password) {
        if (!username) {
            username = await this.promptInput('Username: ');
        }
        if (!password) {
            password = await this.promptPassword('Password: ');
        }

        const loginData = { usr: username, pwd: password };

        try {
            const response = await this.client.post('/api/method/login', loginData);
            
            if (response.data.message && response.data.message.includes('Logged In')) {
                this.authMethod = 'session';
                this.currentUser = username;
                console.log('✅ Logged in successfully (session-based)');
                this.logAuthEvent('LOGIN_SUCCESS', username);
                return true;
            } else {
                console.log('❌ Login failed');
                this.logAuthEvent('LOGIN_FAILED', username);
                return false;
            }
        } catch (error) {
            console.error(`❌ Login error: ${error.message}`);
            this.logAuthEvent('LOGIN_ERROR', username, error.message);
            return false;
        }
    }

    /**
     * Setup token-based authentication
     * SECURITY: Recommended for API clients and server-to-server communication
     */
    async authenticateWithToken(apiKey, apiSecret) {
        if (!apiKey) {
            apiKey = process.env.ERPNEXT_API_KEY;
            if (!apiKey) {
                apiKey = await this.promptInput('API Key: ');
            }
        }

        if (!apiSecret) {
            apiSecret = process.env.ERPNEXT_API_SECRET;
            if (!apiSecret) {
                apiSecret = await this.promptPassword('API Secret: ');
            }
        }

        this.apiKey = apiKey;
        this.apiSecret = apiSecret;
        this.authMethod = 'token';

        // Set authorization header
        this.client.defaults.headers.common['Authorization'] = `token ${apiKey}:${apiSecret}`;

        // Test the token
        try {
            await this.get('/api/resource/User', { limit_page_length: 1 });
            console.log('✅ Token authentication successful');
            this.logAuthEvent('TOKEN_AUTH_SUCCESS', `${apiKey.substring(0, 8)}...`);
            return true;
        } catch (error) {
            console.error(`❌ Token authentication failed: ${error.message}`);
            this.logAuthEvent('TOKEN_AUTH_FAILED', `${apiKey.substring(0, 8)}...`, error.message);
            return false;
        }
    }

    generateApiKeyInstructions() {
        console.log('\n' + '='.repeat(60));
        console.log('HOW TO GENERATE API KEYS:');
        console.log('='.repeat(60));
        console.log('1. Login to ERPNext web interface');
        console.log('2. Go to Settings → My Settings');
        console.log('3. Scroll to \'API Access\' section');
        console.log('4. Click \'Generate Keys\'');
        console.log('5. Copy the API Key and API Secret');
        console.log('6. Store them securely (environment variables recommended)');
        console.log('\nEnvironment Variables:');
        console.log('export ERPNEXT_API_KEY=\'your_api_key_here\'');
        console.log('export ERPNEXT_API_SECRET=\'your_api_secret_here\'');
        console.log('\nNode.js (.env file):');
        console.log('ERPNEXT_API_KEY=your_api_key_here');
        console.log('ERPNEXT_API_SECRET=your_api_secret_here');
        console.log('='.repeat(60));
    }

    /**
     * Secure API Methods
     */
    async get(endpoint, params = {}) {
        this.checkAuth();
        const response = await this.client.get(endpoint, { params });
        return response.data;
    }

    async post(endpoint, data = {}) {
        this.checkAuth();
        const response = await this.client.post(endpoint, data);
        return response.data;
    }

    async put(endpoint, data = {}) {
        this.checkAuth();
        const response = await this.client.put(endpoint, data);
        return response.data;
    }

    async delete(endpoint) {
        this.checkAuth();
        const response = await this.client.delete(endpoint);
        return response.data;
    }

    checkAuth() {
        if (!this.authMethod) {
            throw new Error('Not authenticated. Use loginWithCredentials() or authenticateWithToken()');
        }
    }

    async logout() {
        if (this.authMethod === 'session') {
            try {
                await this.client.post('/api/method/logout');
                console.log('✅ Logged out successfully');
            } catch (error) {
                // Ignore logout errors
            }
        }

        // Clear auth headers and reset state
        delete this.client.defaults.headers.common['Authorization'];
        this.authMethod = null;
        this.currentUser = 'unknown';
        console.log('🔒 Session cleared');
    }

    /**
     * Utility Methods
     */
    async promptInput(question) {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        return new Promise((resolve) => {
            rl.question(question, (answer) => {
                rl.close();
                resolve(answer);
            });
        });
    }

    async promptPassword(question) {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        return new Promise((resolve) => {
            rl.question(question, (answer) => {
                rl.close();
                resolve(answer);
            });
            rl.stdoutMuted = true;
            rl._writeToOutput = function _writeToOutput(stringToWrite) {
                if (rl.stdoutMuted) {
                    rl.output.write('*');
                } else {
                    rl.output.write(stringToWrite);
                }
            };
        });
    }

    async logAuthEvent(event, user, details = '') {
        const timestamp = new Date().toISOString();
        const logEntry = `${timestamp} - ${event} - User: ${user} - ${details}\n`;
        
        try {
            await fs.appendFile('api_security.log', logEntry);
        } catch (error) {
            // Don't fail if logging fails
        }
    }

    async logRequest(method, endpoint, statusCode, error = '') {
        const timestamp = new Date().toISOString();
        const logEntry = `${timestamp} - ${method} ${endpoint} - ${statusCode} - User: ${this.currentUser} - ${error}\n`;
        
        try {
            await fs.appendFile('api_requests.log', logEntry);
        } catch (error) {
            // Don't fail if logging fails
        }
    }
}

/**
 * Advanced Secure Client with additional features
 */
class ERPNextAdvancedSecureClient extends ERPNextSecureClient {
    constructor(baseUrl, options = {}) {
        super(baseUrl);
        
        this.options = {
            retryAttempts: options.retryAttempts || 3,
            retryDelay: options.retryDelay || 1000,
            enableCache: options.enableCache || false,
            cacheTimeout: options.cacheTimeout || 300000, // 5 minutes
            ...options
        };

        this.cache = new Map();
        this.setupRetryLogic();
        
        if (options.rateLimitPerMinute) {
            this.setupRateLimit(options.rateLimitPerMinute);
        }
    }

    setupRetryLogic() {
        // Add retry interceptor
        this.client.interceptors.response.use(
            response => response,
            async (error) => {
                const config = error.config;

                // Don't retry if we've exceeded max attempts or it's not a retriable error
                if (!config || config.retry >= this.options.retryAttempts) {
                    return Promise.reject(error);
                }

                // Only retry on network errors or 5xx status codes
                const shouldRetry = !error.response || 
                    (error.response.status >= 500 && error.response.status < 600);

                if (!shouldRetry) {
                    return Promise.reject(error);
                }

                config.retry = (config.retry || 0) + 1;
                
                console.log(`🔄 Retrying request (${config.retry}/${this.options.retryAttempts}): ${config.url}`);
                
                // Wait before retrying
                await new Promise(resolve => setTimeout(resolve, this.options.retryDelay * config.retry));
                
                return this.client(config);
            }
        );
    }

    setupRateLimit(requestsPerMinute) {
        this.rateLimitQueue = [];
        this.rateLimitWindow = 60000; // 1 minute
        this.maxRequests = requestsPerMinute;

        this.client.interceptors.request.use(async (config) => {
            await this.checkRateLimit();
            return config;
        });
    }

    async checkRateLimit() {
        const now = Date.now();
        
        // Remove old requests outside the window
        this.rateLimitQueue = this.rateLimitQueue.filter(
            timestamp => now - timestamp < this.rateLimitWindow
        );

        // Check if we're at the limit
        if (this.rateLimitQueue.length >= this.maxRequests) {
            const oldestRequest = Math.min(...this.rateLimitQueue);
            const waitTime = this.rateLimitWindow - (now - oldestRequest);
            
            console.log(`⏳ Rate limit reached. Waiting ${Math.ceil(waitTime / 1000)}s...`);
            await new Promise(resolve => setTimeout(resolve, waitTime));
        }

        this.rateLimitQueue.push(now);
    }

    async get(endpoint, params = {}) {
        // Check cache first
        if (this.options.enableCache) {
            const cacheKey = `GET:${endpoint}:${JSON.stringify(params)}`;
            const cached = this.cache.get(cacheKey);
            
            if (cached && Date.now() - cached.timestamp < this.options.cacheTimeout) {
                console.log(`💾 Cache hit: ${endpoint}`);
                return cached.data;
            }
        }

        const result = await super.get(endpoint, params);

        // Cache the result
        if (this.options.enableCache) {
            const cacheKey = `GET:${endpoint}:${JSON.stringify(params)}`;
            this.cache.set(cacheKey, {
                data: result,
                timestamp: Date.now()
            });
        }

        return result;
    }

    clearCache() {
        this.cache.clear();
        console.log('🗑️  Cache cleared');
    }
}

/**
 * Demo Functions
 */
async function demoSecureUsage() {
    console.log('ERPNext Secure API Client Demo (Node.js/Axios)');
    console.log('='.repeat(50));

    const client = new ERPNextSecureClient();

    // Method 1: API Token (Recommended for APIs)
    console.log('\n🔐 Method 1: API Token Authentication (Recommended)');
    console.log('-'.repeat(50));

    const success = await client.authenticateWithToken();
    
    if (success) {
        try {
            console.log('\n📊 Fetching system info...');
            const systemSettings = await client.get('/api/resource/System%20Settings/System%20Settings');
            if (systemSettings?.data) {
                console.log(`   Country: ${systemSettings.data.country || 'Not set'}`);
                console.log(`   Time Zone: ${systemSettings.data.time_zone || 'Not set'}`);
            }

            console.log('\n👥 Fetching users (limited)...');
            const users = await client.get('/api/resource/User', { limit_page_length: 3 });
            if (users?.data) {
                users.data.forEach(user => {
                    console.log(`   - ${user.full_name || 'Unknown'} (${user.name || 'unknown'})`);
                });
            }

            console.log('\n🏢 Checking companies...');
            const companies = await client.get('/api/resource/Company');
            if (companies?.data) {
                companies.data.forEach(company => {
                    console.log(`   - ${company.name || 'Unknown Company'}`);
                });
            }

            // Demo creating a customer (if you have permissions)
            console.log('\n👤 Demo: Creating a test customer...');
            try {
                const newCustomer = await client.post('/api/resource/Customer', {
                    customer_name: 'Test Customer JS',
                    customer_type: 'Individual',
                    customer_group: 'All Customer Groups',
                    territory: 'All Territories'
                });
                console.log(`   ✅ Created customer: ${newCustomer.data.name}`);
            } catch (error) {
                console.log(`   ℹ️  Skipping customer creation (permission/validation error)`);
            }

        } catch (error) {
            console.error(`❌ Error during API calls: ${error.message}`);
        }

        await client.logout();
    } else {
        client.generateApiKeyInstructions();
    }
}

async function demoAdvancedFeatures() {
    console.log('\n🚀 Advanced Features Demo');
    console.log('-'.repeat(50));

    const advancedClient = new ERPNextAdvancedSecureClient('http://localhost:8080', {
        retryAttempts: 3,
        retryDelay: 1000,
        enableCache: true,
        cacheTimeout: 60000, // 1 minute cache
        rateLimitPerMinute: 30
    });

    if (await advancedClient.authenticateWithToken()) {
        console.log('\n💾 Testing caching...');
        
        // First request (will be cached)
        console.time('First request');
        await advancedClient.get('/api/resource/User', { limit_page_length: 1 });
        console.timeEnd('First request');
        
        // Second request (from cache)
        console.time('Cached request');
        await advancedClient.get('/api/resource/User', { limit_page_length: 1 });
        console.timeEnd('Cached request');
        
        advancedClient.clearCache();
        await advancedClient.logout();
    }
}

function printSecurityRecommendations() {
    console.log('\n' + '='.repeat(60));
    console.log('🔒 SECURITY RECOMMENDATIONS');
    console.log('='.repeat(60));
    console.log('1. ✅ USE API TOKENS for server-to-server communication');
    console.log('2. ✅ USE HTTPS in production (never HTTP)');
    console.log('3. ✅ STORE credentials in environment variables (.env)');
    console.log('4. ✅ IMPLEMENT rate limiting and retry logic');
    console.log('5. ✅ LOG all API access for audit trails');
    console.log('6. ✅ VALIDATE all inputs and handle errors gracefully');
    console.log('7. ✅ USE request timeouts and proper error handling');
    console.log('8. ✅ IMPLEMENT caching for frequently accessed data');
    console.log('9. ✅ MONITOR API usage and performance metrics');
    console.log('10. ✅ ROTATE API keys regularly (every 90 days)');
    console.log('\n❌ AVOID:');
    console.log('- Never commit API keys to version control');
    console.log('- Never use HTTP in production');
    console.log('- Never ignore SSL certificate errors');
    console.log('- Never expose API keys in client-side code');
    console.log('- Never log sensitive data');
    console.log('='.repeat(60));

    console.log('\n📦 Required Dependencies:');
    console.log('npm install axios dotenv');
    console.log('\n📄 Example .env file:');
    console.log('ERPNEXT_API_KEY=your_api_key_here');
    console.log('ERPNEXT_API_SECRET=your_api_secret_here');
    console.log('ERPNEXT_URL=https://your-domain.com');
}

// Main execution
async function main() {
    try {
        // Load environment variables if available
        try {
            require('dotenv').config();
        } catch (error) {
            console.log('💡 Tip: Install dotenv for .env file support: npm install dotenv');
        }

        await demoSecureUsage();
        await demoAdvancedFeatures();
        printSecurityRecommendations();
    } catch (error) {
        if (error.code === 'ECONNREFUSED') {
            console.error('\n❌ Connection refused. Make sure ERPNext is running on http://localhost:8080');
        } else {
            console.error(`\n❌ Unexpected error: ${error.message}`);
        }
    }
}

// Export classes for use as modules
module.exports = {
    ERPNextSecureClient,
    ERPNextAdvancedSecureClient
};

// Run demo if called directly
if (require.main === module) {
    main().catch(error => {
        console.error('Fatal error:', error.message);
        process.exit(1);
    });
}