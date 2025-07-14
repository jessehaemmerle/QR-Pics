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

    def make_request(self, method, endpoint, data=None, headers=None, auth_required=True):
        """Make HTTP request with proper headers"""
        url = f"{API_BASE_URL}{endpoint}"
        request_headers = {'Content-Type': 'application/json'}
        
        if headers:
            request_headers.update(headers)
            
        if auth_required and self.auth_token:
            request_headers['Authorization'] = f"Bearer {self.auth_token}"
        
        try:
            if method.upper() == 'GET':
                response = self.session.get(url, headers=request_headers, timeout=10)
            elif method.upper() == 'POST':
                response = self.session.post(url, json=data, headers=request_headers, timeout=10)
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
            self.test_public_routes()
            
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