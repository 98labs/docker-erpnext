#!/usr/bin/env node

/**
 * Quick test to verify environment variables work with Axios
 */

const { ERPNextSecureClient } = require('./secure_api_client');
require('dotenv').config();

async function testEnvVars() {
    console.log('🔍 Testing Environment Variables with Axios');
    console.log('=' .repeat(50));
    
    // Check if env vars are loaded
    console.log('Environment Variables Status:');
    console.log(`ERPNEXT_API_KEY: ${process.env.ERPNEXT_API_KEY ? '✅ Set' : '❌ Missing'}`);
    console.log(`ERPNEXT_API_SECRET: ${process.env.ERPNEXT_API_SECRET ? '✅ Set' : '❌ Missing'}`);
    console.log('');

    if (!process.env.ERPNEXT_API_KEY || !process.env.ERPNEXT_API_SECRET) {
        console.log('❌ Environment variables not found!');
        console.log('Make sure you have:');
        console.log('1. Created .env file with your credentials, OR');
        console.log('2. Exported the variables in your terminal');
        console.log('');
        console.log('Example .env file:');
        console.log('ERPNEXT_API_KEY="your_key_here"');
        console.log('ERPNEXT_API_SECRET="your_secret_here"');
        return;
    }

    // Test the client
    const client = new ERPNextSecureClient('http://localhost:8080');
    
    try {
        console.log('🔐 Testing authentication with environment variables...');
        
        // This call automatically uses the env vars
        const success = await client.authenticateWithToken();
        
        if (success) {
            console.log('✅ Authentication successful!');
            console.log('🌐 Testing API call...');
            
            // Test a simple API call
            const users = await client.get('/api/resource/User', {
                limit_page_length: 1,
                fields: JSON.stringify(['name', 'full_name'])
            });
            
            console.log('✅ API call successful!');
            console.log('Sample user:', users.data[0]);
            
            await client.logout();
            console.log('🔒 Logged out successfully');
            
        } else {
            console.log('❌ Authentication failed. Check your credentials.');
        }
        
    } catch (error) {
        if (error.code === 'ECONNREFUSED') {
            console.log('❌ Connection refused. Make sure ERPNext is running:');
            console.log('   docker-compose up -d');
        } else {
            console.log('❌ Error:', error.message);
        }
    }
}

// Run the test
testEnvVars().catch(console.error);