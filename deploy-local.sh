#!/bin/bash

# Local deployment script for QR Photo Upload
echo "🚀 Starting QR Photo Upload LOCAL deployment..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check for Docker Compose (try both versions)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Using Docker Compose command: $DOCKER_COMPOSE"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
$DOCKER_COMPOSE -f docker-compose.local.yml down 2>/dev/null || true

# Clean up any conflicting containers
echo "🧹 Cleaning up..."
docker rm -f qr-photo-mongodb qr-photo-backend qr-photo-frontend 2>/dev/null || true

# Build and start services
echo "🔨 Building and starting services..."
$DOCKER_COMPOSE -f docker-compose.local.yml up --build -d

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 15

# Check if services are running
echo "🔍 Checking service status..."
$DOCKER_COMPOSE -f docker-compose.local.yml ps

# Test backend API
echo "🧪 Testing backend API..."
if curl -f http://localhost:8001/api/ > /dev/null 2>&1; then
    echo "✅ Backend API is responding"
else
    echo "❌ Backend API is not responding"
    echo "Backend logs:"
    $DOCKER_COMPOSE -f docker-compose.local.yml logs backend
fi

# Test frontend
echo "🧪 Testing frontend..."
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Frontend is responding"
else
    echo "❌ Frontend is not responding"
    echo "Frontend logs:"
    $DOCKER_COMPOSE -f docker-compose.local.yml logs frontend
fi

# Display access information
echo ""
echo "🎉 QR Photo Upload LOCAL deployment complete!"
echo ""
echo "📱 Frontend: http://localhost:3000"
echo "🔗 Admin Login: http://localhost:3000/admin/login"
echo "⚙️  Backend API: http://localhost:8001/api/"
echo ""
echo "👤 Default Admin Credentials:"
echo "   Username: superadmin"
echo "   Password: changeme123"
echo ""
echo "🐳 To stop the services:"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml down"
echo ""
echo "📊 To view logs:"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml logs -f"
echo ""
echo "🔧 If you encounter issues, check the logs:"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml logs backend"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml logs frontend"
echo "   $DOCKER_COMPOSE -f docker-compose.local.yml logs mongodb"