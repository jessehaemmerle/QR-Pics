#!/bin/bash

echo "🔧 QR Photo Upload - Force Superadmin Creation"
echo "============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}This script will force the creation of the superadmin user${NC}"
echo -e "${BLUE}by restarting the backend and monitoring the startup process.${NC}"
echo ""

# Check if containers are running
echo -e "${YELLOW}📋 Checking container status...${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""

# Clear the users collection to force superadmin creation
echo -e "${YELLOW}🗑️  Clearing users collection...${NC}"
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.deleteMany({});
print('Cleared users collection');
"

# Stop and restart backend to trigger superadmin creation
echo ""
echo -e "${YELLOW}🔄 Stopping backend container...${NC}"
docker stop qr-photo-backend

echo ""
echo -e "${YELLOW}🚀 Starting backend container...${NC}"
docker start qr-photo-backend

echo ""
echo -e "${YELLOW}📋 Monitoring backend startup logs...${NC}"
echo "Looking for superadmin creation message..."

# Wait a bit and check logs
sleep 5

# Check if superadmin creation message appears in logs
echo ""
echo "Backend startup logs:"
docker logs --tail=20 qr-photo-backend

echo ""
echo -e "${YELLOW}✅ Checking if superadmin was created...${NC}"
sleep 5

# Check if superadmin user exists
user_count=$(docker exec qr-photo-mongodb mongosh --quiet --eval "
use qr_photo_db;
db.users.countDocuments({username: 'superadmin'});
")

if [ "$user_count" -eq 1 ]; then
    echo -e "${GREEN}✅ Superadmin user found in database${NC}"
    
    # Show user details
    docker exec qr-photo-mongodb mongosh --eval "
    use qr_photo_db;
    var user = db.users.findOne({username: 'superadmin'});
    if (user) {
        print('Username: ' + user.username);
        print('Is Superadmin: ' + user.is_superadmin);
        print('Created By: ' + user.created_by);
    }
    "
else
    echo -e "${RED}❌ Superadmin user not found${NC}"
    echo "Manual creation may be needed. Run: ./reset-superadmin.sh"
fi

# Wait for backend to be fully ready
echo ""
echo -e "${YELLOW}⏳ Waiting for backend to be ready...${NC}"
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
    echo "🎉 Superadmin creation complete!"
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
    echo "Please run the manual reset script:"
    echo "./reset-superadmin.sh"
fi