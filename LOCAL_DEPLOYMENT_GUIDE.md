# 🚀 QR Photo Upload - Local Server Deployment Guide

## ✅ **Issues Fixed:**

### **1. Docker Compose Configuration**
- **Problem**: Complex nginx proxy setup causing connection issues
- **Solution**: Created simplified `docker-compose.local.yml` with direct port mapping

### **2. Frontend Build Issues**
- **Problem**: Yarn lockfile conflicts and complex environment handling
- **Solution**: Simplified Dockerfile and nginx configuration

### **3. Service Communication**
- **Problem**: Internal network communication issues
- **Solution**: Direct port exposure for local development

## 🛠️ **New Local Deployment Files:**

### **Created Files:**
- `docker-compose.local.yml` - Simplified Docker Compose for local development
- `Dockerfile.frontend.simple` - Simplified frontend Dockerfile
- `nginx.simple.conf` - Basic nginx configuration
- `deploy-local.sh` - Local deployment script
- `troubleshoot-local.sh` - Troubleshooting script

## 🚀 **How to Deploy on Your Local Server:**

### **Step 1: Use the Local Deployment Script**
```bash
./deploy-local.sh
```

### **Step 2: Manual Deployment (if script fails)**
```bash
# If you have docker-compose (with hyphen):
docker-compose -f docker-compose.local.yml up --build -d

# If you have docker compose (without hyphen):
docker compose -f docker-compose.local.yml up --build -d
```

### **Step 3: Verify Deployment**
```bash
# Check container status
docker-compose -f docker-compose.local.yml ps

# Test services
curl http://localhost:8001/api/     # Should return {"message":"QR Photo Upload API"}
curl http://localhost:3000/health   # Should return "healthy"
```

## 🔍 **Troubleshooting:**

### **If deployment fails, run:**
```bash
./troubleshoot-local.sh
```

### **Common Issues & Solutions:**

#### **1. Port Conflicts**
```bash
# Check what's using the ports
sudo netstat -tlnp | grep :3000
sudo netstat -tlnp | grep :8001
sudo netstat -tlnp | grep :27017

# Kill conflicting processes
sudo kill -9 <process_id>
```

#### **2. Docker Permission Issues**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo
sudo ./deploy-local.sh
```

#### **3. Build Failures**
```bash
# Clean Docker cache
docker system prune -a

# Force rebuild
docker-compose -f docker-compose.local.yml build --no-cache
```

#### **4. Service Not Starting**
```bash
# Check logs
docker-compose -f docker-compose.local.yml logs backend
docker-compose -f docker-compose.local.yml logs frontend
docker-compose -f docker-compose.local.yml logs mongodb

# Restart services
docker-compose -f docker-compose.local.yml restart
```

## 📱 **After Successful Deployment:**

### **Access URLs:**
- **Frontend**: http://localhost:3000
- **Admin Login**: http://localhost:3000/admin/login
- **Backend API**: http://localhost:8001/api/

### **Default Credentials:**
- **Username**: `superadmin`
- **Password**: `changeme123`

### **Test the Application:**
1. **Login**: Go to http://localhost:3000/admin/login
2. **Create Session**: Click "New Session"
3. **Generate QR Code**: Click "Generate QR Code"
4. **Test Upload**: Scan QR code with phone or access upload URL directly
5. **Test Bulk Download**: Upload some photos and test bulk download

## 🎛️ **Service Management:**

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
# All services
docker-compose -f docker-compose.local.yml logs -f

# Specific service
docker-compose -f docker-compose.local.yml logs -f backend
```

### **Update Application:**
```bash
# Stop services
docker-compose -f docker-compose.local.yml down

# Rebuild and start
docker-compose -f docker-compose.local.yml up --build -d
```

## 📊 **Expected Behavior:**

### **Successful Deployment Output:**
```
🚀 Starting QR Photo Upload LOCAL deployment...
✅ Using Docker Compose command: docker compose
🛑 Stopping existing containers...
🧹 Cleaning up...
🔨 Building and starting services...
⏳ Waiting for services to initialize...
🔍 Checking service status...
✅ Backend API is responding
✅ Frontend is responding
🎉 QR Photo Upload LOCAL deployment complete!
```

### **Container Status:**
```bash
$ docker-compose -f docker-compose.local.yml ps
NAME                   COMMAND                  SERVICE             STATUS              PORTS
qr-photo-backend       "uvicorn server:app …"   backend             running             0.0.0.0:8001->8001/tcp
qr-photo-frontend      "/docker-entrypoint.…"   frontend            running             0.0.0.0:3000->80/tcp
qr-photo-mongodb       "docker-entrypoint.s…"   mongodb             running             0.0.0.0:27017->27017/tcp
```

## 🔧 **Configuration Details:**

### **Port Mapping:**
- **Frontend**: localhost:3000 → container:80
- **Backend**: localhost:8001 → container:8001
- **MongoDB**: localhost:27017 → container:27017

### **Environment Variables:**
- **Backend**: Direct MongoDB connection, proper secret key
- **Frontend**: Direct backend API connection at localhost:8001
- **MongoDB**: Initialized with proper database name

### **Network Configuration:**
- **Internal Network**: `qr-photo-network` for service communication
- **External Access**: Direct port mapping for local development

## 🎯 **Key Improvements:**

1. **Simplified Architecture**: Removed complex nginx proxy setup
2. **Direct Port Mapping**: Services accessible directly on localhost
3. **Better Error Handling**: Comprehensive logging and troubleshooting
4. **Local Development Focus**: Optimized for local development workflow
5. **Easy Debugging**: Simple log access and service management

## 🚨 **Important Notes:**

1. **Use Local Configuration**: Always use `docker-compose.local.yml` for local development
2. **Port Availability**: Ensure ports 3000, 8001, and 27017 are available
3. **Docker Permissions**: Make sure your user has Docker permissions
4. **Service Dependencies**: Services start in correct order (MongoDB → Backend → Frontend)

## 📞 **Support:**

If you still encounter issues:
1. **Run troubleshooting script**: `./troubleshoot-local.sh`
2. **Check logs**: `docker-compose -f docker-compose.local.yml logs`
3. **Verify ports**: `netstat -tlnp | grep -E ":(3000|8001|27017)"`
4. **Check Docker status**: `docker ps`

**Your QR Photo Upload application should now work perfectly on your local server!** 🎉