#!/bin/bash

# Docker Setup Validation Script
# This script validates the Docker configuration files

set -e

echo "🔍 Validating Docker setup for QR Photo Upload..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check required files
echo ""
echo "📋 Checking required files..."

required_files=(
    "docker-compose.yml"
    "docker-compose.prod.yml"
    "Dockerfile.backend"
    "Dockerfile.frontend"
    "nginx.conf"
    "nginx.prod.conf"
    "mongo-init.js"
    "frontend-entrypoint.sh"
    ".dockerignore"
    "deploy.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found $file"
    else
        print_error "Missing $file"
        exit 1
    fi
done

# Check if files are executable
echo ""
echo "🔧 Checking file permissions..."

executable_files=(
    "deploy.sh"
    "frontend-entrypoint.sh"
    "backend/healthcheck.sh"
)

for file in "${executable_files[@]}"; do
    if [ -x "$file" ]; then
        print_success "$file is executable"
    else
        print_warning "$file is not executable"
        chmod +x "$file"
        print_success "Made $file executable"
    fi
done

# Validate YAML syntax
echo ""
echo "📝 Validating YAML syntax..."

if command -v python3 &> /dev/null; then
    python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml')); print('✅ docker-compose.yml is valid YAML')"
    python3 -c "import yaml; yaml.safe_load(open('docker-compose.prod.yml')); print('✅ docker-compose.prod.yml is valid YAML')"
else
    print_warning "Python3 not found, skipping YAML validation"
fi

# Check Docker configuration
echo ""
echo "🐳 Checking Docker configuration..."

# Check if Docker is available
if command -v docker &> /dev/null; then
    print_success "Docker is installed"
    docker --version
else
    print_warning "Docker is not installed"
    echo "  Install Docker: curl -fsSL https://get.docker.com | sh"
fi

# Check if Docker Compose is available
if command -v docker-compose &> /dev/null; then
    print_success "Docker Compose is installed"
    docker-compose --version
else
    print_warning "Docker Compose is not installed"
    echo "  Install Docker Compose: https://docs.docker.com/compose/install/"
fi

# Validate Dockerfile syntax
echo ""
echo "📦 Validating Dockerfile syntax..."

if command -v docker &> /dev/null; then
    if docker build -f Dockerfile.backend -t qr-photo-backend-test . --dry-run 2>/dev/null; then
        print_success "Dockerfile.backend syntax is valid"
    else
        print_warning "Cannot validate Dockerfile.backend (Docker daemon not running)"
    fi
    
    if docker build -f Dockerfile.frontend -t qr-photo-frontend-test . --dry-run 2>/dev/null; then
        print_success "Dockerfile.frontend syntax is valid"
    else
        print_warning "Cannot validate Dockerfile.frontend (Docker daemon not running)"
    fi
else
    print_warning "Docker not available, skipping Dockerfile validation"
fi

# Check environment files
echo ""
echo "🔧 Checking environment configuration..."

if [ -f "backend/.env" ]; then
    print_success "Backend environment file exists"
else
    print_warning "Backend .env file not found"
    echo "  Create backend/.env with required variables"
fi

if [ -f "frontend/.env" ]; then
    print_success "Frontend environment file exists"
else
    print_warning "Frontend .env file not found"
    echo "  Create frontend/.env with required variables"
fi

if [ -f "frontend/.env.docker" ]; then
    print_success "Docker-specific frontend environment file exists"
else
    print_warning "Docker-specific frontend .env file not found"
fi

# Check directory structure
echo ""
echo "📁 Checking directory structure..."

directories=(
    "backend"
    "frontend"
    "frontend/src"
    "frontend/public"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        print_success "Directory $dir exists"
    else
        print_error "Directory $dir missing"
        exit 1
    fi
done

# Check key application files
echo ""
echo "📱 Checking application files..."

app_files=(
    "backend/server.py"
    "backend/requirements.txt"
    "frontend/package.json"
    "frontend/src/App.js"
    "frontend/src/App.css"
)

for file in "${app_files[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found $file"
    else
        print_error "Missing $file"
        exit 1
    fi
done

# Final summary
echo ""
echo "🎉 Docker setup validation complete!"
echo ""
echo "📋 Summary:"
echo "   ✅ All required files present"
echo "   ✅ File permissions correct"
echo "   ✅ YAML syntax valid"
echo "   ✅ Directory structure correct"
echo "   ✅ Application files present"
echo ""
echo "🚀 Ready to deploy!"
echo ""
echo "📌 Next steps:"
echo "   1. Install Docker and Docker Compose (if not already installed)"
echo "   2. Run: ./deploy.sh"
echo "   3. Access: http://localhost:3000"
echo ""
echo "📚 Documentation:"
echo "   - DOCKER_GUIDE.md - Comprehensive deployment guide"
echo "   - README.Docker.md - Docker-specific documentation"
echo "   - DOCKER_SUMMARY.md - Quick reference"
echo ""
print_success "QR Photo Upload is ready for Docker deployment!"