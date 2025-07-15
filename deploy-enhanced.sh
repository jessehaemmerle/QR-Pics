#!/bin/bash

echo "🔧 QR Photo Upload - Enhanced Deployment Script"
echo "==============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command was successful
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Success${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

# Function to wait for service to be healthy
wait_for_service() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $service to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if curl -f "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service is ready${NC}"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - waiting for $service..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ $service failed to start within timeout${NC}"
    return 1
}

# Check prerequisites
echo -e "${BLUE}🔍 Checking Prerequisites${NC}"
echo "========================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

# Start Docker if not running
if ! docker info &> /dev/null; then
    echo "Starting Docker daemon..."
    sudo systemctl start docker
    sleep 5
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}❌ Docker Compose not available${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Clean up existing containers
echo ""
echo -e "${YELLOW}🧹 Cleaning Up Existing Containers${NC}"
echo "=================================="

echo "Stopping existing containers..."
$DOCKER_COMPOSE -f docker-compose.local.yml down --remove-orphans 2>/dev/null || true

echo "Removing existing containers..."
docker stop qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true
docker rm qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true

echo "Cleaning up unused Docker resources..."
docker system prune -f

# Kill processes using our ports
echo "Freeing up ports..."
sudo fuser -k 3000/tcp 2>/dev/null || true
sudo fuser -k 8001/tcp 2>/dev/null || true
sudo fuser -k 27017/tcp 2>/dev/null || true

sleep 5

# Build images
echo ""
echo -e "${BLUE}🔨 Building Docker Images${NC}"
echo "========================="

echo "Building backend image..."
if docker build -f Dockerfile.backend -t qr-photo-backend . > /tmp/backend_build.log 2>&1; then
    check_success
else
    echo -e "${RED}❌ Backend build failed${NC}"
    echo "Build log:"
    cat /tmp/backend_build.log
    exit 1
fi

echo "Building frontend image..."
if docker build -f Dockerfile.frontend.simple -t qr-photo-frontend . > /tmp/frontend_build.log 2>&1; then
    check_success
else
    echo -e "${RED}❌ Frontend build failed${NC}"
    echo "Build log:"
    cat /tmp/frontend_build.log
    exit 1
fi

# Start services one by one
echo ""
echo -e "${BLUE}🚀 Starting Services${NC}"
echo "==================="

# Start MongoDB first
echo "Starting MongoDB..."
docker run -d \
    --name qr-photo-mongodb \
    --network qr-photo-network \
    -p 27017:27017 \
    -e MONGO_INITDB_DATABASE=qr_photo_db \
    -v mongodb_data:/data/db \
    -v "$(pwd)/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro" \
    mongo:7.0

# Create network if it doesn't exist
docker network create qr-photo-network 2>/dev/null || true

# Wait for MongoDB
echo "Waiting for MongoDB to be ready..."
sleep 15

# Test MongoDB
if docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MongoDB is running${NC}"
else
    echo -e "${RED}❌ MongoDB failed to start${NC}"
    echo "MongoDB logs:"
    docker logs qr-photo-mongodb
    exit 1
fi

# Start backend
echo "Starting backend..."
docker run -d \
    --name qr-photo-backend \
    --network qr-photo-network \
    -p 8001:8001 \
    -e MONGO_URL=mongodb://qr-photo-mongodb:27017 \
    -e DB_NAME=qr_photo_db \
    -e SECRET_KEY=your-secret-key-change-in-production-docker-abc123def456 \
    -e FRONTEND_URL=http://81.173.84.37:3000 \
    qr-photo-backend

# Wait for backend
if wait_for_service "backend" "http://81.173.84.37:8001/api/"; then
    echo -e "${GREEN}✅ Backend is running${NC}"
else
    echo -e "${RED}❌ Backend failed to start${NC}"
    echo "Backend logs:"
    docker logs qr-photo-backend
    exit 1
fi

# Start frontend
echo "Starting frontend..."
docker run -d \
    --name qr-photo-frontend \
    --network qr-photo-network \
    -p 3000:80 \
    -e REACT_APP_BACKEND_URL=http://81.173.84.37:8001 \
    qr-photo-frontend

# Wait for frontend
if wait_for_service "frontend" "http://81.173.84.37:3000/health"; then
    echo -e "${GREEN}✅ Frontend is running${NC}"
else
    echo -e "${RED}❌ Frontend failed to start${NC}"
    echo "Frontend logs:"
    docker logs qr-photo-frontend
    exit 1
fi

# Final status check
echo ""
echo -e "${BLUE}📊 Final Status${NC}"
echo "================"

echo "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

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
echo "🐳 Container Management:"
echo "   View logs: docker logs [container_name]"
echo "   Stop all: docker stop qr-photo-frontend qr-photo-backend qr-photo-mongodb"
echo "   Remove all: docker rm qr-photo-frontend qr-photo-backend qr-photo-mongodb"
echo ""
echo -e "${YELLOW}🔧 If you encounter issues, run: ./diagnose-containers.sh${NC}"