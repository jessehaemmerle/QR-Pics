#!/bin/bash

# QR Photo Upload - Deployment Script

set -e

echo "🚀 Starting QR Photo Upload deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed (try both versions)
DOCKER_COMPOSE_CMD=""
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Using Docker Compose command: $DOCKER_COMPOSE_CMD"

# Parse command line arguments
ENVIRONMENT="development"
DETACHED=false
BUILD=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--detached)
            DETACHED=true
            shift
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -e, --environment   Environment (development|production) [default: development]"
            echo "  -d, --detached      Run in detached mode"
            echo "  -b, --build         Force rebuild of images"
            echo "  -c, --clean         Clean up existing containers and volumes"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set compose file based on environment
if [ "$ENVIRONMENT" = "production" ]; then
    COMPOSE_FILE="docker-compose.prod.yml"
    print_status "Using production configuration"
else
    COMPOSE_FILE="docker-compose.yml"
    print_status "Using development configuration"
fi

# Clean up if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning up existing containers and volumes..."
    $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down --volumes --remove-orphans
    docker system prune -f
fi

# Build images if requested
if [ "$BUILD" = true ]; then
    print_status "Building Docker images..."
    $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE build --no-cache
fi

# Start services
print_status "Starting services..."
if [ "$DETACHED" = true ]; then
    $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE up -d
else
    $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE up
fi

# Wait for services to be healthy
if [ "$DETACHED" = true ]; then
    print_status "Waiting for services to be healthy..."
    
    # Wait for MongoDB
    print_status "Waiting for MongoDB to be ready..."
    until docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')" > /dev/null 2>&1; do
        sleep 2
    done
    
    # Wait for backend
    print_status "Waiting for backend to be ready..."
    until curl -f http://localhost:8001/api/ > /dev/null 2>&1; do
        sleep 2
    done
    
    # Wait for frontend
    print_status "Waiting for frontend to be ready..."
    until curl -f http://localhost:3000/health > /dev/null 2>&1; do
        sleep 2
    done
    
    print_status "All services are healthy!"
    
    # Display access information
    echo ""
    echo "🎉 QR Photo Upload is now running!"
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
    echo "   $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down"
    echo ""
    echo "📊 To view logs:"
    echo "   $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE logs -f"
fi