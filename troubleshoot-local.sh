#!/bin/bash

echo "🔍 QR Photo Upload - Server 81.173.84.37 Troubleshooting"
echo "======================================================="

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    exit 1
else
    echo "✅ Docker is installed: $(docker --version)"
fi

# Check for Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose available: $(docker-compose --version)"
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    echo "✅ Docker Compose available: $(docker compose version)"
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose is not available"
    exit 1
fi

echo ""
echo "🐳 Docker Container Status:"
echo "=========================="
$DOCKER_COMPOSE -f docker-compose.local.yml ps

echo ""
echo "🌐 Port Status:"
echo "=============="
echo "Port 3000 (Frontend):"
if netstat -tuln | grep -q ":3000 "; then
    echo "✅ Port 3000 is in use"
else
    echo "❌ Port 3000 is not in use"
fi

echo "Port 8001 (Backend):"
if netstat -tuln | grep -q ":8001 "; then
    echo "✅ Port 8001 is in use"
else
    echo "❌ Port 8001 is not in use"
fi

echo "Port 27017 (MongoDB):"
if netstat -tuln | grep -q ":27017 "; then
    echo "✅ Port 27017 is in use"
else
    echo "❌ Port 27017 is not in use"
fi

echo ""
echo "🧪 Service Tests:"
echo "================"

# Test backend
echo "Testing backend API..."
if curl -f http://81.173.84.37:8001/api/ > /dev/null 2>&1; then
    echo "✅ Backend API is responding"
    echo "   Response: $(curl -s http://81.173.84.37:8001/api/)"
else
    echo "❌ Backend API is not responding"
fi

# Test frontend
echo "Testing frontend..."
if curl -f http://81.173.84.37:3000/health > /dev/null 2>&1; then
    echo "✅ Frontend is responding"
else
    echo "❌ Frontend is not responding"
fi

# Test MongoDB
echo "Testing MongoDB..."
if docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; then
    echo "✅ MongoDB is responding"
else
    echo "❌ MongoDB is not responding"
fi

echo ""
echo "🔥 Firewall Check:"
echo "=================="
echo "Make sure these ports are open on your server:"
echo "  - Port 3000 (Frontend)"
echo "  - Port 8001 (Backend)"
echo "  - Port 27017 (MongoDB - optional, only if external access needed)"
echo ""
echo "Common firewall commands:"
echo "  Ubuntu/Debian: sudo ufw allow 3000 && sudo ufw allow 8001"
echo "  CentOS/RHEL: sudo firewall-cmd --permanent --add-port=3000/tcp && sudo firewall-cmd --permanent --add-port=8001/tcp && sudo firewall-cmd --reload"

echo ""
echo "📊 Recent Logs:"
echo "=============="
echo "Backend logs (last 10 lines):"
$DOCKER_COMPOSE -f docker-compose.local.yml logs --tail=10 backend

echo ""
echo "Frontend logs (last 10 lines):"
$DOCKER_COMPOSE -f docker-compose.local.yml logs --tail=10 frontend

echo ""
echo "MongoDB logs (last 10 lines):"
$DOCKER_COMPOSE -f docker-compose.local.yml logs --tail=10 mongodb

echo ""
echo "🔧 Quick Fixes:"
echo "=============="
echo "1. Restart all services:"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml restart"
echo ""
echo "2. Full rebuild:"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml down"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml up --build -d"
echo ""
echo "3. Check logs:"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml logs -f"
echo ""
echo "4. Access URLs:"
echo "   Frontend: http://81.173.84.37:3000"
echo "   Backend: http://81.173.84.37:8001/api/"
echo "   Admin: http://81.173.84.37:3000/admin/login"
echo ""
echo "5. Check firewall settings:"
echo "   sudo ufw status"
echo "   sudo ufw allow 3000"
echo "   sudo ufw allow 8001"