#!/usr/bin/env python3
"""
Secure ERPNext API Client
Demonstrates best practices for API authentication and security
"""

import os
import requests
import json
import getpass
from datetime import datetime
import hashlib
import hmac
from urllib.parse import urlparse

class ERPNextSecureClient:
    """
    Secure ERPNext API Client with multiple authentication methods
    """
    
    def __init__(self, base_url="http://localhost:8080"):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        self.auth_method = None
        
        # Security headers
        self.session.headers.update({
            'User-Agent': 'ERPNext-Secure-Client/1.0',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        })
        
        # Verify SSL in production
        if urlparse(base_url).scheme == 'https':
            self.session.verify = True
        else:
            print("⚠️  WARNING: Using HTTP. Use HTTPS in production!")
    
    def login_with_credentials(self, username=None, password=None):
        """
        Login using username/password (creates session cookie)
        SECURITY: Use only for web applications, not for API clients
        """
        if not username:
            username = input("Username: ")
        if not password:
            password = getpass.getpass("Password: ")
        
        login_data = {"usr": username, "pwd": password}
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/method/login",
                json=login_data
            )
            response.raise_for_status()
            
            result = response.json()
            if "message" in result and "Logged In" in result["message"]:
                self.auth_method = "session"
                print("✅ Logged in successfully (session-based)")
                self._log_auth_event("LOGIN_SUCCESS", username)
                return True
            else:
                print("❌ Login failed")
                self._log_auth_event("LOGIN_FAILED", username)
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Login error: {e}")
            self._log_auth_event("LOGIN_ERROR", username, str(e))
            return False
    
    def authenticate_with_token(self, api_key=None, api_secret=None):
        """
        Setup token-based authentication
        SECURITY: Recommended for API clients and server-to-server communication
        """
        if not api_key:
            api_key = os.environ.get('ERPNEXT_API_KEY')
            if not api_key:
                api_key = input("API Key: ")
        
        if not api_secret:
            api_secret = os.environ.get('ERPNEXT_API_SECRET')
            if not api_secret:
                api_secret = getpass.getpass("API Secret: ")
        
        self.api_key = api_key
        self.api_secret = api_secret
        self.auth_method = "token"
        
        # Update session headers for token auth
        self.session.headers.update({
            'Authorization': f'token {api_key}:{api_secret}'
        })
        
        # Test the token
        try:
            response = self.get('/api/resource/User', params={'limit_page_length': 1})
            print("✅ Token authentication successful")
            self._log_auth_event("TOKEN_AUTH_SUCCESS", api_key[:8] + "...")
            return True
        except Exception as e:
            print(f"❌ Token authentication failed: {e}")
            self._log_auth_event("TOKEN_AUTH_FAILED", api_key[:8] + "...", str(e))
            return False
    
    def generate_api_key_instructions(self):
        """
        Print instructions for generating API keys
        """
        print("\n" + "="*60)
        print("HOW TO GENERATE API KEYS:")
        print("="*60)
        print("1. Login to ERPNext web interface")
        print("2. Go to Settings → My Settings")
        print("3. Scroll to 'API Access' section")
        print("4. Click 'Generate Keys'")
        print("5. Copy the API Key and API Secret")
        print("6. Store them securely (environment variables recommended)")
        print("\nEnvironment Variables:")
        print("export ERPNEXT_API_KEY='your_api_key_here'")
        print("export ERPNEXT_API_SECRET='your_api_secret_here'")
        print("="*60)
    
    def _log_auth_event(self, event, user, details=""):
        """Log authentication events for security audit"""
        timestamp = datetime.now().isoformat()
        log_entry = f"{timestamp} - {event} - User: {user} - {details}\n"
        
        try:
            with open('api_security.log', 'a') as f:
                f.write(log_entry)
        except:
            pass  # Don't fail if logging fails
    
    def _make_secure_request(self, method, endpoint, **kwargs):
        """
        Make secure API request with proper error handling and logging
        """
        if self.auth_method != "session" and self.auth_method != "token":
            raise Exception("Not authenticated. Use login_with_credentials() or authenticate_with_token()")
        
        # Add security headers
        if 'headers' not in kwargs:
            kwargs['headers'] = {}
        
        # Add timestamp for audit
        kwargs['headers']['X-Request-Time'] = datetime.now().isoformat()
        
        # Make request
        try:
            response = self.session.request(method, f"{self.base_url}{endpoint}", **kwargs)
            
            # Log request for audit
            self._log_request(method, endpoint, response.status_code)
            
            # Handle authentication errors
            if response.status_code == 401:
                print("❌ Authentication failed. Token may be expired.")
                return None
            elif response.status_code == 403:
                print("❌ Access forbidden. Check permissions.")
                return None
            elif response.status_code == 429:
                print("❌ Rate limit exceeded. Please wait.")
                return None
            
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Request failed: {e}")
            self._log_request(method, endpoint, 0, str(e))
            raise
    
    def _log_request(self, method, endpoint, status_code, error=""):
        """Log API requests for audit"""
        timestamp = datetime.now().isoformat()
        user = getattr(self, 'current_user', 'unknown')
        log_entry = f"{timestamp} - {method} {endpoint} - {status_code} - User: {user} - {error}\n"
        
        try:
            with open('api_requests.log', 'a') as f:
                f.write(log_entry)
        except:
            pass
    
    # Secure API methods
    def get(self, endpoint, params=None):
        """Secure GET request"""
        return self._make_secure_request('GET', endpoint, params=params)
    
    def post(self, endpoint, data=None):
        """Secure POST request"""
        return self._make_secure_request('POST', endpoint, json=data)
    
    def put(self, endpoint, data=None):
        """Secure PUT request"""
        return self._make_secure_request('PUT', endpoint, json=data)
    
    def delete(self, endpoint):
        """Secure DELETE request"""
        return self._make_secure_request('DELETE', endpoint)
    
    def logout(self):
        """Logout and clear session"""
        if self.auth_method == "session":
            try:
                self.session.post(f"{self.base_url}/api/method/logout")
                print("✅ Logged out successfully")
            except:
                pass
        
        self.session.cookies.clear()
        self.auth_method = None
        print("🔒 Session cleared")

def demo_secure_usage():
    """
    Demonstrate secure API usage patterns
    """
    print("ERPNext Secure API Client Demo")
    print("="*40)
    
    client = ERPNextSecureClient()
    
    # Method 1: API Token (Recommended for APIs)
    print("\n🔐 Method 1: API Token Authentication (Recommended)")
    print("-" * 50)
    
    if client.authenticate_with_token():
        # Demo secure API calls
        try:
            print("\n📊 Fetching system info...")
            system_settings = client.get('/api/resource/System%20Settings/System%20Settings')
            if system_settings:
                data = system_settings.get('data', {})
                print(f"   Country: {data.get('country', 'Not set')}")
                print(f"   Time Zone: {data.get('time_zone', 'Not set')}")
            
            print("\n👥 Fetching users (limited)...")
            users = client.get('/api/resource/User', params={'limit_page_length': 3})
            if users:
                for user in users.get('data', []):
                    print(f"   - {user.get('full_name', 'Unknown')} ({user.get('name', 'unknown')})")
            
            print("\n🏢 Checking companies...")
            companies = client.get('/api/resource/Company')
            if companies:
                for company in companies.get('data', []):
                    print(f"   - {company.get('name', 'Unknown Company')}")
            
        except Exception as e:
            print(f"❌ Error during API calls: {e}")
        
        client.logout()
    else:
        client.generate_api_key_instructions()
        
        # Method 2: Session Authentication (for web apps)
        print("\n🌐 Method 2: Session Authentication (Web Apps)")
        print("-" * 50)
        print("Would you like to try session-based login? (y/n): ", end='')
        if input().lower().startswith('y'):
            if client.login_with_credentials():
                try:
                    # Demo with session
                    users = client.get('/api/resource/User', params={'limit_page_length': 1})
                    if users:
                        print("✅ Session-based API call successful")
                    
                except Exception as e:
                    print(f"❌ Session API call failed: {e}")
                
                client.logout()

def security_recommendations():
    """
    Print security recommendations
    """
    print("\n" + "="*60)
    print("🔒 SECURITY RECOMMENDATIONS")
    print("="*60)
    print("1. ✅ USE API TOKENS for server-to-server communication")
    print("2. ✅ USE HTTPS in production (never HTTP)")
    print("3. ✅ STORE credentials in environment variables")
    print("4. ✅ IMPLEMENT rate limiting")
    print("5. ✅ LOG all API access for audit trails")
    print("6. ✅ ROTATE API keys regularly (every 90 days)")
    print("7. ✅ USE IP whitelisting when possible")
    print("8. ✅ IMPLEMENT proper error handling")
    print("9. ✅ VALIDATE all inputs")
    print("10. ✅ MONITOR for unusual access patterns")
    print("\n❌ AVOID:")
    print("- Never commit API keys to version control")
    print("- Never use Basic Auth in production")
    print("- Never use HTTP in production")
    print("- Never expose API keys in logs")
    print("- Never use session cookies for mobile apps")
    print("="*60)

if __name__ == "__main__":
    try:
        demo_secure_usage()
        security_recommendations()
    except KeyboardInterrupt:
        print("\n\n👋 Goodbye!")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")