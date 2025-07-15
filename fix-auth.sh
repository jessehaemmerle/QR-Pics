#!/bin/bash

echo "🔍 QR Photo Upload - Authentication Issues Diagnosis"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Checking Authentication System${NC}"
echo "================================="

# Check if backend is running
echo "Checking backend status..."
if curl -f http://81.173.84.37:8001/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is responding${NC}"
else
    echo -e "${RED}❌ Backend is not responding${NC}"
    echo "Please ensure backend is running first"
    exit 1
fi

# Check backend logs for superadmin creation
echo ""
echo -e "${YELLOW}📋 Checking Backend Logs for Superadmin Creation${NC}"
echo "==============================================="
echo "Backend logs (last 50 lines):"
docker logs --tail=50 qr-photo-backend

echo ""
echo -e "${BLUE}🔍 Checking Database Connection${NC}"
echo "==============================="

# Check if MongoDB is accessible
echo "Testing MongoDB connection..."
if docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MongoDB is accessible${NC}"
else
    echo -e "${RED}❌ MongoDB is not accessible${NC}"
    exit 1
fi

# Check database and users collection
echo ""
echo -e "${YELLOW}📋 Checking Database Contents${NC}"
echo "============================="

echo "Checking database qr_photo_db..."
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.runCommand('listCollections').cursor.firstBatch.forEach(function(collection) {
    print('Collection: ' + collection.name);
});
"

echo ""
echo "Checking users collection..."
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
print('Users count: ' + db.users.countDocuments());
db.users.find().forEach(function(user) {
    print('User: ' + user.username + ', Is Superadmin: ' + user.is_superadmin);
});
"

echo ""
echo -e "${BLUE}🔧 Testing Authentication Manually${NC}"
echo "=================================="

# Test the login endpoint
echo "Testing login endpoint with superadmin credentials..."
login_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login)

echo "Login response: $login_response"

if echo "$login_response" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Login successful${NC}"
else
    echo -e "${RED}❌ Login failed${NC}"
    
    # Check if it's a credential issue or server issue
    if echo "$login_response" | grep -q "Invalid credentials"; then
        echo -e "${YELLOW}⚠️  Credential issue detected${NC}"
    elif echo "$login_response" | grep -q "detail"; then
        echo -e "${YELLOW}⚠️  Server error detected${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}🔧 Attempting to Fix Authentication Issues${NC}"
echo "=========================================="

# Check if superadmin user exists
echo "Checking if superadmin user exists..."
user_exists=$(docker exec qr-photo-mongodb mongosh --quiet --eval "
use qr_photo_db;
db.users.countDocuments({username: 'superadmin'});
")

if [ "$user_exists" -eq 0 ]; then
    echo -e "${RED}❌ Superadmin user does not exist${NC}"
    echo "Creating superadmin user manually..."
    
    # Create superadmin user manually
    docker exec qr-photo-mongodb mongosh --eval "
    use qr_photo_db;
    db.users.insertOne({
        id: '$(uuidgen)',
        username: 'superadmin',
        password_hash: '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewHEJbFI6GRLUi1O',
        is_superadmin: true,
        allowed_sessions: [],
        created_at: new Date(),
        created_by: 'system'
    });
    "
    
    echo -e "${GREEN}✅ Superadmin user created manually${NC}"
else
    echo -e "${GREEN}✅ Superadmin user exists${NC}"
    
    # Check the password hash
    echo "Checking password hash..."
    docker exec qr-photo-mongodb mongosh --eval "
    use qr_photo_db;
    var user = db.users.findOne({username: 'superadmin'});
    if (user) {
        print('Password hash: ' + user.password_hash);
        print('Is superadmin: ' + user.is_superadmin);
    }
    "
fi

echo ""
echo -e "${BLUE}🔄 Restarting Backend to Apply Changes${NC}"
echo "====================================="

echo "Restarting backend container..."
docker restart qr-photo-backend

echo "Waiting for backend to restart..."
sleep 10

# Test login again
echo ""
echo -e "${YELLOW}🧪 Testing Login Again${NC}"
echo "======================"

login_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login)

echo "Login response: $login_response"

if echo "$login_response" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Login now works!${NC}"
    echo ""
    echo "You can now login with:"
    echo "Username: superadmin"
    echo "Password: changeme123"
    echo ""
    echo "Access the admin panel at: http://81.173.84.37:3000/admin/login"
else
    echo -e "${RED}❌ Login still fails${NC}"
    echo ""
    echo "Manual troubleshooting needed. Check backend logs:"
    echo "docker logs qr-photo-backend"
fi

echo ""
echo -e "${BLUE}📋 Summary${NC}"
echo "=========="
echo "Frontend: http://81.173.84.37:3000"
echo "Admin Login: http://81.173.84.37:3000/admin/login"
echo "Backend API: http://81.173.84.37:8001/api/"
echo ""
echo "Default credentials:"
echo "Username: superadmin"
echo "Password: changeme123"