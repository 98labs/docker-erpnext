#!/bin/bash

# ERPNext API Discovery Script
# This script discovers all available DocTypes and their endpoints

API_URL="http://localhost:8080"
USERNAME="Administrator"
PASSWORD="LocalDev123!"
OUTPUT_FILE="API_ENDPOINTS.md"

echo "======================================"
echo "ERPNext API Discovery Script"
echo "======================================"
echo ""

# Login
echo "Logging in..."
curl -s -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d "{\"usr\":\"$USERNAME\",\"pwd\":\"$PASSWORD\"}" \
  $API_URL/api/method/login > /dev/null

# Get all DocTypes
echo "Fetching all DocTypes..."
ALL_DOCTYPES=$(curl -s -b cookies.txt "$API_URL/api/resource/DocType?limit_page_length=1000&fields=\[\"name\",\"module\",\"is_submittable\",\"issingle\"\]" | jq -r '.data')

# Start creating the documentation
cat > $OUTPUT_FILE << 'EOF'
# ERPNext API Endpoints Documentation

Generated on: $(date)

This document provides a comprehensive list of all available API endpoints in ERPNext.

## Authentication

All API calls require authentication. First, login to get a session:

```bash
curl -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"usr":"Administrator","pwd":"your_password"}' \
  http://localhost:8080/api/method/login
```

## API Endpoint Pattern

All DocTypes follow the same RESTful pattern:

- **List/Search**: `GET /api/resource/{DocType}`
- **Get Single**: `GET /api/resource/{DocType}/{name}`
- **Create**: `POST /api/resource/{DocType}`
- **Update**: `PUT /api/resource/{DocType}/{name}`
- **Delete**: `DELETE /api/resource/{DocType}/{name}`

## Available DocTypes and Endpoints

EOF

echo "" >> $OUTPUT_FILE
echo "Processing DocTypes and getting sample data..."

# Process each module
MODULES=$(echo "$ALL_DOCTYPES" | jq -r '.[].module' | sort -u)

for MODULE in $MODULES; do
    echo "Processing module: $MODULE"
    echo "" >> $OUTPUT_FILE
    echo "### Module: $MODULE" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
    echo "| DocType | Single/List | Sample Names | Endpoints |" >> $OUTPUT_FILE
    echo "|---------|-------------|--------------|-----------|" >> $OUTPUT_FILE
    
    # Get DocTypes for this module
    MODULE_DOCTYPES=$(echo "$ALL_DOCTYPES" | jq -r ".[] | select(.module==\"$MODULE\") | .name")
    
    for DOCTYPE in $MODULE_DOCTYPES; do
        # URL encode the DocType name
        DOCTYPE_ENCODED=$(echo "$DOCTYPE" | sed 's/ /%20/g')
        
        # Check if it's a single DocType
        IS_SINGLE=$(echo "$ALL_DOCTYPES" | jq -r ".[] | select(.name==\"$DOCTYPE\") | .issingle")
        
        # Get sample records (limit to 3)
        SAMPLE_RECORDS=$(curl -s -b cookies.txt "$API_URL/api/resource/$DOCTYPE_ENCODED?limit_page_length=3&fields=\[\"name\"\]" 2>/dev/null | jq -r '.data[]?.name' 2>/dev/null | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')
        
        if [ "$IS_SINGLE" == "1" ]; then
            TYPE="Single"
            ENDPOINTS="\`GET /api/resource/$DOCTYPE/$DOCTYPE\`"
            SAMPLE_RECORDS="$DOCTYPE"
        else
            TYPE="List"
            ENDPOINTS="\`/api/resource/$DOCTYPE\`"
            if [ -z "$SAMPLE_RECORDS" ]; then
                SAMPLE_RECORDS="No records"
            fi
        fi
        
        # Escape pipe characters in sample records
        SAMPLE_RECORDS=$(echo "$SAMPLE_RECORDS" | sed 's/|/\\|/g')
        
        # Truncate if too long
        if [ ${#SAMPLE_RECORDS} -gt 50 ]; then
            SAMPLE_RECORDS="${SAMPLE_RECORDS:0:47}..."
        fi
        
        echo "| $DOCTYPE | $TYPE | $SAMPLE_RECORDS | $ENDPOINTS |" >> $OUTPUT_FILE
    done
done

# Add common query parameters section
cat >> $OUTPUT_FILE << 'EOF'

## Common Query Parameters

### For List Endpoints

| Parameter | Description | Example |
|-----------|-------------|---------|
| `fields` | Select specific fields | `fields=["name","status"]` |
| `filters` | Filter results | `filters=[["status","=","Active"]]` |
| `limit_start` | Pagination offset | `limit_start=0` |
| `limit_page_length` | Page size | `limit_page_length=20` |
| `order_by` | Sort results | `order_by=modified desc` |

### Examples

#### Get list with filters
```bash
curl -b cookies.txt \
  "http://localhost:8080/api/resource/Item?filters=[[\"item_group\",\"=\",\"Products\"]]&fields=[\"item_code\",\"item_name\"]"
```

#### Get single document
```bash
curl -b cookies.txt \
  "http://localhost:8080/api/resource/User/Administrator"
```

#### Create new document
```bash
curl -b cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"doctype":"Item","item_code":"TEST-001","item_name":"Test Item","item_group":"Products","stock_uom":"Nos"}' \
  "http://localhost:8080/api/resource/Item"
```

#### Update document
```bash
curl -b cookies.txt -X PUT \
  -H "Content-Type: application/json" \
  -d '{"item_name":"Updated Test Item"}' \
  "http://localhost:8080/api/resource/Item/TEST-001"
```

#### Delete document
```bash
curl -b cookies.txt -X DELETE \
  "http://localhost:8080/api/resource/Item/TEST-001"
```

## Special Endpoints

### Authentication
- `POST /api/method/login` - Login
- `POST /api/method/logout` - Logout

### File Upload
- `POST /api/method/upload_file` - Upload files

### Reports
- `GET /api/method/frappe.desk.query_report.run` - Run reports

## Notes

1. **Single DocTypes**: These DocTypes have only one record (like System Settings) and use their name directly in the URL
2. **URL Encoding**: DocType names with spaces must be URL encoded (e.g., "Sales Order" becomes "Sales%20Order")
3. **Permissions**: Access to DocTypes depends on user permissions
4. **Rate Limiting**: Default rate limit is 60 requests per minute

EOF

echo ""
echo "======================================"
echo "Discovery complete!"
echo "Documentation saved to: $OUTPUT_FILE"
echo "======================================"

# Clean up
rm -f cookies.txt