#!/usr/bin/env node

/**
 * Simple ERPNext API Usage Example
 * Quick start guide for new users
 */

const { ERPNextSecureClient } = require('../secure_api_client');
require('dotenv').config();

async function simpleExample() {
    console.log('🚀 Simple ERPNext API Usage Example');
    console.log('='.repeat(40));

    // 1. Create client
    const client = new ERPNextSecureClient('http://localhost:8080');

    try {
        // 2. Authenticate (using environment variables)
        console.log('🔐 Authenticating...');
        const success = await client.authenticateWithToken();
        
        if (!success) {
            throw new Error('Authentication failed');
        }

        // 3. Get some data
        console.log('📊 Fetching data...');
        
        // Get users
        const users = await client.get('/api/resource/User', {
            fields: JSON.stringify(['name', 'full_name']),
            limit_page_length: 3
        });
        console.log('Users:', users.data);

        // Get companies
        const companies = await client.get('/api/resource/Company');
        console.log('Companies:', companies.data);

        // 4. Create something (example)
        try {
            const newCustomer = await client.post('/api/resource/Customer', {
                customer_name: 'Simple API Test Customer',
                customer_type: 'Individual'
            });
            console.log('Created customer:', newCustomer.data.name);
        } catch (error) {
            console.log('Customer creation skipped:', error.response?.data?.message);
        }

        // 5. Logout
        await client.logout();
        console.log('✅ Done!');

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

// Run if called directly
if (require.main === module) {
    simpleExample();
}

module.exports = simpleExample;