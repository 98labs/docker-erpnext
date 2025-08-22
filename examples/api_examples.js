#!/usr/bin/env node

/**
 * Practical ERPNext API Examples using Axios
 * These examples show real-world usage patterns
 */

require('dotenv').config();
const { ERPNextSecureClient, ERPNextAdvancedSecureClient } = require('../secure_api_client');

/**
 * Customer Management Examples
 */
async function customerManagementExamples(client) {
    console.log('\n📋 Customer Management Examples');
    console.log('-'.repeat(40));

    try {
        // 1. Get all customers with filters
        console.log('1. Fetching active customers...');
        const customers = await client.get('/api/resource/Customer', {
            filters: JSON.stringify([['disabled', '=', 0]]),
            fields: JSON.stringify(['name', 'customer_name', 'customer_type', 'territory']),
            limit_page_length: 5
        });
        
        if (customers?.data?.length > 0) {
            customers.data.forEach((customer, index) => {
                console.log(`   ${index + 1}. ${customer.customer_name} (${customer.customer_type})`);
            });
        } else {
            console.log('   No customers found.');
        }

        // 2. Create a new customer
        console.log('\n2. Creating a new customer...');
        const newCustomerData = {
            customer_name: `Test Customer JS ${Date.now()}`,
            customer_type: 'Individual',
            customer_group: 'All Customer Groups',
            territory: 'All Territories'
        };

        try {
            const newCustomer = await client.post('/api/resource/Customer', newCustomerData);
            console.log(`   ✅ Created: ${newCustomer.data.name} - ${newCustomer.data.customer_name}`);
            
            // 3. Update the customer
            console.log('3. Updating customer...');
            const updatedCustomer = await client.put(`/api/resource/Customer/${newCustomer.data.name}`, {
                customer_type: 'Company'
            });
            console.log(`   ✅ Updated customer type to: ${updatedCustomer.data.customer_type}`);
            
            return newCustomer.data.name; // Return for potential cleanup
        } catch (error) {
            console.log(`   ⚠️  Customer creation failed: ${error.response?.data?.message || error.message}`);
        }

    } catch (error) {
        console.error(`❌ Customer management error: ${error.message}`);
    }
}

/**
 * Item Management Examples
 */
async function itemManagementExamples(client) {
    console.log('\n📦 Item Management Examples');
    console.log('-'.repeat(40));

    try {
        // 1. Get items with stock information
        console.log('1. Fetching items...');
        const items = await client.get('/api/resource/Item', {
            fields: JSON.stringify(['item_code', 'item_name', 'item_group', 'stock_uom', 'standard_rate']),
            filters: JSON.stringify([['disabled', '=', 0]]),
            limit_page_length: 5
        });

        if (items?.data?.length > 0) {
            items.data.forEach((item, index) => {
                const rate = item.standard_rate || 'Not set';
                console.log(`   ${index + 1}. ${item.item_code} - ${item.item_name} (${rate})`);
            });
        } else {
            console.log('   No items found. Creating sample item...');
            
            // Create a sample item if none exist
            const sampleItem = {
                item_code: `SAMPLE-${Date.now()}`,
                item_name: 'Sample Item from API',
                item_group: 'All Item Groups',
                stock_uom: 'Nos',
                standard_rate: 100.00,
                is_stock_item: 1
            };

            try {
                const newItem = await client.post('/api/resource/Item', sampleItem);
                console.log(`   ✅ Created sample item: ${newItem.data.name}`);
            } catch (error) {
                console.log(`   ⚠️  Item creation failed: ${error.response?.data?.message || error.message}`);
            }
        }

        // 2. Get item groups
        console.log('\n2. Fetching item groups...');
        const itemGroups = await client.get('/api/resource/Item Group', {
            fields: JSON.stringify(['name', 'parent_item_group']),
            limit_page_length: 5
        });

        if (itemGroups?.data?.length > 0) {
            itemGroups.data.forEach((group, index) => {
                console.log(`   ${index + 1}. ${group.name} (Parent: ${group.parent_item_group || 'None'})`);
            });
        }

    } catch (error) {
        console.error(`❌ Item management error: ${error.message}`);
    }
}

/**
 * Sales Order Examples
 */
async function salesOrderExamples(client) {
    console.log('\n📄 Sales Order Examples');
    console.log('-'.repeat(40));

    try {
        // 1. Get recent sales orders
        console.log('1. Fetching recent sales orders...');
        const salesOrders = await client.get('/api/resource/Sales Order', {
            fields: JSON.stringify(['name', 'customer', 'status', 'grand_total', 'transaction_date']),
            order_by: 'creation desc',
            limit_page_length: 5
        });

        if (salesOrders?.data?.length > 0) {
            salesOrders.data.forEach((order, index) => {
                console.log(`   ${index + 1}. ${order.name} - ${order.customer} (${order.status}) - ${order.grand_total || 0}`);
            });
        } else {
            console.log('   No sales orders found.');
        }

        // 2. Get sales order statuses
        console.log('\n2. Sales order status breakdown...');
        try {
            const statusBreakdown = await client.get('/api/resource/Sales Order', {
                fields: JSON.stringify(['status']),
                limit_page_length: 100 // Get more for status analysis
            });

            if (statusBreakdown?.data?.length > 0) {
                const statusCount = {};
                statusBreakdown.data.forEach(order => {
                    const status = order.status || 'Unknown';
                    statusCount[status] = (statusCount[status] || 0) + 1;
                });

                Object.entries(statusCount).forEach(([status, count]) => {
                    console.log(`   ${status}: ${count} orders`);
                });
            }
        } catch (error) {
            console.log('   ⚠️  Status breakdown not available');
        }

    } catch (error) {
        console.error(`❌ Sales order error: ${error.message}`);
    }
}

/**
 * User and Permission Examples
 */
async function userPermissionExamples(client) {
    console.log('\n👥 User and Permission Examples');
    console.log('-'.repeat(40));

    try {
        // 1. Get current user info
        console.log('1. Getting current user info...');
        const currentUser = await client.get('/api/method/frappe.auth.get_logged_user');
        console.log(`   Current user: ${currentUser.message || 'Unknown'}`);

        // 2. Get all users (limited)
        console.log('\n2. Fetching system users...');
        const users = await client.get('/api/resource/User', {
            fields: JSON.stringify(['name', 'full_name', 'enabled', 'user_type']),
            filters: JSON.stringify([['enabled', '=', 1]]),
            limit_page_length: 5
        });

        if (users?.data?.length > 0) {
            users.data.forEach((user, index) => {
                console.log(`   ${index + 1}. ${user.full_name || user.name} (${user.user_type || 'System User'})`);
            });
        }

        // 3. Get user roles (if accessible)
        console.log('\n3. Available roles in system...');
        try {
            const roles = await client.get('/api/resource/Role', {
                fields: JSON.stringify(['name', 'disabled']),
                filters: JSON.stringify([['disabled', '=', 0]]),
                limit_page_length: 10
            });

            if (roles?.data?.length > 0) {
                roles.data.forEach((role, index) => {
                    console.log(`   ${index + 1}. ${role.name}`);
                });
            }
        } catch (error) {
            console.log('   ⚠️  Role information not accessible');
        }

    } catch (error) {
        console.error(`❌ User/permission error: ${error.message}`);
    }
}

/**
 * System Information Examples
 */
async function systemInfoExamples(client) {
    console.log('\n⚙️  System Information Examples');
    console.log('-'.repeat(40));

    try {
        // 1. Get system settings
        console.log('1. System configuration...');
        const systemSettings = await client.get('/api/resource/System Settings/System Settings');
        if (systemSettings?.data) {
            const data = systemSettings.data;
            console.log(`   Country: ${data.country || 'Not set'}`);
            console.log(`   Time Zone: ${data.time_zone || 'Not set'}`);
            console.log(`   Currency: ${data.currency || 'Not set'}`);
            console.log(`   Date Format: ${data.date_format || 'Not set'}`);
        }

        // 2. Get company information
        console.log('\n2. Company information...');
        const companies = await client.get('/api/resource/Company', {
            fields: JSON.stringify(['name', 'company_name', 'default_currency', 'country'])
        });

        if (companies?.data?.length > 0) {
            companies.data.forEach((company, index) => {
                console.log(`   ${index + 1}. ${company.company_name || company.name} (${company.country || 'Unknown'})`);
            });
        }

        // 3. Get fiscal year
        console.log('\n3. Fiscal year information...');
        const fiscalYears = await client.get('/api/resource/Fiscal Year', {
            fields: JSON.stringify(['name', 'year_start_date', 'year_end_date']),
            limit_page_length: 3
        });

        if (fiscalYears?.data?.length > 0) {
            fiscalYears.data.forEach((year, index) => {
                console.log(`   ${index + 1}. ${year.name}: ${year.year_start_date} to ${year.year_end_date}`);
            });
        }

    } catch (error) {
        console.error(`❌ System info error: ${error.message}`);
    }
}

/**
 * Error Handling Examples
 */
async function errorHandlingExamples(client) {
    console.log('\n⚠️  Error Handling Examples');
    console.log('-'.repeat(40));

    // 1. Handle non-existent resource
    console.log('1. Testing non-existent resource...');
    try {
        await client.get('/api/resource/NonExistentDocType');
    } catch (error) {
        const status = error.response?.status;
        const message = error.response?.data?.message || error.message;
        console.log(`   ✅ Properly caught error: ${status} - ${message}`);
    }

    // 2. Handle invalid filter
    console.log('\n2. Testing invalid filter...');
    try {
        await client.get('/api/resource/Customer', {
            filters: 'invalid-filter-format'
        });
    } catch (error) {
        const message = error.response?.data?.message || error.message;
        console.log(`   ✅ Filter validation error caught: ${message.substring(0, 100)}...`);
    }

    // 3. Handle permission error (if applicable)
    console.log('\n3. Testing potential permission restrictions...');
    try {
        await client.delete('/api/resource/User/Administrator');
    } catch (error) {
        const status = error.response?.status;
        const message = error.response?.data?.message || error.message;
        console.log(`   ✅ Permission error handled: ${status} - ${message.substring(0, 80)}...`);
    }
}

/**
 * Performance and Caching Examples
 */
async function performanceExamples() {
    console.log('\n🚀 Performance and Caching Examples');
    console.log('-'.repeat(40));

    const perfClient = new ERPNextAdvancedSecureClient(process.env.ERPNEXT_URL || 'http://localhost:8080', {
        enableCache: true,
        cacheTimeout: 30000, // 30 seconds
        retryAttempts: 2,
        rateLimitPerMinute: 30
    });

    if (await perfClient.authenticateWithToken()) {
        console.log('1. Testing response caching...');
        
        // First request (will hit the API)
        console.time('First API call');
        await perfClient.get('/api/resource/Company', { limit_page_length: 1 });
        console.timeEnd('First API call');

        // Second request (should use cache)
        console.time('Cached call');
        await perfClient.get('/api/resource/Company', { limit_page_length: 1 });
        console.timeEnd('Cached call');

        console.log('2. Testing rate limiting...');
        const promises = [];
        for (let i = 0; i < 5; i++) {
            promises.push(perfClient.get('/api/resource/User', { limit_page_length: 1 }));
        }
        
        console.time('Rate limited requests');
        await Promise.all(promises);
        console.timeEnd('Rate limited requests');

        perfClient.clearCache();
        await perfClient.logout();
    }
}

/**
 * Main execution function
 */
async function runExamples() {
    console.log('ERPNext API Examples - Practical Usage Patterns');
    console.log('='.repeat(60));

    // Initialize client
    const client = new ERPNextSecureClient(process.env.ERPNEXT_URL || 'http://localhost:8080');

    try {
        // Authenticate using token (recommended)
        const authenticated = await client.authenticateWithToken(
            process.env.ERPNEXT_API_KEY,
            process.env.ERPNEXT_API_SECRET
        );

        if (!authenticated) {
            console.error('❌ Authentication failed. Please check your API credentials.');
            console.log('\n💡 Make sure you have:');
            console.log('   - Set ERPNEXT_API_KEY environment variable');
            console.log('   - Set ERPNEXT_API_SECRET environment variable');
            console.log('   - ERPNext is running and accessible');
            return;
        }

        // Run all example categories
        await systemInfoExamples(client);
        await userPermissionExamples(client);
        await customerManagementExamples(client);
        await itemManagementExamples(client);
        await salesOrderExamples(client);
        await errorHandlingExamples(client);

        // Logout
        await client.logout();

        // Performance examples (separate client)
        await performanceExamples();

        console.log('\n✅ All examples completed successfully!');
        console.log('\n📊 Check the generated log files:');
        console.log('   - api_security.log (authentication events)');
        console.log('   - api_requests.log (API request audit trail)');

    } catch (error) {
        console.error(`❌ Example execution failed: ${error.message}`);
        
        if (error.code === 'ECONNREFUSED') {
            console.log('\n💡 Make sure ERPNext is running:');
            console.log('   docker-compose up -d');
        }
    }
}

// Export for use as module
module.exports = {
    customerManagementExamples,
    itemManagementExamples,
    salesOrderExamples,
    userPermissionExamples,
    systemInfoExamples,
    errorHandlingExamples,
    performanceExamples
};

// Run examples if called directly
if (require.main === module) {
    runExamples().catch(error => {
        console.error('Fatal error:', error.message);
        process.exit(1);
    });
}