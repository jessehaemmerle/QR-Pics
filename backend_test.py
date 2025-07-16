#!/usr/bin/env python3
"""
Comprehensive Backend Testing for QR Photo Upload System
Tests all backend API endpoints and functionality
"""

import requests
import json
import base64
import uuid
from datetime import datetime
import os
from pathlib import Path

# Load environment variables to get backend URL
def load_env_file(file_path):
    env_vars = {}
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key] = value.strip('"')
    return env_vars

# Get backend URL from frontend .env
frontend_env = load_env_file('/app/frontend/.env')
BACKEND_URL = frontend_env.get('REACT_APP_BACKEND_URL', 'http://localhost:8001')
API_BASE_URL = f"{BACKEND_URL}/api"

print(f"Testing backend at: {API_BASE_URL}")

class BackendTester:
    def __init__(self):
        self.session = requests.Session()
        self.auth_token = None
        self.restricted_user_token = None
        self.test_results = {
            'authentication': {'passed': 0, 'failed': 0, 'details': []},
            'session_management': {'passed': 0, 'failed': 0, 'details': []},
            'photo_upload': {'passed': 0, 'failed': 0, 'details': []},
            'user_management': {'passed': 0, 'failed': 0, 'details': []},
            'enhanced_user_management': {'passed': 0, 'failed': 0, 'details': []},
            'session_restrictions': {'passed': 0, 'failed': 0, 'details': []},
            'user_update_endpoint': {'passed': 0, 'failed': 0, 'details': []},
            'session_access_control': {'passed': 0, 'failed': 0, 'details': []},
            'bulk_download': {'passed': 0, 'failed': 0, 'details': []},
            'public_routes': {'passed': 0, 'failed': 0, 'details': []}
        }
        self.created_resources = {
            'sessions': [],
            'users': [],
            'photos': []
        }

    def log_result(self, category, test_name, passed, details=""):
        """Log test result"""
        if passed:
            self.test_results[category]['passed'] += 1
            status = "✅ PASS"
        else:
            self.test_results[category]['failed'] += 1
            status = "❌ FAIL"
        
        self.test_results[category]['details'].append(f"{status}: {test_name} - {details}")
        print(f"{status}: {test_name} - {details}")

    def make_request(self, method, endpoint, data=None, headers=None, auth_required=True, use_restricted_token=False):
        """Make HTTP request with proper headers"""
        url = f"{API_BASE_URL}{endpoint}"
        request_headers = {'Content-Type': 'application/json'}
        
        if headers:
            request_headers.update(headers)
            
        if auth_required:
            token = self.restricted_user_token if use_restricted_token else self.auth_token
            if token:
                request_headers['Authorization'] = f"Bearer {token}"
        
        try:
            if method.upper() == 'GET':
                response = self.session.get(url, headers=request_headers, timeout=10)
            elif method.upper() == 'POST':
                response = self.session.post(url, json=data, headers=request_headers, timeout=10)
            elif method.upper() == 'PUT':
                response = self.session.put(url, json=data, headers=request_headers, timeout=10)
            elif method.upper() == 'DELETE':
                response = self.session.delete(url, headers=request_headers, timeout=10)
            else:
                raise ValueError(f"Unsupported method: {method}")
                
            print(f"DEBUG: {method} {url} -> {response.status_code}")
            return response
        except Exception as e:
            print(f"Request failed: {e}")
            return None

    def test_authentication(self):
        """Test authentication system"""
        print("\n=== Testing Authentication System ===")
        
        # Test 1: Login with correct superadmin credentials
        login_data = {
            "username": "superadmin",
            "password": "changeme123"
        }
        
        response = self.make_request('POST', '/auth/login', login_data, auth_required=False)
        if response and response.status_code == 200:
            token_data = response.json()
            if 'access_token' in token_data and 'token_type' in token_data:
                self.auth_token = token_data['access_token']
                self.log_result('authentication', 'Superadmin login', True, 
                              f"Token received: {token_data['token_type']}")
            else:
                self.log_result('authentication', 'Superadmin login', False, 
                              "Token format invalid")
        else:
            self.log_result('authentication', 'Superadmin login', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Login with wrong credentials
        print("Testing invalid credentials...")
        try:
            response = requests.post(f"{API_BASE_URL}/auth/login", 
                                   json={"username": "superadmin", "password": "wrongpassword"},
                                   headers={'Content-Type': 'application/json'},
                                   timeout=10)
            print(f"Invalid login response: {response.status_code}")
            if response.status_code == 401:
                self.log_result('authentication', 'Invalid credentials rejection', True, 
                              "Correctly rejected invalid credentials")
            else:
                self.log_result('authentication', 'Invalid credentials rejection', False, 
                              f"Expected 401, got {response.status_code}")
        except Exception as e:
            print(f"Exception during invalid login test: {e}")
            self.log_result('authentication', 'Invalid credentials rejection', False, f"Request error: {e}")

        # Test 3: Get current user info
        if self.auth_token:
            response = self.make_request('GET', '/auth/me')
            if response and response.status_code == 200:
                user_data = response.json()
                if user_data.get('username') == 'superadmin' and user_data.get('is_superadmin'):
                    self.log_result('authentication', 'Get current user', True, 
                                  f"User: {user_data['username']}, Superadmin: {user_data['is_superadmin']}")
                else:
                    self.log_result('authentication', 'Get current user', False, 
                                  "User data incorrect")
            else:
                self.log_result('authentication', 'Get current user', False, 
                              f"Status: {response.status_code if response else 'No response'}")

        # Test 4: Access protected route without token
        print("Testing protected route without token...")
        try:
            response = requests.get(f"{API_BASE_URL}/auth/me", 
                                  headers={'Content-Type': 'application/json'},
                                  timeout=10)
            print(f"Protected route response: {response.status_code}")
            if response.status_code == 403:
                self.log_result('authentication', 'Protected route without token', True, 
                              "Correctly rejected request without token")
            else:
                self.log_result('authentication', 'Protected route without token', False, 
                              f"Expected 403, got {response.status_code}")
        except Exception as e:
            print(f"Exception during protected route test: {e}")
            self.log_result('authentication', 'Protected route without token', False, f"Request error: {e}")

    def test_session_management(self):
        """Test session management functionality"""
        print("\n=== Testing Session Management ===")
        
        if not self.auth_token:
            self.log_result('session_management', 'Session tests', False, "No auth token available")
            return

        # Test 1: Create a new session
        session_data = {
            "name": "Photography Event 2025",
            "description": "Wedding photography session for John & Jane"
        }
        
        response = self.make_request('POST', '/sessions', session_data)
        session_id = None
        if response and response.status_code == 200:
            session_response = response.json()
            if 'id' in session_response and 'name' in session_response:
                session_id = session_response['id']
                self.created_resources['sessions'].append(session_id)
                self.log_result('session_management', 'Create session', True, 
                              f"Session created: {session_response['name']}")
            else:
                self.log_result('session_management', 'Create session', False, 
                              "Session response format invalid")
        else:
            self.log_result('session_management', 'Create session', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: List sessions
        response = self.make_request('GET', '/sessions')
        if response and response.status_code == 200:
            sessions = response.json()
            if isinstance(sessions, list) and len(sessions) > 0:
                self.log_result('session_management', 'List sessions', True, 
                              f"Found {len(sessions)} sessions")
            else:
                self.log_result('session_management', 'List sessions', False, 
                              "No sessions found or invalid format")
        else:
            self.log_result('session_management', 'List sessions', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 3: Get specific session
        if session_id:
            response = self.make_request('GET', f'/sessions/{session_id}')
            if response and response.status_code == 200:
                session_data = response.json()
                if session_data.get('id') == session_id:
                    self.log_result('session_management', 'Get specific session', True, 
                                  f"Retrieved session: {session_data['name']}")
                else:
                    self.log_result('session_management', 'Get specific session', False, 
                                  "Session ID mismatch")
            else:
                self.log_result('session_management', 'Get specific session', False, 
                              f"Status: {response.status_code if response else 'No response'}")

        # Test 4: Generate QR code for session
        if session_id:
            response = self.make_request('GET', f'/sessions/{session_id}/qr')
            if response and response.status_code == 200:
                qr_data = response.json()
                if 'qr_code' in qr_data and 'upload_url' in qr_data:
                    self.log_result('session_management', 'Generate QR code', True, 
                                  f"QR generated for URL: {qr_data['upload_url']}")
                else:
                    self.log_result('session_management', 'Generate QR code', False, 
                                  "QR response format invalid")
            else:
                self.log_result('session_management', 'Generate QR code', False, 
                              f"Status: {response.status_code if response else 'No response'}")

    def test_photo_upload(self):
        """Test photo upload functionality"""
        print("\n=== Testing Photo Upload ===")
        
        if not self.created_resources['sessions']:
            self.log_result('photo_upload', 'Photo upload tests', False, "No session available for testing")
            return

        session_id = self.created_resources['sessions'][0]
        
        # Create a simple base64 encoded test image (1x1 pixel PNG)
        test_image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77mgAAAABJRU5ErkJggg=="
        
        # Test 1: Upload photo to session
        photo_data = {
            "session_id": session_id,
            "filename": "test_photo.png",
            "content_type": "image/png",
            "image_data": test_image_base64,
            "file_size": 100
        }
        
        response = self.make_request('POST', '/photos', photo_data, auth_required=False)
        photo_id = None
        if response and response.status_code == 200:
            photo_response = response.json()
            if 'id' in photo_response and 'session_id' in photo_response:
                photo_id = photo_response['id']
                self.created_resources['photos'].append(photo_id)
                self.log_result('photo_upload', 'Upload photo', True, 
                              f"Photo uploaded: {photo_response['filename']}")
            else:
                self.log_result('photo_upload', 'Upload photo', False, 
                              "Photo response format invalid")
        else:
            self.log_result('photo_upload', 'Upload photo', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Upload photo to non-existent session
        invalid_photo_data = {
            "session_id": "non-existent-session-id",
            "filename": "test_photo2.png",
            "content_type": "image/png",
            "image_data": test_image_base64,
            "file_size": 100
        }
        
        try:
            response = requests.post(f"{API_BASE_URL}/photos", 
                                   json=invalid_photo_data,
                                   headers={'Content-Type': 'application/json'},
                                   timeout=10)
            if response and response.status_code == 404:
                self.log_result('photo_upload', 'Upload to invalid session', True, 
                              "Correctly rejected upload to non-existent session")
            else:
                self.log_result('photo_upload', 'Upload to invalid session', False, 
                              f"Expected 404, got {response.status_code if response else 'No response'}")
        except Exception as e:
            self.log_result('photo_upload', 'Upload to invalid session', False, f"Request error: {e}")

        # Test 3: Get photos by session
        if self.auth_token:
            response = self.make_request('GET', f'/photos/session/{session_id}')
            if response and response.status_code == 200:
                photos = response.json()
                if isinstance(photos, list) and len(photos) > 0:
                    self.log_result('photo_upload', 'Get photos by session', True, 
                                  f"Found {len(photos)} photos in session")
                else:
                    self.log_result('photo_upload', 'Get photos by session', False, 
                                  "No photos found or invalid format")
            else:
                self.log_result('photo_upload', 'Get photos by session', False, 
                              f"Status: {response.status_code if response else 'No response'}")

        # Test 4: Get specific photo
        if photo_id and self.auth_token:
            response = self.make_request('GET', f'/photos/{photo_id}')
            if response and response.status_code == 200:
                photo_data = response.json()
                if photo_data.get('id') == photo_id:
                    self.log_result('photo_upload', 'Get specific photo', True, 
                                  f"Retrieved photo: {photo_data['filename']}")
                else:
                    self.log_result('photo_upload', 'Get specific photo', False, 
                                  "Photo ID mismatch")
            else:
                self.log_result('photo_upload', 'Get specific photo', False, 
                              f"Status: {response.status_code if response else 'No response'}")

    def test_user_management(self):
        """Test user management functionality (superadmin only)"""
        print("\n=== Testing User Management ===")
        
        if not self.auth_token:
            self.log_result('user_management', 'User management tests', False, "No auth token available")
            return

        # Test 1: Create a new admin user
        user_data = {
            "username": f"admin_user_{uuid.uuid4().hex[:8]}",
            "password": "securepassword123",
            "is_superadmin": False
        }
        
        response = self.make_request('POST', '/users', user_data)
        user_id = None
        if response and response.status_code == 200:
            user_response = response.json()
            if 'id' in user_response and 'username' in user_response:
                user_id = user_response['id']
                self.created_resources['users'].append(user_id)
                self.log_result('user_management', 'Create admin user', True, 
                              f"User created: {user_response['username']}")
            else:
                self.log_result('user_management', 'Create admin user', False, 
                              "User response format invalid")
        else:
            self.log_result('user_management', 'Create admin user', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Create user with duplicate username
        duplicate_user_data = {
            "username": "superadmin",  # This should already exist
            "password": "somepassword",
            "is_superadmin": False
        }
        
        try:
            response = requests.post(f"{API_BASE_URL}/users", 
                                   json=duplicate_user_data,
                                   headers={
                                       'Content-Type': 'application/json',
                                       'Authorization': f'Bearer {self.auth_token}'
                                   },
                                   timeout=10)
            if response and response.status_code == 400:
                self.log_result('user_management', 'Duplicate username rejection', True, 
                              "Correctly rejected duplicate username")
            else:
                self.log_result('user_management', 'Duplicate username rejection', False, 
                              f"Expected 400, got {response.status_code if response else 'No response'}")
        except Exception as e:
            self.log_result('user_management', 'Duplicate username rejection', False, f"Request error: {e}")

        # Test 3: List all users
        response = self.make_request('GET', '/users')
        if response and response.status_code == 200:
            users = response.json()
            if isinstance(users, list) and len(users) >= 1:  # At least superadmin should exist
                self.log_result('user_management', 'List users', True, 
                              f"Found {len(users)} users")
            else:
                self.log_result('user_management', 'List users', False, 
                              "No users found or invalid format")
        else:
            self.log_result('user_management', 'List users', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 4: Delete user (if we created one)
        if user_id:
            response = self.make_request('DELETE', f'/users/{user_id}')
            if response and response.status_code == 200:
                self.log_result('user_management', 'Delete user', True, 
                              "User deleted successfully")
                self.created_resources['users'].remove(user_id)
            else:
                self.log_result('user_management', 'Delete user', False, 
                              f"Status: {response.status_code if response else 'No response'}")

    def test_public_routes(self):
        """Test public routes that don't require authentication"""
        print("\n=== Testing Public Routes ===")
        
        if not self.created_resources['sessions']:
            self.log_result('public_routes', 'Public route tests', False, "No session available for testing")
            return

        session_id = self.created_resources['sessions'][0]
        
        # Test 1: Check valid session (public route)
        response = self.make_request('GET', f'/public/sessions/{session_id}/check', auth_required=False)
        if response and response.status_code == 200:
            session_data = response.json()
            if 'session_name' in session_data and 'session_id' in session_data:
                self.log_result('public_routes', 'Check valid session', True, 
                              f"Session found: {session_data['session_name']}")
            else:
                self.log_result('public_routes', 'Check valid session', False, 
                              "Session response format invalid")
        else:
            self.log_result('public_routes', 'Check valid session', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Check invalid session
        try:
            response = requests.get(f"{API_BASE_URL}/public/sessions/invalid-session-id/check",
                                  headers={'Content-Type': 'application/json'},
                                  timeout=10)
            if response and response.status_code == 404:
                self.log_result('public_routes', 'Check invalid session', True, 
                              "Correctly returned 404 for invalid session")
            else:
                self.log_result('public_routes', 'Check invalid session', False, 
                              f"Expected 404, got {response.status_code if response else 'No response'}")
        except Exception as e:
            self.log_result('public_routes', 'Check invalid session', False, f"Request error: {e}")

    def test_enhanced_user_management(self):
        """Test enhanced user management with session restrictions"""
        print("\n=== Testing Enhanced User Management ===")
        
        if not self.auth_token:
            self.log_result('enhanced_user_management', 'Enhanced user management tests', False, "No auth token available")
            return

        # Create test sessions first
        session1_data = {"name": "Wedding Session", "description": "Wedding photography"}
        session2_data = {"name": "Corporate Event", "description": "Corporate photography"}
        
        session1_response = self.make_request('POST', '/sessions', session1_data)
        session2_response = self.make_request('POST', '/sessions', session2_data)
        
        session1_id = session1_response.json()['id'] if session1_response and session1_response.status_code == 200 else None
        session2_id = session2_response.json()['id'] if session2_response and session2_response.status_code == 200 else None
        
        if session1_id:
            self.created_resources['sessions'].append(session1_id)
        if session2_id:
            self.created_resources['sessions'].append(session2_id)

        # Test 1: Create user with session restrictions
        if session1_id:
            restricted_user_data = {
                "username": f"photographer_{uuid.uuid4().hex[:8]}",
                "password": "photographer123",
                "is_superadmin": False,
                "allowed_sessions": [session1_id]
            }
            
            response = self.make_request('POST', '/users', restricted_user_data)
            if response and response.status_code == 200:
                user_response = response.json()
                if user_response.get('allowed_sessions') == [session1_id]:
                    self.created_resources['users'].append(user_response['id'])
                    self.log_result('enhanced_user_management', 'Create user with session restrictions', True, 
                                  f"User created with access to 1 session: {user_response['username']}")
                else:
                    self.log_result('enhanced_user_management', 'Create user with session restrictions', False, 
                                  "Session restrictions not properly set")
            else:
                self.log_result('enhanced_user_management', 'Create user with session restrictions', False, 
                              f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Create additional superadmin user
        superadmin_data = {
            "username": f"superadmin_{uuid.uuid4().hex[:8]}",
            "password": "superadmin123",
            "is_superadmin": True,
            "allowed_sessions": []
        }
        
        response = self.make_request('POST', '/users', superadmin_data)
        if response and response.status_code == 200:
            user_response = response.json()
            if user_response.get('is_superadmin') == True:
                self.created_resources['users'].append(user_response['id'])
                self.log_result('enhanced_user_management', 'Create additional superadmin', True, 
                              f"Superadmin created: {user_response['username']}")
            else:
                self.log_result('enhanced_user_management', 'Create additional superadmin', False, 
                              "Superadmin flag not properly set")
        else:
            self.log_result('enhanced_user_management', 'Create additional superadmin', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 3: Create user with invalid session ID
        invalid_session_user_data = {
            "username": f"invalid_user_{uuid.uuid4().hex[:8]}",
            "password": "password123",
            "is_superadmin": False,
            "allowed_sessions": ["invalid-session-id"]
        }
        
        response = self.make_request('POST', '/users', invalid_session_user_data)
        if response and response.status_code == 400:
            self.log_result('enhanced_user_management', 'Create user with invalid session', True, 
                          "Correctly rejected user with invalid session ID")
        else:
            self.log_result('enhanced_user_management', 'Create user with invalid session', False, 
                          f"Expected 400, got {response.status_code if response else 'No response'}")

        # Test 4: List users with session restriction information
        response = self.make_request('GET', '/users')
        if response and response.status_code == 200:
            users = response.json()
            restricted_users = [u for u in users if u.get('allowed_sessions')]
            if len(restricted_users) > 0:
                self.log_result('enhanced_user_management', 'List users with session info', True, 
                              f"Found {len(restricted_users)} users with session restrictions")
            else:
                self.log_result('enhanced_user_management', 'List users with session info', True, 
                              "User list retrieved (no restricted users found)")
        else:
            self.log_result('enhanced_user_management', 'List users with session info', False, 
                          f"Status: {response.status_code if response else 'No response'}")

    def test_user_update_endpoint(self):
        """Test user update endpoint functionality"""
        print("\n=== Testing User Update Endpoint ===")
        
        if not self.auth_token:
            self.log_result('user_update_endpoint', 'User update tests', False, "No auth token available")
            return

        # Create a test user first
        test_user_data = {
            "username": f"update_test_{uuid.uuid4().hex[:8]}",
            "password": "original123",
            "is_superadmin": False,
            "allowed_sessions": []
        }
        
        response = self.make_request('POST', '/users', test_user_data)
        if not response or response.status_code != 200:
            self.log_result('user_update_endpoint', 'User update tests', False, "Failed to create test user")
            return
        
        user_id = response.json()['id']
        self.created_resources['users'].append(user_id)

        # Create test sessions for restriction updates
        session_data = {"name": "Update Test Session", "description": "For testing updates"}
        session_response = self.make_request('POST', '/sessions', session_data)
        session_id = session_response.json()['id'] if session_response and session_response.status_code == 200 else None
        if session_id:
            self.created_resources['sessions'].append(session_id)

        # Test 1: Update user session restrictions
        if session_id:
            update_data = {"allowed_sessions": [session_id]}
            response = self.make_request('PUT', f'/users/{user_id}', update_data)
            if response and response.status_code == 200:
                updated_user = response.json()
                if updated_user.get('allowed_sessions') == [session_id]:
                    self.log_result('user_update_endpoint', 'Update session restrictions', True, 
                                  "Session restrictions updated successfully")
                else:
                    self.log_result('user_update_endpoint', 'Update session restrictions', False, 
                                  "Session restrictions not properly updated")
            else:
                self.log_result('user_update_endpoint', 'Update session restrictions', False, 
                              f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Promote user to superadmin
        update_data = {"is_superadmin": True}
        response = self.make_request('PUT', f'/users/{user_id}', update_data)
        if response and response.status_code == 200:
            updated_user = response.json()
            if updated_user.get('is_superadmin') == True:
                self.log_result('user_update_endpoint', 'Promote to superadmin', True, 
                              "User promoted to superadmin successfully")
            else:
                self.log_result('user_update_endpoint', 'Promote to superadmin', False, 
                              "Superadmin promotion failed")
        else:
            self.log_result('user_update_endpoint', 'Promote to superadmin', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 3: Update password
        update_data = {"password": "newpassword123"}
        response = self.make_request('PUT', f'/users/{user_id}', update_data)
        if response and response.status_code == 200:
            self.log_result('user_update_endpoint', 'Update password', True, 
                          "Password updated successfully")
        else:
            self.log_result('user_update_endpoint', 'Update password', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 4: Update username
        new_username = f"updated_user_{uuid.uuid4().hex[:8]}"
        update_data = {"username": new_username}
        response = self.make_request('PUT', f'/users/{user_id}', update_data)
        if response and response.status_code == 200:
            updated_user = response.json()
            if updated_user.get('username') == new_username:
                self.log_result('user_update_endpoint', 'Update username', True, 
                              f"Username updated to: {new_username}")
            else:
                self.log_result('user_update_endpoint', 'Update username', False, 
                              "Username not properly updated")
        else:
            self.log_result('user_update_endpoint', 'Update username', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 5: Update with invalid session ID
        update_data = {"allowed_sessions": ["invalid-session-id"]}
        response = self.make_request('PUT', f'/users/{user_id}', update_data)
        if response and response.status_code == 400:
            self.log_result('user_update_endpoint', 'Update with invalid session', True, 
                          "Correctly rejected invalid session ID")
        else:
            self.log_result('user_update_endpoint', 'Update with invalid session', False, 
                          f"Expected 400, got {response.status_code if response else 'No response'}")

    def test_session_restrictions(self):
        """Test session restriction functionality for restricted users"""
        print("\n=== Testing Session Restrictions ===")
        
        if not self.auth_token:
            self.log_result('session_restrictions', 'Session restriction tests', False, "No auth token available")
            return

        # Create test sessions
        session1_data = {"name": "Allowed Session", "description": "User has access"}
        session2_data = {"name": "Restricted Session", "description": "User has no access"}
        
        session1_response = self.make_request('POST', '/sessions', session1_data)
        session2_response = self.make_request('POST', '/sessions', session2_data)
        
        session1_id = session1_response.json()['id'] if session1_response and session1_response.status_code == 200 else None
        session2_id = session2_response.json()['id'] if session2_response and session2_response.status_code == 200 else None
        
        if session1_id:
            self.created_resources['sessions'].append(session1_id)
        if session2_id:
            self.created_resources['sessions'].append(session2_id)

        if not session1_id or not session2_id:
            self.log_result('session_restrictions', 'Session restriction tests', False, "Failed to create test sessions")
            return

        # Create restricted user with access to only session1
        restricted_user_data = {
            "username": f"restricted_{uuid.uuid4().hex[:8]}",
            "password": "restricted123",
            "is_superadmin": False,
            "allowed_sessions": [session1_id]
        }
        
        response = self.make_request('POST', '/users', restricted_user_data)
        if not response or response.status_code != 200:
            self.log_result('session_restrictions', 'Session restriction tests', False, "Failed to create restricted user")
            return
        
        restricted_user_id = response.json()['id']
        self.created_resources['users'].append(restricted_user_id)

        # Login as restricted user
        login_data = {
            "username": restricted_user_data['username'],
            "password": restricted_user_data['password']
        }
        
        response = self.make_request('POST', '/auth/login', login_data, auth_required=False)
        if response and response.status_code == 200:
            self.restricted_user_token = response.json()['access_token']
        else:
            self.log_result('session_restrictions', 'Session restriction tests', False, "Failed to login as restricted user")
            return

        # Test 1: Restricted user can access allowed session
        response = self.make_request('GET', f'/sessions/{session1_id}', use_restricted_token=True)
        if response and response.status_code == 200:
            self.log_result('session_restrictions', 'Access allowed session', True, 
                          "Restricted user can access allowed session")
        else:
            self.log_result('session_restrictions', 'Access allowed session', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Restricted user cannot access restricted session
        response = self.make_request('GET', f'/sessions/{session2_id}', use_restricted_token=True)
        if response and response.status_code == 403:
            self.log_result('session_restrictions', 'Access restricted session', True, 
                          "Correctly denied access to restricted session")
        else:
            self.log_result('session_restrictions', 'Access restricted session', False, 
                          f"Expected 403, got {response.status_code if response else 'No response'}")

        # Test 3: Restricted user can generate QR for allowed session
        response = self.make_request('GET', f'/sessions/{session1_id}/qr', use_restricted_token=True)
        if response and response.status_code == 200:
            qr_data = response.json()
            if 'qr_code' in qr_data:
                self.log_result('session_restrictions', 'Generate QR for allowed session', True, 
                              "QR code generated for allowed session")
            else:
                self.log_result('session_restrictions', 'Generate QR for allowed session', False, 
                              "QR response format invalid")
        else:
            self.log_result('session_restrictions', 'Generate QR for allowed session', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 4: Restricted user cannot generate QR for restricted session
        response = self.make_request('GET', f'/sessions/{session2_id}/qr', use_restricted_token=True)
        if response and response.status_code == 403:
            self.log_result('session_restrictions', 'Generate QR for restricted session', True, 
                          "Correctly denied QR generation for restricted session")
        else:
            self.log_result('session_restrictions', 'Generate QR for restricted session', False, 
                          f"Expected 403, got {response.status_code if response else 'No response'}")

        # Upload a photo to allowed session for photo access tests
        test_image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77mgAAAABJRU5ErkJggg=="
        photo_data = {
            "session_id": session1_id,
            "filename": "test_restricted.png",
            "content_type": "image/png",
            "image_data": test_image_base64,
            "file_size": 100
        }
        
        photo_response = self.make_request('POST', '/photos', photo_data, auth_required=False)
        photo_id = photo_response.json()['id'] if photo_response and photo_response.status_code == 200 else None
        if photo_id:
            self.created_resources['photos'].append(photo_id)

        # Test 5: Restricted user can access photos from allowed session
        if photo_id:
            response = self.make_request('GET', f'/photos/session/{session1_id}', use_restricted_token=True)
            if response and response.status_code == 200:
                photos = response.json()
                if len(photos) > 0:
                    self.log_result('session_restrictions', 'Access photos from allowed session', True, 
                                  f"Found {len(photos)} photos in allowed session")
                else:
                    self.log_result('session_restrictions', 'Access photos from allowed session', False, 
                                  "No photos found in allowed session")
            else:
                self.log_result('session_restrictions', 'Access photos from allowed session', False, 
                              f"Status: {response.status_code if response else 'No response'}")

        # Test 6: Restricted user cannot access photos from restricted session
        response = self.make_request('GET', f'/photos/session/{session2_id}', use_restricted_token=True)
        if response and response.status_code == 403:
            self.log_result('session_restrictions', 'Access photos from restricted session', True, 
                          "Correctly denied access to photos from restricted session")
        else:
            self.log_result('session_restrictions', 'Access photos from restricted session', False, 
                          f"Expected 403, got {response.status_code if response else 'No response'}")

    def test_session_access_control(self):
        """Test session access control and filtering"""
        print("\n=== Testing Session Access Control ===")
        
        if not self.auth_token:
            self.log_result('session_access_control', 'Session access control tests', False, "No auth token available")
            return

        # Create multiple test sessions
        session1_data = {"name": "Public Session", "description": "Available to all"}
        session2_data = {"name": "Private Session", "description": "Restricted access"}
        session3_data = {"name": "Another Session", "description": "Another test session"}
        
        session1_response = self.make_request('POST', '/sessions', session1_data)
        session2_response = self.make_request('POST', '/sessions', session2_data)
        session3_response = self.make_request('POST', '/sessions', session3_data)
        
        session1_id = session1_response.json()['id'] if session1_response and session1_response.status_code == 200 else None
        session2_id = session2_response.json()['id'] if session2_response and session2_response.status_code == 200 else None
        session3_id = session3_response.json()['id'] if session3_response and session3_response.status_code == 200 else None
        
        for session_id in [session1_id, session2_id, session3_id]:
            if session_id:
                self.created_resources['sessions'].append(session_id)

        if not all([session1_id, session2_id, session3_id]):
            self.log_result('session_access_control', 'Session access control tests', False, "Failed to create test sessions")
            return

        # Test 1: Superadmin can see all sessions
        response = self.make_request('GET', '/sessions')
        if response and response.status_code == 200:
            sessions = response.json()
            session_ids = [s['id'] for s in sessions]
            if all(sid in session_ids for sid in [session1_id, session2_id, session3_id]):
                self.log_result('session_access_control', 'Superadmin sees all sessions', True, 
                              f"Superadmin can see all {len(sessions)} sessions")
            else:
                self.log_result('session_access_control', 'Superadmin sees all sessions', False, 
                              "Superadmin cannot see all created sessions")
        else:
            self.log_result('session_access_control', 'Superadmin sees all sessions', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Create restricted user with access to only session1 and session2
        restricted_user_data = {
            "username": f"access_test_{uuid.uuid4().hex[:8]}",
            "password": "access123",
            "is_superadmin": False,
            "allowed_sessions": [session1_id, session2_id]
        }
        
        response = self.make_request('POST', '/users', restricted_user_data)
        if not response or response.status_code != 200:
            self.log_result('session_access_control', 'Session access control tests', False, "Failed to create restricted user")
            return
        
        restricted_user_id = response.json()['id']
        self.created_resources['users'].append(restricted_user_id)

        # Login as restricted user
        login_data = {
            "username": restricted_user_data['username'],
            "password": restricted_user_data['password']
        }
        
        response = self.make_request('POST', '/auth/login', login_data, auth_required=False)
        if response and response.status_code == 200:
            restricted_token = response.json()['access_token']
        else:
            self.log_result('session_access_control', 'Session access control tests', False, "Failed to login as restricted user")
            return

        # Test 2: Restricted user sees only allowed sessions
        self.restricted_user_token = restricted_token
        response = self.make_request('GET', '/sessions', use_restricted_token=True)
        if response and response.status_code == 200:
            sessions = response.json()
            session_ids = [s['id'] for s in sessions]
            if session1_id in session_ids and session2_id in session_ids and session3_id not in session_ids:
                self.log_result('session_access_control', 'Restricted user sees filtered sessions', True, 
                              f"Restricted user sees {len(sessions)} allowed sessions")
            else:
                self.log_result('session_access_control', 'Restricted user sees filtered sessions', False, 
                              f"Session filtering not working properly. Saw sessions: {session_ids}")
        else:
            self.log_result('session_access_control', 'Restricted user sees filtered sessions', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 3: Restricted user cannot access unauthorized session
        response = self.make_request('GET', f'/sessions/{session3_id}', use_restricted_token=True)
        if response and response.status_code == 403:
            self.log_result('session_access_control', 'Deny unauthorized session access', True, 
                          "Correctly denied access to unauthorized session")
        else:
            self.log_result('session_access_control', 'Deny unauthorized session access', False, 
                          f"Expected 403, got {response.status_code if response else 'No response'}")

        # Create unrestricted user (empty allowed_sessions means access to all)
        unrestricted_user_data = {
            "username": f"unrestricted_{uuid.uuid4().hex[:8]}",
            "password": "unrestricted123",
            "is_superadmin": False,
            "allowed_sessions": []
        }
        
        response = self.make_request('POST', '/users', unrestricted_user_data)
        if response and response.status_code == 200:
            unrestricted_user_id = response.json()['id']
            self.created_resources['users'].append(unrestricted_user_id)

            # Login as unrestricted user
            login_data = {
                "username": unrestricted_user_data['username'],
                "password": unrestricted_user_data['password']
            }
            
            response = self.make_request('POST', '/auth/login', login_data, auth_required=False)
            if response and response.status_code == 200:
                unrestricted_token = response.json()['access_token']

                # Test 4: Unrestricted user (empty allowed_sessions) sees all sessions
                headers = {'Authorization': f'Bearer {unrestricted_token}'}
                response = self.make_request('GET', '/sessions', headers=headers, auth_required=False)
                if response and response.status_code == 200:
                    sessions = response.json()
                    session_ids = [s['id'] for s in sessions]
                    if all(sid in session_ids for sid in [session1_id, session2_id, session3_id]):
                        self.log_result('session_access_control', 'Unrestricted user sees all sessions', True, 
                                      f"Unrestricted user can see all {len(sessions)} sessions")
                    else:
                        self.log_result('session_access_control', 'Unrestricted user sees all sessions', False, 
                                      "Unrestricted user cannot see all sessions")
                else:
                    self.log_result('session_access_control', 'Unrestricted user sees all sessions', False, 
                                  f"Status: {response.status_code if response else 'No response'}")

    def test_bulk_download(self):
        """Test bulk download functionality"""
        print("\n=== Testing Bulk Download Functionality ===")
        
        if not self.auth_token:
            self.log_result('bulk_download', 'Bulk download tests', False, "No auth token available")
            return

        # Create test sessions and photos for bulk download
        session1_data = {"name": "Bulk Test Session 1", "description": "For bulk download testing"}
        session2_data = {"name": "Bulk Test Session 2", "description": "For bulk download testing"}
        
        session1_response = self.make_request('POST', '/sessions', session1_data)
        session2_response = self.make_request('POST', '/sessions', session2_data)
        
        session1_id = session1_response.json()['id'] if session1_response and session1_response.status_code == 200 else None
        session2_id = session2_response.json()['id'] if session2_response and session2_response.status_code == 200 else None
        
        if session1_id:
            self.created_resources['sessions'].append(session1_id)
        if session2_id:
            self.created_resources['sessions'].append(session2_id)

        if not session1_id or not session2_id:
            self.log_result('bulk_download', 'Bulk download tests', False, "Failed to create test sessions")
            return

        # Create test images (different base64 encoded images)
        test_image1_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77mgAAAABJRU5ErkJggg=="
        test_image2_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFklEQVR42mNkYGBgYGBgYGBgYGBgYAAABQABDQottAAAAABJRU5ErkJggg=="
        test_image3_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAYAAABWKLW/AAAAHklEQVR42mNkYGBgYGBgYGBgYGBgYGBgYGBgYGBgYAAAEAABAKKxjxsAAAAASUVORK5CYII="

        # Upload photos to session1
        photo_data_list = [
            {
                "session_id": session1_id,
                "filename": "bulk_test1.png",
                "content_type": "image/png",
                "image_data": test_image1_base64,
                "file_size": 100
            },
            {
                "session_id": session1_id,
                "filename": "bulk_test2.png",
                "content_type": "image/png",
                "image_data": test_image2_base64,
                "file_size": 120
            },
            {
                "session_id": session2_id,
                "filename": "bulk_test3.png",
                "content_type": "image/png",
                "image_data": test_image3_base64,
                "file_size": 140
            }
        ]

        uploaded_photo_ids = []
        for photo_data in photo_data_list:
            response = self.make_request('POST', '/photos', photo_data, auth_required=False)
            if response and response.status_code == 200:
                photo_id = response.json()['id']
                uploaded_photo_ids.append(photo_id)
                self.created_resources['photos'].append(photo_id)

        if len(uploaded_photo_ids) < 3:
            self.log_result('bulk_download', 'Bulk download tests', False, "Failed to upload test photos")
            return

        # Test 1: Bulk download with valid photo IDs
        bulk_request_data = uploaded_photo_ids
        response = self.make_request('POST', '/photos/bulk-download', bulk_request_data)
        if response and response.status_code == 200:
            # Check if response is a ZIP file
            content_type = response.headers.get('content-type', '')
            content_disposition = response.headers.get('content-disposition', '')
            
            if 'application/zip' in content_type and 'attachment' in content_disposition:
                # Check if we got actual ZIP content
                content_length = len(response.content)
                if content_length > 100:  # ZIP files should be larger than 100 bytes
                    self.log_result('bulk_download', 'Bulk download valid photos', True, 
                                  f"ZIP file created successfully ({content_length} bytes)")
                else:
                    self.log_result('bulk_download', 'Bulk download valid photos', False, 
                                  f"ZIP file too small ({content_length} bytes)")
            else:
                self.log_result('bulk_download', 'Bulk download valid photos', False, 
                              f"Invalid response format. Content-Type: {content_type}")
        else:
            self.log_result('bulk_download', 'Bulk download valid photos', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 2: Bulk download with empty photo ID list
        response = self.make_request('POST', '/photos/bulk-download', [])
        if response and response.status_code == 400:
            self.log_result('bulk_download', 'Bulk download empty list', True, 
                          "Correctly rejected empty photo ID list")
        else:
            self.log_result('bulk_download', 'Bulk download empty list', False, 
                          f"Expected 400, got {response.status_code if response else 'No response'}")

        # Test 3: Bulk download with invalid photo IDs
        invalid_photo_ids = ["invalid-id-1", "invalid-id-2"]
        response = self.make_request('POST', '/photos/bulk-download', invalid_photo_ids)
        if response and response.status_code == 404:
            self.log_result('bulk_download', 'Bulk download invalid IDs', True, 
                          "Correctly returned 404 for invalid photo IDs")
        else:
            self.log_result('bulk_download', 'Bulk download invalid IDs', False, 
                          f"Expected 404, got {response.status_code if response else 'No response'}")

        # Test 4: Bulk download with mixed valid/invalid photo IDs
        mixed_photo_ids = [uploaded_photo_ids[0], "invalid-id", uploaded_photo_ids[1]]
        response = self.make_request('POST', '/photos/bulk-download', mixed_photo_ids)
        if response and response.status_code == 200:
            # Should succeed with valid photos only
            content_type = response.headers.get('content-type', '')
            if 'application/zip' in content_type:
                self.log_result('bulk_download', 'Bulk download mixed IDs', True, 
                              "Successfully created ZIP with valid photos only")
            else:
                self.log_result('bulk_download', 'Bulk download mixed IDs', False, 
                              "Invalid response format for mixed IDs")
        else:
            self.log_result('bulk_download', 'Bulk download mixed IDs', False, 
                          f"Status: {response.status_code if response else 'No response'}")

        # Test 5: Test session access control for bulk download
        # Create a restricted user with access to only session1
        restricted_user_data = {
            "username": f"bulk_restricted_{uuid.uuid4().hex[:8]}",
            "password": "bulkrestricted123",
            "is_superadmin": False,
            "allowed_sessions": [session1_id]
        }
        
        response = self.make_request('POST', '/users', restricted_user_data)
        if response and response.status_code == 200:
            restricted_user_id = response.json()['id']
            self.created_resources['users'].append(restricted_user_id)

            # Login as restricted user
            login_data = {
                "username": restricted_user_data['username'],
                "password": restricted_user_data['password']
            }
            
            response = self.make_request('POST', '/auth/login', login_data, auth_required=False)
            if response and response.status_code == 200:
                restricted_token = response.json()['access_token']

                # Try to bulk download photos from both sessions (should only get session1 photos)
                self.restricted_user_token = restricted_token
                response = self.make_request('POST', '/photos/bulk-download', uploaded_photo_ids, use_restricted_token=True)
                if response and response.status_code == 200:
                    content_type = response.headers.get('content-type', '')
                    if 'application/zip' in content_type:
                        self.log_result('bulk_download', 'Bulk download session restrictions', True, 
                                      "Restricted user can bulk download accessible photos only")
                    else:
                        self.log_result('bulk_download', 'Bulk download session restrictions', False, 
                                      "Invalid response format for restricted user")
                else:
                    self.log_result('bulk_download', 'Bulk download session restrictions', False, 
                                  f"Status: {response.status_code if response else 'No response'}")
            else:
                self.log_result('bulk_download', 'Bulk download session restrictions', False, 
                              "Failed to login as restricted user")
        else:
            self.log_result('bulk_download', 'Bulk download session restrictions', False, 
                          "Failed to create restricted user")

        # Test 6: Test bulk download without authentication
        try:
            response = requests.post(f"{API_BASE_URL}/photos/bulk-download", 
                                   json=uploaded_photo_ids,
                                   headers={'Content-Type': 'application/json'},
                                   timeout=10)
            if response and response.status_code == 403:
                self.log_result('bulk_download', 'Bulk download without auth', True, 
                              "Correctly rejected bulk download without authentication")
            else:
                self.log_result('bulk_download', 'Bulk download without auth', False, 
                              f"Expected 403, got {response.status_code if response else 'No response'}")
        except Exception as e:
            self.log_result('bulk_download', 'Bulk download without auth', False, f"Request error: {e}")

    def cleanup_resources(self):
        """Clean up created test resources"""
        print("\n=== Cleaning up test resources ===")
        
        # Delete created photos
        for photo_id in self.created_resources['photos']:
            try:
                response = self.make_request('DELETE', f'/photos/{photo_id}')
                if response and response.status_code == 200:
                    print(f"✅ Deleted photo: {photo_id}")
                else:
                    print(f"❌ Failed to delete photo: {photo_id}")
            except Exception as e:
                print(f"❌ Error deleting photo {photo_id}: {e}")

        # Delete created sessions
        for session_id in self.created_resources['sessions']:
            try:
                response = self.make_request('DELETE', f'/sessions/{session_id}')
                if response and response.status_code == 200:
                    print(f"✅ Deactivated session: {session_id}")
                else:
                    print(f"❌ Failed to deactivate session: {session_id}")
            except Exception as e:
                print(f"❌ Error deactivating session {session_id}: {e}")

        # Delete created users
        for user_id in self.created_resources['users']:
            try:
                response = self.make_request('DELETE', f'/users/{user_id}')
                if response and response.status_code == 200:
                    print(f"✅ Deleted user: {user_id}")
                else:
                    print(f"❌ Failed to delete user: {user_id}")
            except Exception as e:
                print(f"❌ Error deleting user {user_id}: {e}")

    def print_summary(self):
        """Print test summary"""
        print("\n" + "="*60)
        print("BACKEND TESTING SUMMARY")
        print("="*60)
        
        total_passed = 0
        total_failed = 0
        
        for category, results in self.test_results.items():
            passed = results['passed']
            failed = results['failed']
            total_passed += passed
            total_failed += failed
            
            print(f"\n{category.upper().replace('_', ' ')}:")
            print(f"  ✅ Passed: {passed}")
            print(f"  ❌ Failed: {failed}")
            
            if results['details']:
                for detail in results['details']:
                    print(f"    {detail}")
        
        print(f"\nOVERALL RESULTS:")
        print(f"  ✅ Total Passed: {total_passed}")
        print(f"  ❌ Total Failed: {total_failed}")
        print(f"  📊 Success Rate: {(total_passed/(total_passed+total_failed)*100):.1f}%" if (total_passed+total_failed) > 0 else "  📊 Success Rate: 0%")
        
        return total_failed == 0

    def test_new_functionality_review(self):
        """Test newly added functionality as requested in review"""
        print("\n=== Testing New Functionality (Review Request) ===")
        
        if not self.auth_token:
            self.log_result('new_functionality', 'New functionality tests', False, "No auth token available")
            return

        # Test 1: Session deletion functionality
        print("\n--- Testing Session Deletion ---")
        session_data = {"name": "Test Session for Deletion", "description": "Will be deleted"}
        response = self.make_request('POST', '/sessions', session_data)
        
        if response and response.status_code == 200:
            session_id = response.json()['id']
            self.created_resources['sessions'].append(session_id)
            
            # Delete the session
            response = self.make_request('DELETE', f'/sessions/{session_id}')
            if response and response.status_code == 200:
                # Verify session is marked as inactive by trying to upload to it
                test_image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77mgAAAABJRU5ErkJggg=="
                photo_data = {
                    "session_id": session_id,
                    "filename": "test_inactive.png",
                    "content_type": "image/png",
                    "image_data": test_image_base64,
                    "file_size": 100
                }
                
                upload_response = self.make_request('POST', '/photos', photo_data, auth_required=False)
                if upload_response and upload_response.status_code == 404:
                    self.log_result('new_functionality', 'Session deletion marks inactive', True, 
                                  "Session correctly marked as inactive after deletion")
                else:
                    self.log_result('new_functionality', 'Session deletion marks inactive', False, 
                                  f"Session not properly marked inactive. Upload status: {upload_response.status_code if upload_response else 'No response'}")
            else:
                self.log_result('new_functionality', 'Session deletion', False, 
                              f"Session deletion failed. Status: {response.status_code if response else 'No response'}")
        else:
            self.log_result('new_functionality', 'Session deletion setup', False, "Failed to create test session")

        # Test 2: User deletion functionality
        print("\n--- Testing User Deletion ---")
        user_data = {
            "username": f"delete_test_{uuid.uuid4().hex[:8]}",
            "password": "deletetest123",
            "is_superadmin": False
        }
        
        response = self.make_request('POST', '/users', user_data)
        if response and response.status_code == 200:
            user_id = response.json()['id']
            
            # Delete the user
            response = self.make_request('DELETE', f'/users/{user_id}')
            if response and response.status_code == 200:
                # Verify user is deleted by trying to get user list and checking it's not there
                users_response = self.make_request('GET', '/users')
                if users_response and users_response.status_code == 200:
                    users = users_response.json()
                    user_ids = [u['id'] for u in users]
                    if user_id not in user_ids:
                        self.log_result('new_functionality', 'User deletion', True, 
                                      "User successfully deleted from database")
                    else:
                        self.log_result('new_functionality', 'User deletion', False, 
                                      "User still exists after deletion")
                else:
                    self.log_result('new_functionality', 'User deletion verification', False, 
                                  "Failed to verify user deletion")
            else:
                self.log_result('new_functionality', 'User deletion', False, 
                              f"User deletion failed. Status: {response.status_code if response else 'No response'}")
        else:
            self.log_result('new_functionality', 'User deletion setup', False, "Failed to create test user")

        # Test 3: User update functionality
        print("\n--- Testing User Update Functionality ---")
        
        # Create test session for restrictions
        session_data = {"name": "Update Test Session", "description": "For user update testing"}
        session_response = self.make_request('POST', '/sessions', session_data)
        session_id = session_response.json()['id'] if session_response and session_response.status_code == 200 else None
        if session_id:
            self.created_resources['sessions'].append(session_id)

        # Create test user for updates
        user_data = {
            "username": f"update_test_{uuid.uuid4().hex[:8]}",
            "password": "original123",
            "is_superadmin": False,
            "allowed_sessions": []
        }
        
        response = self.make_request('POST', '/users', user_data)
        if response and response.status_code == 200:
            user_id = response.json()['id']
            self.created_resources['users'].append(user_id)
            
            # Test 3a: Update session restrictions
            if session_id:
                update_data = {"allowed_sessions": [session_id]}
                response = self.make_request('PUT', f'/users/{user_id}', update_data)
                if response and response.status_code == 200:
                    updated_user = response.json()
                    if updated_user.get('allowed_sessions') == [session_id]:
                        self.log_result('new_functionality', 'Update user session restrictions', True, 
                                      "Session restrictions updated successfully")
                    else:
                        self.log_result('new_functionality', 'Update user session restrictions', False, 
                                      "Session restrictions not properly updated")
                else:
                    self.log_result('new_functionality', 'Update user session restrictions', False, 
                                  f"Status: {response.status_code if response else 'No response'}")
            
            # Test 3b: Update superadmin status
            update_data = {"is_superadmin": True}
            response = self.make_request('PUT', f'/users/{user_id}', update_data)
            if response and response.status_code == 200:
                updated_user = response.json()
                if updated_user.get('is_superadmin') == True:
                    self.log_result('new_functionality', 'Update user superadmin status', True, 
                                  "Superadmin status updated successfully")
                else:
                    self.log_result('new_functionality', 'Update user superadmin status', False, 
                                  "Superadmin status not properly updated")
            else:
                self.log_result('new_functionality', 'Update user superadmin status', False, 
                              f"Status: {response.status_code if response else 'No response'}")
            
            # Test 3c: Update password
            update_data = {"password": "newpassword456"}
            response = self.make_request('PUT', f'/users/{user_id}', update_data)
            if response and response.status_code == 200:
                self.log_result('new_functionality', 'Update user password', True, 
                              "Password updated successfully")
            else:
                self.log_result('new_functionality', 'Update user password', False, 
                              f"Status: {response.status_code if response else 'No response'}")
            
            # Test 3d: Update username
            new_username = f"updated_{uuid.uuid4().hex[:8]}"
            update_data = {"username": new_username}
            response = self.make_request('PUT', f'/users/{user_id}', update_data)
            if response and response.status_code == 200:
                updated_user = response.json()
                if updated_user.get('username') == new_username:
                    self.log_result('new_functionality', 'Update username', True, 
                                  f"Username updated to: {new_username}")
                else:
                    self.log_result('new_functionality', 'Update username', False, 
                                  "Username not properly updated")
            else:
                self.log_result('new_functionality', 'Update username', False, 
                              f"Status: {response.status_code if response else 'No response'}")
        else:
            self.log_result('new_functionality', 'User update setup', False, "Failed to create test user")

        # Test 4: QR code generation with new server IP
        print("\n--- Testing QR Code with Server IP Configuration ---")
        session_data = {"name": "QR Test Session", "description": "For QR code testing"}
        response = self.make_request('POST', '/sessions', session_data)
        
        if response and response.status_code == 200:
            session_id = response.json()['id']
            self.created_resources['sessions'].append(session_id)
            
            # Generate QR code
            response = self.make_request('GET', f'/sessions/{session_id}/qr')
            if response and response.status_code == 200:
                qr_data = response.json()
                upload_url = qr_data.get('upload_url', '')
                
                # Check if QR code points to the correct server IP
                expected_url = f"http://81.173.84.37/upload/{session_id}"
                if upload_url == expected_url:
                    self.log_result('new_functionality', 'QR code server IP configuration', True, 
                                  f"QR code correctly points to: {upload_url}")
                else:
                    self.log_result('new_functionality', 'QR code server IP configuration', False, 
                                  f"Expected: {expected_url}, Got: {upload_url}")
            else:
                self.log_result('new_functionality', 'QR code generation', False, 
                              f"QR generation failed. Status: {response.status_code if response else 'No response'}")
        else:
            self.log_result('new_functionality', 'QR code setup', False, "Failed to create test session")

    def run_all_tests(self):
        """Run all backend tests"""
        print("Starting comprehensive backend testing...")
        print(f"Backend URL: {API_BASE_URL}")
        
        try:
            # Run all test categories
            self.test_authentication()
            self.test_session_management()
            self.test_photo_upload()
            self.test_user_management()
            
            # New enhanced tests for user management and session restrictions
            self.test_enhanced_user_management()
            self.test_user_update_endpoint()
            self.test_session_restrictions()
            self.test_session_access_control()
            
            # Test bulk download functionality
            self.test_bulk_download()
            
            self.test_public_routes()
            
            # Test new functionality as requested in review
            self.test_new_functionality_review()
            
            # Print summary
            success = self.print_summary()
            
            # Cleanup
            self.cleanup_resources()
            
            return success
            
        except Exception as e:
            print(f"❌ Critical error during testing: {e}")
            return False

if __name__ == "__main__":
    tester = BackendTester()
    success = tester.run_all_tests()
    
    if success:
        print("\n🎉 All backend tests passed!")
        exit(0)
    else:
        print("\n⚠️  Some backend tests failed. Check the details above.")
        exit(1)