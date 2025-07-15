#!/bin/bash

echo "🔍 Pre-deployment Validation"
echo "============================"

# Check if required files exist
echo "📁 Checking required files..."
required_files=(
    "docker-compose.local.yml"
    "Dockerfile.frontend.simple"
    "nginx.simple.conf"
    "deploy-local.sh"
    "troubleshoot-local.sh"
    "backend/server.py"
    "frontend/package.json"
    "frontend/src/App.js"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (missing)"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo ""
    echo "❌ Some required files are missing. Please ensure all files are present."
    exit 1
fi

echo ""
echo "🐳 Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
else
    echo "✅ Docker is installed: $(docker --version)"
fi

echo ""
echo "🔧 Checking Docker Compose..."
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose available: $(docker-compose --version)"
elif docker compose version &> /dev/null; then
    echo "✅ Docker Compose available: $(docker compose version)"
else
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

echo ""
echo "🌐 Checking port availability..."
ports=(3000 8001 27017)
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  Port $port is in use (you may need to stop existing services)"
    else
        echo "✅ Port $port is available"
    fi
done

echo ""
echo "📊 System Resources..."
echo "Available disk space: $(df -h . | awk 'NR==2{print $4}')"
echo "Available memory: $(free -h | awk 'NR==2{print $7}')"

echo ""
echo "🎯 Validation Complete!"
echo "======================"
echo ""
echo "✅ All required files are present"
echo "✅ Docker and Docker Compose are available"
echo "✅ System resources are adequate"
echo ""
echo "🚀 Ready to deploy! Run:"
echo "   ./deploy-local.sh"
echo ""
echo "📖 For detailed instructions, see:"
echo "   LOCAL_DEPLOYMENT_GUIDE.md"