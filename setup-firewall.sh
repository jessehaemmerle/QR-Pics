#!/bin/bash

echo "🔥 QR Photo Upload - Firewall Configuration for Server 81.173.84.37"
echo "=================================================================="
echo ""

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Checking current firewall status...${NC}"
echo ""

# Check if UFW is installed and active
if command -v ufw &> /dev/null; then
    echo "✅ UFW is installed"
    echo "Current UFW status:"
    sudo ufw status
    echo ""
    
    echo -e "${YELLOW}📋 Required ports for QR Photo Upload:${NC}"
    echo "  - Port 3000 (Frontend)"
    echo "  - Port 8001 (Backend)"
    echo "  - Port 22 (SSH - recommended to keep open)"
    echo ""
    
    read -p "Do you want to configure UFW firewall? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}🔧 Configuring UFW firewall...${NC}"
        
        # Enable UFW if not already enabled
        echo "Enabling UFW..."
        sudo ufw --force enable
        
        # Allow SSH (important to not lock yourself out)
        echo "Allowing SSH (port 22)..."
        sudo ufw allow ssh
        
        # Allow required ports
        echo "Allowing port 3000 (Frontend)..."
        sudo ufw allow 3000
        
        echo "Allowing port 8001 (Backend)..."
        sudo ufw allow 8001
        
        # Show final status
        echo ""
        echo -e "${GREEN}✅ Firewall configuration complete!${NC}"
        echo "Final UFW status:"
        sudo ufw status
    fi
    
elif command -v firewall-cmd &> /dev/null; then
    echo "✅ Firewalld is installed"
    echo "Current firewall zones:"
    sudo firewall-cmd --list-all
    echo ""
    
    echo -e "${YELLOW}📋 Required ports for QR Photo Upload:${NC}"
    echo "  - Port 3000 (Frontend)"
    echo "  - Port 8001 (Backend)"
    echo "  - Port 22 (SSH - recommended to keep open)"
    echo ""
    
    read -p "Do you want to configure firewalld? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}🔧 Configuring firewalld...${NC}"
        
        # Allow required ports
        echo "Allowing port 3000 (Frontend)..."
        sudo firewall-cmd --permanent --add-port=3000/tcp
        
        echo "Allowing port 8001 (Backend)..."
        sudo firewall-cmd --permanent --add-port=8001/tcp
        
        # Reload firewall
        echo "Reloading firewall..."
        sudo firewall-cmd --reload
        
        # Show final status
        echo ""
        echo -e "${GREEN}✅ Firewall configuration complete!${NC}"
        echo "Active firewall rules:"
        sudo firewall-cmd --list-all
    fi
    
else
    echo -e "${YELLOW}⚠️  No common firewall detected (UFW or firewalld)${NC}"
    echo ""
    echo "Manual firewall configuration may be needed."
    echo "Please ensure these ports are open:"
    echo "  - Port 3000 (Frontend)"
    echo "  - Port 8001 (Backend)"
    echo ""
    echo "Common commands for other firewalls:"
    echo "  iptables: sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT"
    echo "           sudo iptables -A INPUT -p tcp --dport 8001 -j ACCEPT"
fi

echo ""
echo -e "${BLUE}🧪 Testing port accessibility...${NC}"
echo ""

# Test if ports are open
echo "Testing port 3000..."
if netstat -tuln | grep -q ":3000 "; then
    echo "✅ Port 3000 is bound (application is running)"
else
    echo "❌ Port 3000 is not bound (application not running or blocked)"
fi

echo "Testing port 8001..."
if netstat -tuln | grep -q ":8001 "; then
    echo "✅ Port 8001 is bound (application is running)"
else
    echo "❌ Port 8001 is not bound (application not running or blocked)"
fi

echo ""
echo -e "${GREEN}🌐 External Access Test${NC}"
echo "======================"
echo ""
echo "After configuring the firewall, your QR Photo Upload app should be accessible at:"
echo -e "${YELLOW}http://81.173.84.37:3000${NC}"
echo ""
echo "You can test external access by opening this URL in a browser from another device."
echo ""
echo "If the app is not accessible externally, check:"
echo "1. Firewall configuration (this script)"
echo "2. Cloud provider security groups (if applicable)"
echo "3. Router/network configuration"
echo "4. Application is running: docker-compose -f docker-compose.local.yml ps"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "1. Configure firewall (if not done above)"
echo "2. Deploy the application: ./deploy-local.sh"
echo "3. Test access: http://81.173.84.37:3000"
echo ""