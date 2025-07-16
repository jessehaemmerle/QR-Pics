#!/bin/bash

echo "🔍 QR Photo Upload - Deep Authentication Debug"
echo "============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Deep Debugging Authentication System${NC}"
echo "======================================="

# Test if we can reach the backend
echo ""
echo -e "${YELLOW}Step 1: Testing Backend Connectivity${NC}"
echo "==================================="
if curl -f http://81.173.84.37:8001/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is reachable${NC}"
    backend_response=$(curl -s http://81.173.84.37:8001/api/)
    echo "Response: $backend_response"
else
    echo -e "${RED}❌ Backend is not reachable${NC}"
    exit 1
fi

# Check what's actually in the database
echo ""
echo -e "${YELLOW}Step 2: Examining Database Contents${NC}"
echo "=================================="
echo "Database contents:"
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
print('=== Collections ===');
db.getCollectionNames().forEach(function(name) {
    print(name + ': ' + db[name].countDocuments() + ' documents');
});

print('\\n=== Users Collection ===');
db.users.find().forEach(function(user) {
    print('ID: ' + user.id);
    print('Username: ' + user.username);
    print('Password Hash: ' + user.password_hash);
    print('Is Superadmin: ' + user.is_superadmin);
    print('Created By: ' + user.created_by);
    print('---');
});
"

# Test the login endpoint with detailed response
echo ""
echo -e "${YELLOW}Step 3: Testing Login Endpoint${NC}"
echo "==============================="
echo "Testing login with full response..."

login_response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}\n" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login)

echo "Full login response:"
echo "$login_response"

# Check backend logs for authentication errors
echo ""
echo -e "${YELLOW}Step 4: Checking Backend Logs${NC}"
echo "============================="
echo "Recent backend logs (last 30 lines):"
docker logs --tail=30 qr-photo-backend

echo ""
echo "Looking for authentication-related errors:"
docker logs qr-photo-backend 2>&1 | grep -i -E "(auth|login|password|credential|superadmin)" | tail -10

# Test password hashing manually
echo ""
echo -e "${YELLOW}Step 5: Manual Password Hash Test${NC}"
echo "==============================="
echo "Testing password hashing inside backend container..."

# Create a test script inside the backend container
docker exec qr-photo-backend python3 -c "
import sys
sys.path.append('/app')
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')

# Test password hashing
password = 'changeme123'
hash1 = pwd_context.hash(password)
hash2 = '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewHEJbFI6GRLUi1O'

print('Original password:', password)
print('New hash:', hash1)
print('Expected hash:', hash2)
print('Hash1 verify:', pwd_context.verify(password, hash1))
print('Hash2 verify:', pwd_context.verify(password, hash2))
"

# Test database connection from backend
echo ""
echo -e "${YELLOW}Step 6: Testing Database Connection from Backend${NC}"
echo "==============================================="
echo "Testing MongoDB connection from backend container..."

docker exec qr-photo-backend python3 -c "
import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient

async def test_db():
    try:
        mongo_url = os.environ.get('MONGO_URL', 'mongodb://mongodb:27017')
        db_name = os.environ.get('DB_NAME', 'qr_photo_db')
        
        print('Connecting to:', mongo_url)
        print('Database:', db_name)
        
        client = AsyncIOMotorClient(mongo_url)
        db = client[db_name]
        
        # Test connection
        await db.command('ping')
        print('✅ Database connection successful')
        
        # Check users collection
        users = await db.users.find().to_list(100)
        print('Users found:', len(users))
        
        for user in users:
            print(f'User: {user.get(\"username\")}, Superadmin: {user.get(\"is_superadmin\")}')
        
    except Exception as e:
        print('❌ Database connection failed:', str(e))

asyncio.run(test_db())
"

# Test the authentication function directly
echo ""
echo -e "${YELLOW}Step 7: Testing Authentication Function${NC}"
echo "=========================================="
echo "Testing authentication logic directly..."

docker exec qr-photo-backend python3 -c "
import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')

async def test_auth():
    try:
        mongo_url = os.environ.get('MONGO_URL', 'mongodb://mongodb:27017')
        db_name = os.environ.get('DB_NAME', 'qr_photo_db')
        
        client = AsyncIOMotorClient(mongo_url)
        db = client[db_name]
        
        # Find superadmin user
        user = await db.users.find_one({'username': 'superadmin'})
        
        if user:
            print('✅ User found in database')
            print('Username:', user.get('username'))
            print('Password hash:', user.get('password_hash'))
            print('Is superadmin:', user.get('is_superadmin'))
            
            # Test password verification
            password = 'changeme123'
            stored_hash = user.get('password_hash')
            
            if stored_hash:
                is_valid = pwd_context.verify(password, stored_hash)
                print('Password verification result:', is_valid)
                
                if not is_valid:
                    print('❌ Password verification failed')
                    print('Trying to create new hash...')
                    new_hash = pwd_context.hash(password)
                    print('New hash:', new_hash)
                    
                    # Update user with new hash
                    await db.users.update_one(
                        {'username': 'superadmin'},
                        {'\$set': {'password_hash': new_hash}}
                    )
                    print('✅ Updated password hash in database')
                else:
                    print('✅ Password verification successful')
            else:
                print('❌ No password hash found')
        else:
            print('❌ No superadmin user found')
            
    except Exception as e:
        print('❌ Authentication test failed:', str(e))

asyncio.run(test_auth())
"

# Restart backend after potential hash update
echo ""
echo -e "${YELLOW}Step 8: Restarting Backend${NC}"
echo "=========================="
echo "Restarting backend container..."
docker restart qr-photo-backend
sleep 10

# Final login test
echo ""
echo -e "${YELLOW}Step 9: Final Login Test${NC}"
echo "======================="
echo "Testing login after all fixes..."

final_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login)

echo "Final login response:"
echo "$final_response"

if echo "$final_response" | grep -q "access_token"; then
    echo -e "${GREEN}✅ LOGIN SUCCESSFUL!${NC}"
    echo ""
    echo "🎉 Authentication is now working!"
    echo "You can login at: http://81.173.84.37:3000/admin/login"
    echo "Username: superadmin"
    echo "Password: changeme123"
else
    echo -e "${RED}❌ Login still failing${NC}"
    echo ""
    echo "Manual intervention required. Please check:"
    echo "1. Backend logs: docker logs qr-photo-backend"
    echo "2. Database contents: docker exec qr-photo-mongodb mongosh"
    echo "3. Try restarting all containers"
fi

echo ""
echo -e "${BLUE}Debug Summary Complete${NC}"
echo "====================="
echo "Check the output above for specific issues and solutions."