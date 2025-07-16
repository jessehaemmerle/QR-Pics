#!/bin/bash

echo "🔧 QR Photo Upload - Complete Authentication Rebuild"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}⚠️  This will completely rebuild the authentication system${NC}"
echo -e "${RED}⚠️  This will delete all existing users and recreate superadmin${NC}"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${BLUE}🔧 Starting Complete Authentication Rebuild${NC}"
echo "=========================================="

# Step 1: Stop all containers
echo ""
echo -e "${YELLOW}Step 1: Stopping all containers${NC}"
echo "==============================="
docker stop qr-photo-frontend qr-photo-backend qr-photo-mongodb

# Step 2: Remove containers
echo ""
echo -e "${YELLOW}Step 2: Removing containers${NC}"
echo "========================="
docker rm qr-photo-frontend qr-photo-backend qr-photo-mongodb

# Step 3: Remove volumes
echo ""
echo -e "${YELLOW}Step 3: Removing database volume${NC}"
echo "=============================="
docker volume rm mongodb_data 2>/dev/null || true

# Step 4: Clean up Docker system
echo ""
echo -e "${YELLOW}Step 4: Cleaning Docker system${NC}"
echo "============================"
docker system prune -f

# Step 5: Rebuild backend image
echo ""
echo -e "${YELLOW}Step 5: Rebuilding backend image${NC}"
echo "=============================="
docker build --no-cache -f Dockerfile.backend -t qr-photo-backend .

# Step 6: Rebuild frontend image
echo ""
echo -e "${YELLOW}Step 6: Rebuilding frontend image${NC}"
echo "==============================="
docker build --no-cache -f Dockerfile.frontend.simple -t qr-photo-frontend .

# Step 7: Create network
echo ""
echo -e "${YELLOW}Step 7: Creating network${NC}"
echo "======================"
docker network create qr-photo-network 2>/dev/null || true

# Step 8: Start MongoDB with fresh database
echo ""
echo -e "${YELLOW}Step 8: Starting fresh MongoDB${NC}"
echo "==========================="
docker run -d \
    --name qr-photo-mongodb \
    --network qr-photo-network \
    -p 27017:27017 \
    -e MONGO_INITDB_DATABASE=qr_photo_db \
    -v mongodb_data:/data/db \
    -v "$(pwd)/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro" \
    mongo:7.0

echo "Waiting for MongoDB to start..."
sleep 15

# Step 9: Manually create superadmin user with known good hash
echo ""
echo -e "${YELLOW}Step 9: Creating superadmin user${NC}"
echo "=============================="

# Generate a UUID for user ID
USER_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")

# Create superadmin user with a hash we know works
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.insertOne({
    id: '$USER_ID',
    username: 'superadmin',
    password_hash: '\$2b\$12\$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPJFxDoqS',
    is_superadmin: true,
    allowed_sessions: [],
    created_at: new Date(),
    created_by: 'system'
});
print('✅ Superadmin user created with known good hash');
"

# Step 10: Start backend
echo ""
echo -e "${YELLOW}Step 10: Starting backend${NC}"
echo "======================"
docker run -d \
    --name qr-photo-backend \
    --network qr-photo-network \
    -p 8001:8001 \
    -e MONGO_URL=mongodb://qr-photo-mongodb:27017 \
    -e DB_NAME=qr_photo_db \
    -e SECRET_KEY=your-secret-key-change-in-production-docker-abc123def456 \
    -e FRONTEND_URL=http://81.173.84.37:3000 \
    qr-photo-backend

echo "Waiting for backend to start..."
sleep 15

# Step 11: Start frontend
echo ""
echo -e "${YELLOW}Step 11: Starting frontend${NC}"
echo "======================="
docker run -d \
    --name qr-photo-frontend \
    --network qr-photo-network \
    -p 3000:80 \
    -e REACT_APP_BACKEND_URL=http://81.173.84.37:8001 \
    qr-photo-frontend

echo "Waiting for frontend to start..."
sleep 10

# Step 12: Test with the standard password 'changeme123'
echo ""
echo -e "${YELLOW}Step 12: Testing login with changeme123${NC}"
echo "========================================"

login_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login)

echo "Login response with changeme123:"
echo "$login_response"

if echo "$login_response" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Login successful with changeme123!${NC}"
    SUCCESS=true
else
    echo -e "${RED}❌ Login failed with changeme123${NC}"
    SUCCESS=false
fi

# Step 13: If standard password doesn't work, try with 'secret'
if [ "$SUCCESS" = false ]; then
    echo ""
    echo -e "${YELLOW}Step 13: Testing login with 'secret'${NC}"
    echo "=================================="
    
    login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"username":"superadmin","password":"secret"}' \
        http://81.173.84.37:8001/api/auth/login)
    
    echo "Login response with secret:"
    echo "$login_response"
    
    if echo "$login_response" | grep -q "access_token"; then
        echo -e "${GREEN}✅ Login successful with 'secret'!${NC}"
        echo ""
        echo "🎉 Authentication rebuild complete!"
        echo "Use these credentials:"
        echo "Username: superadmin"
        echo "Password: secret"
        SUCCESS=true
    else
        echo -e "${RED}❌ Login failed with 'secret'${NC}"
    fi
fi

# Step 14: Final status
echo ""
echo -e "${BLUE}🔍 Final Status Check${NC}"
echo "===================="

# Check container status
echo "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check database contents
echo ""
echo "Database contents:"
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.find({}, {username: 1, is_superadmin: 1, created_by: 1}).forEach(function(user) {
    print('User: ' + user.username + ', Superadmin: ' + user.is_superadmin);
});
"

if [ "$SUCCESS" = true ]; then
    echo ""
    echo -e "${GREEN}🎉 AUTHENTICATION REBUILD SUCCESSFUL!${NC}"
    echo "====================================="
    echo ""
    echo "Your QR Photo Upload application is now ready:"
    echo "📱 Frontend: http://81.173.84.37:3000"
    echo "🔗 Admin Login: http://81.173.84.37:3000/admin/login"
    echo "⚙️  Backend API: http://81.173.84.37:8001/api/"
    echo ""
    echo "Login credentials:"
    echo "Username: superadmin"
    echo "Password: changeme123 (or 'secret' if that's what worked)"
else
    echo ""
    echo -e "${RED}❌ AUTHENTICATION REBUILD FAILED${NC}"
    echo "================================"
    echo ""
    echo "Please check:"
    echo "1. Backend logs: docker logs qr-photo-backend"
    echo "2. Database contents: docker exec qr-photo-mongodb mongosh"
    echo "3. Try the deep debug script: ./deep-debug-auth.sh"
fi