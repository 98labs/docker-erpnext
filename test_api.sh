#!/bin/bash

# ERPNext API Test Script
# This script demonstrates how to access ERPNext APIs

API_URL="http://localhost:8080"
USERNAME="Administrator"
PASSWORD="LocalDev123!"

echo "======================================"
echo "ERPNext API Test Script"
echo "======================================"
echo ""

# 1. Login and save cookies
echo "1. Logging in..."
curl -s -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d "{\"usr\":\"$USERNAME\",\"pwd\":\"$PASSWORD\"}" \
  $API_URL/api/method/login | jq '.'

echo ""
echo "2. Getting list of DocTypes (first 5)..."
curl -s -b cookies.txt "$API_URL/api/resource/DocType?limit_page_length=5" | jq '.data[].name'

echo ""
echo "3. Getting list of Users..."
curl -s -b cookies.txt "$API_URL/api/resource/User?fields=\[\"name\",\"full_name\",\"enabled\"\]&limit_page_length=3" | jq '.'

echo ""
echo "4. Getting system settings..."
curl -s -b cookies.txt "$API_URL/api/resource/System%20Settings/System%20Settings" | jq '{country: .data.country, timezone: .data.time_zone}'

echo ""
echo "5. Getting Company list..."
curl -s -b cookies.txt "$API_URL/api/resource/Company" | jq '.'

echo ""
echo "======================================"
echo "API test complete!"
echo "======================================"

# Clean up
rm -f cookies.txt