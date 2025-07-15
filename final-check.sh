#!/bin/bash

echo "🎉 QR Photo Upload - Final Deployment Check"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Server Configuration Summary${NC}"
echo "==============================="
echo ""
echo "Server IP: 81.173.84.37"
echo "Frontend URL: http://81.173.84.37:3000"
echo "Backend URL: http://81.173.84.37:8001"
echo "Admin Login: http://81.173.84.37:3000/admin/login"
echo ""

echo -e "${YELLOW}📋 Pre-deployment Checklist${NC}"
echo "==========================="
echo ""

# Check if required files exist
required_files=(
    "docker-compose.local.yml"
    "deploy-local.sh"
    "setup-firewall.sh"
    "troubleshoot-local.sh"
)

all_files_ok=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        all_files_ok=false
    fi
done

if [ "$all_files_ok" = false ]; then
    echo ""
    echo -e "${RED}❌ Some required files are missing!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All required files are present${NC}"
echo ""

# Check Docker
echo -e "${BLUE}🐳 Docker Status${NC}"
echo "==============="
if command -v docker &> /dev/null; then
    echo "✅ Docker is installed"
    if docker ps &> /dev/null; then
        echo "✅ Docker is running"
    else
        echo "❌ Docker is not running - start with: sudo systemctl start docker"
    fi
else
    echo "❌ Docker is not installed"
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose is available"
elif docker compose version &> /dev/null; then
    echo "✅ Docker Compose is available"
else
    echo "❌ Docker Compose is not available"
fi

echo ""
echo -e "${YELLOW}🔥 Firewall Status${NC}"
echo "=================="

# Check firewall
if command -v ufw &> /dev/null; then
    echo "UFW Status:"
    sudo ufw status
elif command -v firewall-cmd &> /dev/null; then
    echo "Firewalld Status:"
    sudo firewall-cmd --list-ports
else
    echo "No common firewall detected"
fi

echo ""
echo -e "${BLUE}🌐 Port Check${NC}"
echo "============="

# Check if ports are available
ports=(3000 8001 22)
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        if [ "$port" = "22" ]; then
            echo "✅ Port $port (SSH) is open"
        else
            echo "⚠️  Port $port is in use (may need to stop existing service)"
        fi
    else
        echo "📭 Port $port is available"
    fi
done

echo ""
echo -e "${GREEN}🚀 Deployment Commands${NC}"
echo "======================"
echo ""
echo "1. Configure firewall (if not done):"
echo "   ${YELLOW}./setup-firewall.sh${NC}"
echo ""
echo "2. Deploy application:"
echo "   ${YELLOW}./deploy-local.sh${NC}"
echo ""
echo "3. If issues occur:"
echo "   ${YELLOW}./troubleshoot-local.sh${NC}"
echo ""

echo -e "${BLUE}🎯 Expected Results${NC}"
echo "=================="
echo ""
echo "After successful deployment:"
echo "✅ Frontend accessible at: http://81.173.84.37:3000"
echo "✅ Backend API at: http://81.173.84.37:8001/api/"
echo "✅ Admin login at: http://81.173.84.37:3000/admin/login"
echo "✅ QR codes will work from mobile devices"
echo "✅ Photos can be uploaded and downloaded"
echo ""

echo -e "${GREEN}🌟 Your QR Photo Upload application is ready to deploy!${NC}"
echo ""
echo "Run this command to start:"
echo -e "${YELLOW}./deploy-local.sh${NC}"
echo ""