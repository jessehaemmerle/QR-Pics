# 🌐 QR Photo Upload - Server IP Configuration Complete

## ✅ **Successfully Updated for Server IP: 81.173.84.37**

### **🔧 Files Modified:**

1. **`docker-compose.local.yml`** - Updated environment variables:
   - `FRONTEND_URL=http://81.173.84.37:3000`
   - `REACT_APP_BACKEND_URL=http://81.173.84.37:8001`

2. **`frontend/.env`** - Updated backend URL:
   - `REACT_APP_BACKEND_URL=http://81.173.84.37:8001`

3. **`frontend/.env.docker`** - Updated backend URL:
   - `REACT_APP_BACKEND_URL=http://81.173.84.37:8001`

4. **`deploy-local.sh`** - Updated all references to use server IP

5. **`troubleshoot-local.sh`** - Updated with firewall configuration and server IP

6. **`start-here.sh`** - Updated with server IP and firewall instructions

### **🆕 New Files Created:**

7. **`setup-firewall.sh`** - Automated firewall configuration script

## 🚀 **Deployment Instructions for Your Server:**

### **Step 1: Configure Firewall (Important!)**
```bash
# Run the firewall setup script
./setup-firewall.sh

# Or manually configure:
# Ubuntu/Debian:
sudo ufw allow 3000
sudo ufw allow 8001
sudo ufw enable

# CentOS/RHEL:
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8001/tcp
sudo firewall-cmd --reload
```

### **Step 2: Deploy Application**
```bash
# Quick deployment
./deploy-local.sh

# Or manual deployment
docker-compose -f docker-compose.local.yml up --build -d
```

### **Step 3: Verify Deployment**
```bash
# Check container status
docker-compose -f docker-compose.local.yml ps

# Test backend API
curl http://81.173.84.37:8001/api/

# Test frontend
curl http://81.173.84.37:3000/health
```

## 🌐 **Access Your Application:**

### **URLs:**
- **Frontend**: http://81.173.84.37:3000
- **Admin Login**: http://81.173.84.37:3000/admin/login
- **Backend API**: http://81.173.84.37:8001/api/

### **Default Credentials:**
- **Username**: `superadmin`
- **Password**: `changeme123`

## 🔥 **Firewall Requirements:**

Your server must have these ports open for external access:
- **Port 3000** - Frontend application
- **Port 8001** - Backend API
- **Port 22** - SSH (recommended to keep open)

## 📱 **QR Code Functionality:**

The QR codes generated will now contain URLs pointing to your server:
- **QR Code URLs**: `http://81.173.84.37:3000/upload/{sessionId}`
- **Mobile users** can scan QR codes from anywhere and access your server
- **Photos uploaded** via mobile will be stored on your server

## 🛠️ **Service Management:**

### **Start Services:**
```bash
docker-compose -f docker-compose.local.yml up -d
```

### **Stop Services:**
```bash
docker-compose -f docker-compose.local.yml down
```

### **Restart Services:**
```bash
docker-compose -f docker-compose.local.yml restart
```

### **View Logs:**
```bash
docker-compose -f docker-compose.local.yml logs -f
```

### **Check Status:**
```bash
docker-compose -f docker-compose.local.yml ps
```

## 🔍 **Troubleshooting:**

### **If Application Not Accessible:**
1. **Run troubleshooting script**: `./troubleshoot-local.sh`
2. **Check firewall**: `sudo ufw status` or `sudo firewall-cmd --list-all`
3. **Verify containers**: `docker-compose -f docker-compose.local.yml ps`
4. **Check logs**: `docker-compose -f docker-compose.local.yml logs`

### **Common Issues:**

#### **1. Cannot Access from External IP**
```bash
# Check firewall
sudo ufw status

# Open required ports
sudo ufw allow 3000
sudo ufw allow 8001

# Check if services are running
docker-compose -f docker-compose.local.yml ps
```

#### **2. Backend API Not Responding**
```bash
# Check backend logs
docker-compose -f docker-compose.local.yml logs backend

# Restart backend
docker-compose -f docker-compose.local.yml restart backend
```

#### **3. Frontend Not Loading**
```bash
# Check frontend logs
docker-compose -f docker-compose.local.yml logs frontend

# Verify environment variables
docker-compose -f docker-compose.local.yml exec frontend env | grep REACT_APP
```

## 🎯 **Testing Your Deployment:**

### **1. Test Admin Interface:**
1. Go to: http://81.173.84.37:3000/admin/login
2. Login with: superadmin / changeme123
3. Create a new session
4. Generate QR code
5. Download QR code

### **2. Test Mobile Upload:**
1. Scan the QR code with your phone
2. Or directly access: http://81.173.84.37:3000/upload/{sessionId}
3. Upload some test photos
4. Verify auto-reload works

### **3. Test Bulk Download:**
1. Go to "View Photos" for your session
2. Select multiple photos
3. Click "Download Selected"
4. Verify ZIP file downloads

## 🌟 **Features Available:**

### **✅ Full Application Features:**
- **User Management** with session restrictions
- **QR Code Generation** with downloadable QR codes
- **Mobile Photo Upload** with auto-reload
- **Bulk Download** of photos as ZIP files
- **Session Management** with multiple sessions
- **Admin Dashboard** with complete control

### **✅ External Access:**
- **Public IP Access** - Accessible from anywhere
- **Mobile QR Scanning** - Works from any device
- **Cross-Platform** - Works on all devices and browsers

## 🎉 **Ready for Production Use:**

Your QR Photo Upload application is now:
- ✅ **Configured for your server IP**
- ✅ **Accessible from external networks**
- ✅ **Ready for mobile QR code scanning**
- ✅ **Fully functional with all features**
- ✅ **Containerized and scalable**

## 📞 **Support Commands:**

```bash
# Quick deployment
./deploy-local.sh

# Firewall setup
./setup-firewall.sh

# Troubleshooting
./troubleshoot-local.sh

# Getting started
./start-here.sh

# Validate setup
./validate-setup.sh
```

**Your QR Photo Upload application is now ready to use on your server at http://81.173.84.37:3000!** 🚀