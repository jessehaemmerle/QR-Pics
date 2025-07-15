# 🚀 Container Startup Issues - Complete Solution

## 🔍 **Diagnosis & Fix Scripts Created:**

I've created comprehensive scripts to diagnose and fix container startup issues:

### **1. Diagnosis Script**
```bash
./diagnose-containers.sh
```
**Purpose**: Comprehensive diagnosis of Docker, ports, resources, and build issues

### **2. Enhanced Deployment Script**
```bash
./deploy-enhanced.sh
```
**Purpose**: Robust deployment with error handling and step-by-step container startup

### **3. Manual Step-by-Step Deployment**
```bash
./deploy-manual.sh
```
**Purpose**: Interactive deployment with manual confirmation at each step

## 🛠️ **Common Issues & Solutions:**

### **Issue 1: Docker Daemon Not Running**
```bash
# Fix:
sudo systemctl start docker
sudo systemctl enable docker
```

### **Issue 2: Port Conflicts**
```bash
# Fix:
sudo fuser -k 3000/tcp
sudo fuser -k 8001/tcp
sudo fuser -k 27017/tcp
```

### **Issue 3: Permission Issues**
```bash
# Fix:
sudo usermod -aG docker $USER
newgrp docker
```

### **Issue 4: Resource Issues**
```bash
# Fix:
docker system prune -f
docker volume prune -f
```

### **Issue 5: Build Failures**
```bash
# Fix:
docker build --no-cache -f Dockerfile.backend -t qr-photo-backend .
docker build --no-cache -f Dockerfile.frontend.simple -t qr-photo-frontend .
```

## 🎯 **Recommended Deployment Order:**

### **Step 1: Run Diagnosis**
```bash
./diagnose-containers.sh
```

### **Step 2: Try Enhanced Deployment**
```bash
./deploy-enhanced.sh
```

### **Step 3: If Issues Persist, Use Manual Deployment**
```bash
./deploy-manual.sh
```

## 🔧 **Manual Container Commands:**

If all scripts fail, try these manual commands:

### **1. Clean Up**
```bash
docker stop qr-photo-frontend qr-photo-backend qr-photo-mongodb
docker rm qr-photo-frontend qr-photo-backend qr-photo-mongodb
docker system prune -f
```

### **2. Create Network**
```bash
docker network create qr-photo-network
```

### **3. Start MongoDB**
```bash
docker run -d \
    --name qr-photo-mongodb \
    --network qr-photo-network \
    -p 27017:27017 \
    -e MONGO_INITDB_DATABASE=qr_photo_db \
    -v mongodb_data:/data/db \
    mongo:7.0
```

### **4. Start Backend**
```bash
docker run -d \
    --name qr-photo-backend \
    --network qr-photo-network \
    -p 8001:8001 \
    -e MONGO_URL=mongodb://qr-photo-mongodb:27017 \
    -e DB_NAME=qr_photo_db \
    -e SECRET_KEY=your-secret-key-change-in-production-docker-abc123def456 \
    -e FRONTEND_URL=http://81.173.84.37:3000 \
    qr-photo-backend
```

### **5. Start Frontend**
```bash
docker run -d \
    --name qr-photo-frontend \
    --network qr-photo-network \
    -p 3000:80 \
    -e REACT_APP_BACKEND_URL=http://81.173.84.37:8001 \
    qr-photo-frontend
```

## 📊 **Verification Commands:**

```bash
# Check container status
docker ps

# Check logs
docker logs qr-photo-mongodb
docker logs qr-photo-backend
docker logs qr-photo-frontend

# Test services
curl http://81.173.84.37:8001/api/
curl http://81.173.84.37:3000/health
```

## 🎉 **Expected Success:**

After successful deployment, you should see:
- ✅ **3 containers running**: mongodb, backend, frontend
- ✅ **Backend API responding**: http://81.173.84.37:8001/api/
- ✅ **Frontend accessible**: http://81.173.84.37:3000
- ✅ **Admin login working**: http://81.173.84.37:3000/admin/login

## 🚨 **If Still Having Issues:**

1. **Run the diagnosis script**: `./diagnose-containers.sh`
2. **Check the detailed logs** in the diagnosis output
3. **Verify firewall settings**: `sudo ufw status`
4. **Check available resources**: `df -h` and `free -h`
5. **Try building images manually** to identify build issues

## 📞 **Quick Debug Commands:**

```bash
# Check if Docker daemon is running
docker info

# Check for port conflicts
sudo netstat -tlnp | grep -E ":(3000|8001|27017)"

# Check Docker Compose version
docker-compose --version
docker compose version

# Check available resources
df -h
free -h
```

**Your containers should now start successfully! Try running `./diagnose-containers.sh` first to identify the specific issue.** 🔧