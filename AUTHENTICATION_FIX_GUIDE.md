# 🔐 Authentication Fix Guide - "Invalid Credentials" Error

## 🔍 **Problem Diagnosis:**
You're getting "Invalid credentials" when trying to login with superadmin/changeme123. This usually means:
1. The superadmin user wasn't created during backend startup
2. The password hash doesn't match
3. Database connection issues during user creation

## 🛠️ **Solution Scripts Created:**

### **1. Complete Diagnosis Script**
```bash
./fix-auth.sh
```
**Purpose**: Diagnoses the authentication issue and attempts automatic fix

### **2. Manual Superadmin Reset**
```bash
./reset-superadmin.sh
```
**Purpose**: Manually creates/resets the superadmin user with correct password hash

### **3. Force Superadmin Creation**
```bash
./force-superadmin.sh
```
**Purpose**: Forces backend restart to trigger superadmin creation

## 🎯 **Recommended Fix Order:**

### **Step 1: Run Authentication Diagnosis**
```bash
./fix-auth.sh
```
This will:
- Check if backend is responding
- Examine backend logs for superadmin creation
- Test database connection
- Check if superadmin user exists
- Attempt to create user manually if missing

### **Step 2: If Still Failing, Reset Superadmin**
```bash
./reset-superadmin.sh
```
This will:
- Remove any existing superadmin user
- Create new superadmin with correct password hash
- Restart backend
- Test login functionality

### **Step 3: If Issues Persist, Force Recreation**
```bash
./force-superadmin.sh
```
This will:
- Clear users collection
- Restart backend to trigger automatic creation
- Monitor startup logs
- Verify user creation

## 🔧 **Manual Database Fix (If Scripts Don't Work):**

### **1. Check Database Connection**
```bash
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.runCommand('ping');
"
```

### **2. Check if User Exists**
```bash
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.find({username: 'superadmin'});
"
```

### **3. Manually Create Superadmin User**
```bash
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.insertOne({
    id: '$(uuidgen)',
    username: 'superadmin',
    password_hash: '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewHEJbFI6GRLUi1O',
    is_superadmin: true,
    allowed_sessions: [],
    created_at: new Date(),
    created_by: 'system'
});
"
```

### **4. Restart Backend**
```bash
docker restart qr-photo-backend
```

## 🧪 **Test Login Manually:**
```bash
curl -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login
```

**Expected Response:**
```json
{
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer"
}
```

## 🔍 **Common Issues & Solutions:**

### **Issue 1: Backend Not Creating Superadmin on Startup**
**Solution**: Run `./force-superadmin.sh` to trigger manual creation

### **Issue 2: Wrong Password Hash**
**Solution**: Use `./reset-superadmin.sh` to set correct bcrypt hash

### **Issue 3: Database Connection Issues**
**Solution**: Check MongoDB logs and restart containers

### **Issue 4: Environment Variables Not Set**
**Solution**: Verify backend container has correct environment variables

## 🎯 **Quick Fix Commands:**

```bash
# Quick diagnosis
./fix-auth.sh

# If that doesn't work, reset superadmin
./reset-superadmin.sh

# Test login
curl -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"changeme123"}' \
    http://81.173.84.37:8001/api/auth/login
```

## 📋 **Verification Steps:**

### **1. Check Backend Logs**
```bash
docker logs qr-photo-backend | grep -i superadmin
```

### **2. Check Database Contents**
```bash
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.find({username: 'superadmin'});
"
```

### **3. Test API Endpoint**
```bash
curl http://81.173.84.37:8001/api/auth/login
```

## 🎉 **After Successful Fix:**

You should be able to:
1. **Login at**: http://81.173.84.37:3000/admin/login
2. **Use credentials**: superadmin / changeme123
3. **Access admin dashboard** and create sessions
4. **Generate QR codes** for photo uploads

## 📞 **If Still Having Issues:**

1. **Check container logs**: `docker logs qr-photo-backend`
2. **Verify MongoDB**: `docker exec qr-photo-mongodb mongosh`
3. **Check network connectivity**: `docker network ls`
4. **Review database contents**: Run diagnosis script

**Start with: `./fix-auth.sh` - This should resolve your authentication issues!** 🔐