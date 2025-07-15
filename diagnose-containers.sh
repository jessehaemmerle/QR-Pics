#!/bin/bash

echo "🔍 QR Photo Upload - Container Startup Diagnostics"
echo "================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Docker System Check${NC}"
echo "======================"

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo "Starting Docker daemon..."
    sudo systemctl start docker
    sudo systemctl enable docker
    sleep 5
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Failed to start Docker daemon${NC}"
        echo "Please check Docker installation and run: sudo systemctl status docker"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Docker daemon is running${NC}"
echo "Docker version: $(docker --version)"

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    echo -e "${GREEN}✅ Docker Compose available: $(docker-compose --version)${NC}"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    echo -e "${GREEN}✅ Docker Compose available: $(docker compose version)${NC}"
else
    echo -e "${RED}❌ Docker Compose not available${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📋 Checking Required Files${NC}"
echo "=========================="

required_files=(
    "docker-compose.local.yml"
    "Dockerfile.backend"
    "Dockerfile.frontend.simple"
    "nginx.simple.conf"
    "backend/server.py"
    "frontend/package.json"
    "frontend/src/App.js"
    "mongo-init.js"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file (missing)${NC}"
    fi
done

echo ""
echo -e "${BLUE}🌐 Port Conflicts Check${NC}"
echo "======================"

# Check for port conflicts
ports=(3000 8001 27017)
conflicts=false

for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${YELLOW}⚠️  Port $port is in use${NC}"
        echo "Process using port $port:"
        sudo lsof -i :$port 2>/dev/null || echo "Could not identify process"
        conflicts=true
    else
        echo -e "${GREEN}✅ Port $port is available${NC}"
    fi
done

if [ "$conflicts" = true ]; then
    echo ""
    echo -e "${YELLOW}🛑 Stopping conflicting services...${NC}"
    
    # Stop existing containers
    $DOCKER_COMPOSE -f docker-compose.local.yml down --remove-orphans 2>/dev/null || true
    docker stop qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true
    docker rm qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true
    
    # Kill processes using our ports
    for port in "${ports[@]}"; do
        sudo fuser -k ${port}/tcp 2>/dev/null || true
    done
    
    echo "Waiting for ports to be released..."
    sleep 5
fi

echo ""
echo -e "${BLUE}💾 System Resources Check${NC}"
echo "========================="

# Check disk space
available_space=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$available_space" -lt 5 ]; then
    echo -e "${RED}❌ Low disk space: ${available_space}GB available${NC}"
    echo "At least 5GB recommended for Docker images"
else
    echo -e "${GREEN}✅ Sufficient disk space: ${available_space}GB available${NC}"
fi

# Check memory
available_memory=$(free -m | awk 'NR==2{print $7}')
if [ "$available_memory" -lt 1000 ]; then
    echo -e "${YELLOW}⚠️  Low memory: ${available_memory}MB available${NC}"
    echo "At least 1GB recommended"
else
    echo -e "${GREEN}✅ Sufficient memory: ${available_memory}MB available${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Docker Build Test${NC}"
echo "=================="

# Clean up old images
echo "Cleaning up old Docker images..."
docker system prune -f

# Test build backend
echo "Testing backend build..."
if docker build -f Dockerfile.backend -t qr-photo-backend-test . > /tmp/backend_build.log 2>&1; then
    echo -e "${GREEN}✅ Backend build successful${NC}"
    docker rmi qr-photo-backend-test 2>/dev/null || true
else
    echo -e "${RED}❌ Backend build failed${NC}"
    echo "Backend build log:"
    cat /tmp/backend_build.log
fi

# Test build frontend
echo "Testing frontend build..."
if docker build -f Dockerfile.frontend.simple -t qr-photo-frontend-test . > /tmp/frontend_build.log 2>&1; then
    echo -e "${GREEN}✅ Frontend build successful${NC}"
    docker rmi qr-photo-frontend-test 2>/dev/null || true
else
    echo -e "${RED}❌ Frontend build failed${NC}"
    echo "Frontend build log:"
    cat /tmp/frontend_build.log
fi

echo ""
echo -e "${YELLOW}🚀 Attempting Manual Deployment${NC}"
echo "==============================="

# Try manual deployment step by step
echo "Step 1: Stopping any existing containers..."
$DOCKER_COMPOSE -f docker-compose.local.yml down --remove-orphans

echo "Step 2: Building images..."
$DOCKER_COMPOSE -f docker-compose.local.yml build --no-cache

echo "Step 3: Starting MongoDB first..."
$DOCKER_COMPOSE -f docker-compose.local.yml up -d mongodb

echo "Waiting for MongoDB to start..."
sleep 10

echo "Step 4: Starting backend..."
$DOCKER_COMPOSE -f docker-compose.local.yml up -d backend

echo "Waiting for backend to start..."
sleep 10

echo "Step 5: Starting frontend..."
$DOCKER_COMPOSE -f docker-compose.local.yml up -d frontend

echo "Waiting for frontend to start..."
sleep 5

echo ""
echo -e "${BLUE}📊 Container Status${NC}"
echo "=================="

$DOCKER_COMPOSE -f docker-compose.local.yml ps

echo ""
echo -e "${BLUE}🔍 Detailed Container Logs${NC}"
echo "========================="

echo "MongoDB logs:"
$DOCKER_COMPOSE -f docker-compose.local.yml logs --tail=20 mongodb

echo ""
echo "Backend logs:"
$DOCKER_COMPOSE -f docker-compose.local.yml logs --tail=20 backend

echo ""
echo "Frontend logs:"
$DOCKER_COMPOSE -f docker-compose.local.yml logs --tail=20 frontend

echo ""
echo -e "${BLUE}🧪 Service Tests${NC}"
echo "================"

# Test services
echo "Testing MongoDB..."
if docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MongoDB is responding${NC}"
else
    echo -e "${RED}❌ MongoDB is not responding${NC}"
fi

echo "Testing backend..."
if curl -f http://81.173.84.37:8001/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is responding${NC}"
else
    echo -e "${RED}❌ Backend is not responding${NC}"
fi

echo "Testing frontend..."
if curl -f http://81.173.84.37:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend is responding${NC}"
else
    echo -e "${RED}❌ Frontend is not responding${NC}"
fi

echo ""
echo -e "${YELLOW}🔧 Troubleshooting Recommendations${NC}"
echo "================================="

echo "If containers still aren't starting:"
echo "1. Check the detailed logs above"
echo "2. Verify all required files are present"
echo "3. Ensure Docker daemon is running"
echo "4. Check for port conflicts"
echo "5. Verify sufficient disk space and memory"
echo "6. Try building images individually"
echo ""
echo "Manual commands to try:"
echo "  docker-compose -f docker-compose.local.yml logs [service]"
echo "  docker-compose -f docker-compose.local.yml build --no-cache [service]"
echo "  docker-compose -f docker-compose.local.yml up [service]"
echo ""
echo "Access URLs (if working):"
echo "  Frontend: http://81.173.84.37:3000"
echo "  Backend: http://81.173.84.37:8001/api/"
echo "  Admin: http://81.173.84.37:3000/admin/login"