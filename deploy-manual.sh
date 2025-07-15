#!/bin/bash

echo "🔧 QR Photo Upload - Manual Step-by-Step Deployment"
echo "==================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}This script will deploy your application step by step.${NC}"
echo -e "${BLUE}Press Enter after each step to continue...${NC}"
echo ""

# Step 1: Prerequisites
echo -e "${YELLOW}Step 1: Checking Prerequisites${NC}"
echo "=============================="
echo "Checking Docker installation..."
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker is installed${NC}"
else
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

echo "Checking Docker daemon..."
if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
else
    echo -e "${YELLOW}⚠️  Starting Docker daemon...${NC}"
    sudo systemctl start docker
    sudo systemctl enable docker
    sleep 5
fi

read -p "Press Enter to continue..."
echo ""

# Step 2: Clean up
echo -e "${YELLOW}Step 2: Cleaning Up Previous Installations${NC}"
echo "==========================================="
echo "Stopping any existing containers..."
docker stop qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true
docker rm qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true

echo "Cleaning up Docker resources..."
docker system prune -f

echo "Freeing up ports..."
sudo fuser -k 3000/tcp 2>/dev/null || true
sudo fuser -k 8001/tcp 2>/dev/null || true
sudo fuser -k 27017/tcp 2>/dev/null || true

echo -e "${GREEN}✅ Cleanup complete${NC}"
read -p "Press Enter to continue..."
echo ""

# Step 3: Create network
echo -e "${YELLOW}Step 3: Creating Docker Network${NC}"
echo "==============================="
docker network create qr-photo-network 2>/dev/null || echo "Network already exists"
echo -e "${GREEN}✅ Network ready${NC}"
read -p "Press Enter to continue..."
echo ""

# Step 4: Build images
echo -e "${YELLOW}Step 4: Building Docker Images${NC}"
echo "=============================="
echo "Building backend image..."
if docker build -f Dockerfile.backend -t qr-photo-backend .; then
    echo -e "${GREEN}✅ Backend image built${NC}"
else
    echo -e "${RED}❌ Backend build failed${NC}"
    exit 1
fi

echo "Building frontend image..."
if docker build -f Dockerfile.frontend.simple -t qr-photo-frontend .; then
    echo -e "${GREEN}✅ Frontend image built${NC}"
else
    echo -e "${RED}❌ Frontend build failed${NC}"
    exit 1
fi

read -p "Press Enter to continue..."
echo ""

# Step 5: Start MongoDB
echo -e "${YELLOW}Step 5: Starting MongoDB${NC}"
echo "======================="
echo "Starting MongoDB container..."
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

if docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MongoDB is running${NC}"
else
    echo -e "${RED}❌ MongoDB failed to start${NC}"
    echo "MongoDB logs:"
    docker logs qr-photo-mongodb
    exit 1
fi

read -p "Press Enter to continue..."
echo ""

# Step 6: Start Backend
echo -e "${YELLOW}Step 6: Starting Backend${NC}"
echo "======================="
echo "Starting backend container..."
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
sleep 10

if curl -f http://81.173.84.37:8001/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is running${NC}"
else
    echo -e "${RED}❌ Backend failed to start${NC}"
    echo "Backend logs:"
    docker logs qr-photo-backend
    exit 1
fi

read -p "Press Enter to continue..."
echo ""

# Step 7: Start Frontend
echo -e "${YELLOW}Step 7: Starting Frontend${NC}"
echo "======================="
echo "Starting frontend container..."
docker run -d \
    --name qr-photo-frontend \
    --network qr-photo-network \
    -p 3000:80 \
    -e REACT_APP_BACKEND_URL=http://81.173.84.37:8001 \
    qr-photo-frontend

echo "Waiting for frontend to start..."
sleep 10

if curl -f http://81.173.84.37:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend is running${NC}"
else
    echo -e "${RED}❌ Frontend failed to start${NC}"
    echo "Frontend logs:"
    docker logs qr-photo-frontend
    exit 1
fi

read -p "Press Enter to continue..."
echo ""

# Step 8: Final verification
echo -e "${YELLOW}Step 8: Final Verification${NC}"
echo "========================="
echo "Checking all services..."

echo "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Testing services..."

# Test MongoDB
if docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MongoDB: OK${NC}"
else
    echo -e "${RED}❌ MongoDB: Failed${NC}"
fi

# Test Backend
if curl -f http://81.173.84.37:8001/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend: OK${NC}"
else
    echo -e "${RED}❌ Backend: Failed${NC}"
fi

# Test Frontend
if curl -f http://81.173.84.37:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend: OK${NC}"
else
    echo -e "${RED}❌ Frontend: Failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "======================="
echo ""
echo "Your QR Photo Upload application is now running:"
echo ""
echo "📱 Frontend: http://81.173.84.37:3000"
echo "🔗 Admin Login: http://81.173.84.37:3000/admin/login"
echo "⚙️  Backend API: http://81.173.84.37:8001/api/"
echo ""
echo "👤 Default Admin Credentials:"
echo "   Username: superadmin"
echo "   Password: changeme123"
echo ""
echo "🐳 Container Management Commands:"
echo "   View logs: docker logs [container_name]"
echo "   Stop all: docker stop qr-photo-frontend qr-photo-backend qr-photo-mongodb"
echo "   Remove all: docker rm qr-photo-frontend qr-photo-backend qr-photo-mongodb"
echo ""
echo -e "${BLUE}Test your deployment by visiting: http://81.173.84.37:3000${NC}"