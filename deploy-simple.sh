#!/bin/bash

# Simple deployment script for QR Photo Upload
echo "🚀 Starting QR Photo Upload deployment..."

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

# Build and start services
echo "🔨 Building and starting services..."
$DOCKER_COMPOSE up --build -d

# Wait a moment for services to start
echo "⏳ Waiting for services to initialize..."
sleep 10

# Check if services are running
echo "🔍 Checking service status..."
$DOCKER_COMPOSE ps

# Display access information
echo ""
echo "🎉 QR Photo Upload should now be running!"
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
echo "   $DOCKER_COMPOSE down"
echo ""
echo "📊 To view logs:"
echo "   $DOCKER_COMPOSE logs -f"
echo ""
echo "🔧 If you encounter issues, check the logs:"
echo "   $DOCKER_COMPOSE logs backend"
echo "   $DOCKER_COMPOSE logs frontend"
echo "   $DOCKER_COMPOSE logs mongodb"