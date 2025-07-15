#!/bin/bash

echo "🔧 QR Photo Upload - Manual Superadmin Reset"
echo "==========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}This script will manually reset the superadmin user${NC}"
echo -e "${BLUE}in the MongoDB database with the correct password hash.${NC}"
echo ""

# Check if MongoDB is running
if ! docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo -e "${RED}❌ MongoDB is not accessible${NC}"
    echo "Please ensure MongoDB container is running"
    exit 1
fi

echo -e "${GREEN}✅ MongoDB is accessible${NC}"

# Remove existing superadmin user
echo ""
echo -e "${YELLOW}🗑️  Removing existing superadmin user...${NC}"
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.deleteMany({username: 'superadmin'});
print('Removed existing superadmin users');
"

# Create new superadmin user with correct password hash
echo ""
echo -e "${YELLOW}👤 Creating new superadmin user...${NC}"

# Generate a UUID for the user ID
USER_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")

# Create the user with bcrypt hash for 'changeme123'
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.insertOne({
    id: '$USER_ID',
    username: 'superadmin',
    password_hash: '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewHEJbFI6GRLUi1O',
    is_superadmin: true,
    allowed_sessions: [],
    created_at: new Date(),
    created_by: 'system'
});
print('Created new superadmin user');
"

# Verify the user was created
echo ""
echo -e "${YELLOW}✅ Verifying user creation...${NC}"
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
var user = db.users.findOne({username: 'superadmin'});
if (user) {
    print('✅ User found');
    print('Username: ' + user.username);
    print('Is Superadmin: ' + user.is_superadmin);
    print('Password hash: ' + user.password_hash);
} else {
    print('❌ User not found');
}
"

# Restart backend to ensure it picks up the changes
echo ""
echo -e "${YELLOW}🔄 Restarting backend container...${NC}"
docker restart qr-photo-backend

echo "Waiting for backend to restart..."
sleep 10

# Test the login
echo ""
echo -e "${YELLOW}🧪 Testing login...${NC}"
login_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login)

if echo "$login_response" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Login successful!${NC}"
    echo ""
    echo "🎉 Superadmin reset complete!"
    echo ""
    echo "You can now login with:"
    echo "Username: superadmin"
    echo "Password: changeme123"
    echo ""
    echo "Access the admin panel at: http://81.173.84.37:3000/admin/login"
else
    echo -e "${RED}❌ Login failed${NC}"
    echo "Response: $login_response"
    echo ""
    echo "Please check backend logs for more details:"
    echo "docker logs qr-photo-backend"
fi