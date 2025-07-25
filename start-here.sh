#!/bin/bash

echo "======================================"
echo "🎯 QR Photo Upload - Server 81.173.84.37 Setup"
echo "======================================"
echo ""

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 DEPLOYMENT SUMMARY${NC}"
echo "===================="
echo ""
echo "✅ Issues Fixed:"
echo "   - Docker Compose configuration simplified"
echo "   - Frontend build issues resolved"
echo "   - Service communication improved"
echo "   - Port mapping corrected"
echo "   - Environment variables fixed"
echo "   - Updated for server IP: 81.173.84.37"
echo ""
echo "📁 New Files Created:"
echo "   - docker-compose.local.yml (configured for server IP)"
echo "   - Dockerfile.frontend.simple (simplified frontend build)"
echo "   - nginx.simple.conf (basic nginx config)"
echo "   - deploy-local.sh (deployment script)"
echo "   - troubleshoot-local.sh (troubleshooting script)"
echo ""
echo -e "${GREEN}🚀 DEPLOYMENT INSTRUCTIONS${NC}"
echo "=========================="
echo ""
echo "1. Quick Deployment:"
echo "   ./deploy-local.sh"
echo ""
echo "2. Manual Deployment:"
echo "   docker-compose -f docker-compose.local.yml up --build -d"
echo ""
echo "3. Verify Deployment:"
echo "   curl http://81.173.84.37:8001/api/"
echo "   curl http://81.173.84.37:3000/health"
echo ""
echo -e "${YELLOW}📱 ACCESS INFORMATION${NC}"
echo "====================="
echo ""
echo "Frontend:    http://81.173.84.37:3000"
echo "Admin Login: http://81.173.84.37:3000/admin/login"
echo "Backend API: http://81.173.84.37:8001/api/"
echo ""
echo "Default Credentials:"
echo "Username: superadmin"
echo "Password: changeme123"
echo ""
echo -e "${BLUE}🔧 TROUBLESHOOTING${NC}"
echo "=================="
echo ""
echo "If deployment fails:"
echo "1. Run: ./troubleshoot-local.sh"
echo "2. Check logs: docker-compose -f docker-compose.local.yml logs"
echo "3. Verify ports are free: netstat -tlnp | grep -E ':(3000|8001|27017)'"
echo "4. Check firewall: sudo ufw status"
echo "5. Open ports: sudo ufw allow 3000 && sudo ufw allow 8001"
echo ""
echo -e "${RED}🔥 IMPORTANT FIREWALL SETTINGS${NC}"
echo "=============================="
echo ""
echo "Make sure these ports are open on your server:"
echo "  - Port 3000 (Frontend)"
echo "  - Port 8001 (Backend)"
echo ""
echo "Ubuntu/Debian:"
echo "  sudo ufw allow 3000"
echo "  sudo ufw allow 8001"
echo ""
echo "CentOS/RHEL:"
echo "  sudo firewall-cmd --permanent --add-port=3000/tcp"
echo "  sudo firewall-cmd --permanent --add-port=8001/tcp"
echo "  sudo firewall-cmd --reload"
echo ""
echo -e "${GREEN}🎉 READY TO DEPLOY!${NC}"
echo ""
echo "Your QR Photo Upload app will be accessible from anywhere at:"
echo -e "${YELLOW}http://81.173.84.37:3000${NC}"
echo ""
echo "Run this command to start your application:"
echo -e "${YELLOW}./deploy-local.sh${NC}"
echo ""