#!/usr/bin/env python3

import requests
import json
from datetime import datetime
import urllib.parse

# Configuration
API_URL = "http://localhost:8080"
USERNAME = "Administrator"
PASSWORD = "LocalDev123!"

def login():
    """Login and return session"""
    session = requests.Session()
    response = session.post(
        f"{API_URL}/api/method/login",
        json={"usr": USERNAME, "pwd": PASSWORD}
    )
    if response.status_code == 200:
        print("✓ Logged in successfully")
        return session
    else:
        print("✗ Login failed")
        return None

def get_all_doctypes(session):
    """Fetch all DocTypes"""
    response = session.get(
        f"{API_URL}/api/resource/DocType",
        params={
            "limit_page_length": 1000,
            "fields": json.dumps(["name", "module", "issingle", "is_submittable", "istable"])
        }
    )
    if response.status_code == 200:
        return response.json().get("data", [])
    return []

def get_sample_records(session, doctype, limit=3):
    """Get sample record names for a DocType"""
    try:
        # URL encode the DocType name
        doctype_encoded = urllib.parse.quote(doctype)
        response = session.get(
            f"{API_URL}/api/resource/{doctype_encoded}",
            params={
                "limit_page_length": limit,
                "fields": json.dumps(["name"])
            }
        )
        if response.status_code == 200:
            data = response.json().get("data", [])
            return [record.get("name", "") for record in data]
    except:
        pass
    return []

def generate_documentation(session):
    """Generate comprehensive API documentation"""
    
    print("Fetching all DocTypes...")
    doctypes = get_all_doctypes(session)
    print(f"Found {len(doctypes)} DocTypes")
    
    # Group by module
    modules = {}
    for doctype in doctypes:
        module = doctype.get("module", "Unknown")
        if module not in modules:
            modules[module] = []
        modules[module].append(doctype)
    
    # Sort modules
    sorted_modules = sorted(modules.keys())
    
    # Generate markdown
    doc = []
    doc.append("# ERPNext API Endpoints Documentation")
    doc.append("")
    doc.append(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    doc.append("")
    doc.append("This document provides a comprehensive list of all available API endpoints in ERPNext.")
    doc.append("")
    
    # Authentication section
    doc.append("## Authentication")
    doc.append("")
    doc.append("All API calls require authentication. First, login to get a session:")
    doc.append("")
    doc.append("```bash")
    doc.append("curl -c cookies.txt -X POST \\")
    doc.append("  -H \"Content-Type: application/json\" \\")
    doc.append("  -d '{\"usr\":\"Administrator\",\"pwd\":\"your_password\"}' \\")
    doc.append("  http://localhost:8080/api/method/login")
    doc.append("```")
    doc.append("")
    
    # API Pattern section
    doc.append("## API Endpoint Pattern")
    doc.append("")
    doc.append("All DocTypes follow the same RESTful pattern:")
    doc.append("")
    doc.append("- **List/Search**: `GET /api/resource/{DocType}`")
    doc.append("- **Get Single**: `GET /api/resource/{DocType}/{name}`")
    doc.append("- **Create**: `POST /api/resource/{DocType}`")
    doc.append("- **Update**: `PUT /api/resource/{DocType}/{name}`")
    doc.append("- **Delete**: `DELETE /api/resource/{DocType}/{name}`")
    doc.append("")
    
    # Table of Contents
    doc.append("## Table of Contents")
    doc.append("")
    for module in sorted_modules:
        doc.append(f"- [{module}](#{module.lower().replace(' ', '-')})")
    doc.append("")
    
    # DocTypes by Module
    doc.append("## Available DocTypes by Module")
    doc.append("")
    
    total_processed = 0
    for module in sorted_modules:
        print(f"\nProcessing module: {module}")
        doc.append(f"### {module}")
        doc.append("")
        doc.append("| DocType | Type | Sample Names | API Endpoints |")
        doc.append("|---------|------|--------------|---------------|")
        
        module_doctypes = sorted(modules[module], key=lambda x: x.get("name", ""))
        
        for doctype_info in module_doctypes:
            doctype = doctype_info.get("name", "")
            issingle = doctype_info.get("issingle", 0)
            istable = doctype_info.get("istable", 0)
            is_submittable = doctype_info.get("is_submittable", 0)
            
            # Determine type
            if issingle:
                dtype = "Single"
            elif istable:
                dtype = "Child Table"
            elif is_submittable:
                dtype = "Submittable"
            else:
                dtype = "Standard"
            
            # Get sample records
            if issingle:
                samples = [doctype]
            elif istable:
                samples = ["(Child of parent doc)"]
            else:
                samples = get_sample_records(session, doctype)
                if not samples:
                    samples = ["(No records)"]
            
            # Format samples
            sample_str = ", ".join(str(s) for s in samples[:2])
            if len(sample_str) > 40:
                sample_str = sample_str[:37] + "..."
            
            # Format endpoints
            doctype_url = urllib.parse.quote(doctype)
            if issingle:
                endpoints = f"`GET /api/resource/{doctype_url}/{doctype_url}`"
            else:
                endpoints = f"`/api/resource/{doctype_url}`"
            
            doc.append(f"| {doctype} | {dtype} | {sample_str} | {endpoints} |")
            
            total_processed += 1
            if total_processed % 10 == 0:
                print(f"  Processed {total_processed} DocTypes...")
        
        doc.append("")
    
    print(f"\nProcessed {total_processed} DocTypes total")
    
    # Common Query Parameters
    doc.append("## Common Query Parameters")
    doc.append("")
    doc.append("### For List Endpoints")
    doc.append("")
    doc.append("| Parameter | Description | Example |")
    doc.append("|-----------|-------------|---------|")
    doc.append("| `fields` | Select specific fields | `fields=[\"name\",\"status\"]` |")
    doc.append("| `filters` | Filter results | `filters=[[\"status\",\"=\",\"Active\"]]` |")
    doc.append("| `limit_start` | Pagination offset | `limit_start=0` |")
    doc.append("| `limit_page_length` | Page size | `limit_page_length=20` |")
    doc.append("| `order_by` | Sort results | `order_by=modified desc` |")
    doc.append("")
    
    # Examples section
    doc.append("## Examples")
    doc.append("")
    doc.append("### Get list with filters")
    doc.append("```bash")
    doc.append("curl -b cookies.txt \\")
    doc.append("  \"http://localhost:8080/api/resource/Item?filters=[[\\\"item_group\\\",\\\"=\\\",\\\"Products\\\"]]&fields=[\\\"item_code\\\",\\\"item_name\\\"]\"")
    doc.append("```")
    doc.append("")
    doc.append("### Get single document")
    doc.append("```bash")
    doc.append("curl -b cookies.txt \\")
    doc.append("  \"http://localhost:8080/api/resource/User/Administrator\"")
    doc.append("```")
    doc.append("")
    doc.append("### Create new document")
    doc.append("```bash")
    doc.append("curl -b cookies.txt -X POST \\")
    doc.append("  -H \"Content-Type: application/json\" \\")
    doc.append("  -d '{\"doctype\":\"Item\",\"item_code\":\"TEST-001\",\"item_name\":\"Test Item\",\"item_group\":\"Products\",\"stock_uom\":\"Nos\"}' \\")
    doc.append("  \"http://localhost:8080/api/resource/Item\"")
    doc.append("```")
    doc.append("")
    doc.append("### Update document")
    doc.append("```bash")
    doc.append("curl -b cookies.txt -X PUT \\")
    doc.append("  -H \"Content-Type: application/json\" \\")
    doc.append("  -d '{\"item_name\":\"Updated Test Item\"}' \\")
    doc.append("  \"http://localhost:8080/api/resource/Item/TEST-001\"")
    doc.append("```")
    doc.append("")
    doc.append("### Delete document")
    doc.append("```bash")
    doc.append("curl -b cookies.txt -X DELETE \\")
    doc.append("  \"http://localhost:8080/api/resource/Item/TEST-001\"")
    doc.append("```")
    doc.append("")
    
    # Special Endpoints
    doc.append("## Special Endpoints")
    doc.append("")
    doc.append("### Authentication")
    doc.append("- `POST /api/method/login` - Login")
    doc.append("- `POST /api/method/logout` - Logout")
    doc.append("")
    doc.append("### File Operations")
    doc.append("- `POST /api/method/upload_file` - Upload files")
    doc.append("- `GET /api/method/download_file` - Download files")
    doc.append("")
    doc.append("### Reports")
    doc.append("- `GET /api/method/frappe.desk.query_report.run` - Run reports")
    doc.append("")
    
    # DocType Categories
    doc.append("## DocType Categories")
    doc.append("")
    doc.append("### Single DocTypes")
    doc.append("These DocTypes have only one record (singleton pattern):")
    doc.append("")
    single_docs = [d.get("name") for d in doctypes if d.get("issingle")]
    for doc_name in sorted(single_docs)[:20]:  # Show first 20
        doc.append(f"- {doc_name}")
    if len(single_docs) > 20:
        doc.append(f"- ... and {len(single_docs) - 20} more")
    doc.append("")
    
    doc.append("### Child Tables")
    doc.append("These DocTypes are child tables and cannot be accessed directly:")
    doc.append("")
    child_docs = [d.get("name") for d in doctypes if d.get("istable")]
    for doc_name in sorted(child_docs)[:20]:  # Show first 20
        doc.append(f"- {doc_name}")
    if len(child_docs) > 20:
        doc.append(f"- ... and {len(child_docs) - 20} more")
    doc.append("")
    
    doc.append("### Submittable DocTypes")
    doc.append("These DocTypes support document submission workflow:")
    doc.append("")
    submit_docs = [d.get("name") for d in doctypes if d.get("is_submittable")]
    for doc_name in sorted(submit_docs)[:20]:  # Show first 20
        doc.append(f"- {doc_name}")
    if len(submit_docs) > 20:
        doc.append(f"- ... and {len(submit_docs) - 20} more")
    doc.append("")
    
    # Notes
    doc.append("## Important Notes")
    doc.append("")
    doc.append("1. **URL Encoding**: DocType names with spaces must be URL encoded (e.g., \"Sales Order\" → \"Sales%20Order\")")
    doc.append("2. **Permissions**: Access to DocTypes depends on user permissions")
    doc.append("3. **Rate Limiting**: Default rate limit is 60 requests per minute")
    doc.append("4. **Single DocTypes**: Use the DocType name as both the resource and document name")
    doc.append("5. **Child Tables**: Cannot be accessed directly, only through their parent document")
    doc.append("6. **Submittable Documents**: Support additional states (Draft, Submitted, Cancelled)")
    doc.append("")
    
    return "\n".join(doc)

def main():
    print("=" * 50)
    print("ERPNext API Documentation Generator")
    print("=" * 50)
    print()
    
    # Login
    session = login()
    if not session:
        print("Failed to login!")
        return
    
    # Generate documentation
    documentation = generate_documentation(session)
    
    # Save to file
    output_file = "API_ENDPOINTS.md"
    with open(output_file, "w") as f:
        f.write(documentation)
    
    print()
    print("=" * 50)
    print(f"✓ Documentation saved to: {output_file}")
    print("=" * 50)

if __name__ == "__main__":
    main()