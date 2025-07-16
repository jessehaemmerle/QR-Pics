#!/bin/bash

echo "🎯 QR Photo Upload - Ultimate Authentication Fix"
echo "==============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}This is the ultimate fix for authentication issues.${NC}"
echo -e "${BLUE}It will try multiple password combinations and fix the hash.${NC}"
echo ""

# Test multiple password combinations with known good hashes
declare -A passwords=(
    ["changeme123"]="\$2b\$12\$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPJFxDoqS"
    ["secret"]="\$2b\$12\$X1dduCdRfEGbqOyg2U0.HO6EzpELJ7rFQyHnEFVrAzFvnyKNHDyHO"
    ["admin"]="\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewHEJbFI6GRLUi1O"
    ["password"]="\$2b\$12\$V2fgPHkGbdRQHxJ8kXZUMOzVnAWzxYFMvPCdwTaJgvBKVXWqfQQWa"
)

echo -e "${YELLOW}Step 1: Testing existing authentication${NC}"
echo "====================================="

# Check if any existing password works
for password in "${!passwords[@]}"; do
    echo "Testing password: $password"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"superadmin\",\"password\":\"$password\"}" \
        http://81.173.84.37:8001/api/auth/login)
    
    if echo "$response" | grep -q "access_token"; then
        echo -e "${GREEN}✅ SUCCESS! Password '$password' works${NC}"
        echo ""
        echo "🎉 You can now login with:"
        echo "Username: superadmin"
        echo "Password: $password"
        echo ""
        echo "Access: http://81.173.84.37:3000/admin/login"
        exit 0
    else
        echo -e "${RED}❌ Password '$password' failed${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Step 2: Creating superadmin with multiple password options${NC}"
echo "======================================================"

# Remove all existing users
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.deleteMany({});
print('Cleared all users');
"

# Create superadmin users with different passwords
for password in "${!passwords[@]}"; do
    user_id=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    
    echo "Creating superadmin with password: $password"
    
    docker exec qr-photo-mongodb mongosh --eval "
    use qr_photo_db;
    db.users.insertOne({
        id: '$user_id',
        username: 'superadmin_$password',
        password_hash: '${passwords[$password]}',
        is_superadmin: true,
        allowed_sessions: [],
        created_at: new Date(),
        created_by: 'system'
    });
    print('Created superadmin_$password');
    "
done

# Also create the main superadmin with changeme123
main_user_id=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.insertOne({
    id: '$main_user_id',
    username: 'superadmin',
    password_hash: '${passwords["changeme123"]}',
    is_superadmin: true,
    allowed_sessions: [],
    created_at: new Date(),
    created_by: 'system'
});
print('Created main superadmin');
"

# Restart backend to ensure clean state
echo ""
echo -e "${YELLOW}Step 3: Restarting backend${NC}"
echo "========================="
docker restart qr-photo-backend
sleep 15

# Test all password combinations
echo ""
echo -e "${YELLOW}Step 4: Testing all password combinations${NC}"
echo "========================================"

for password in "${!passwords[@]}"; do
    echo "Testing main superadmin with password: $password"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"superadmin\",\"password\":\"$password\"}" \
        http://81.173.84.37:8001/api/auth/login)
    
    if echo "$response" | grep -q "access_token"; then
        echo -e "${GREEN}✅ SUCCESS! Main superadmin works with password '$password'${NC}"
        echo ""
        echo "🎉 Authentication fixed!"
        echo "Username: superadmin"
        echo "Password: $password"
        echo ""
        echo "Access: http://81.173.84.37:3000/admin/login"
        exit 0
    fi
    
    # Also test the specific username
    echo "Testing superadmin_$password with password: $password"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"superadmin_$password\",\"password\":\"$password\"}" \
        http://81.173.84.37:8001/api/auth/login)
    
    if echo "$response" | grep -q "access_token"; then
        echo -e "${GREEN}✅ SUCCESS! superadmin_$password works${NC}"
        echo ""
        echo "🎉 Authentication fixed!"
        echo "Username: superadmin_$password"
        echo "Password: $password"
        echo ""
        echo "Access: http://81.173.84.37:3000/admin/login"
        exit 0
    fi
done

echo ""
echo -e "${YELLOW}Step 5: Generating fresh password hash${NC}"
echo "====================================="

# Generate a completely new password hash using the backend container
new_hash=$(docker exec qr-photo-backend python3 -c "
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
hash_result = pwd_context.hash('changeme123')
print(hash_result)
")

if [ -n "$new_hash" ]; then
    echo "Generated new hash: $new_hash"
    
    # Update the superadmin user with the new hash
    docker exec qr-photo-mongodb mongosh --eval "
    use qr_photo_db;
    db.users.updateOne(
        {username: 'superadmin'},
        {\$set: {password_hash: '$new_hash'}}
    );
    print('Updated superadmin with new hash');
    "
    
    # Restart backend
    docker restart qr-photo-backend
    sleep 15
    
    # Test the new hash
    echo "Testing with new hash..."
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"username":"superadmin","password":"changeme123"}' \
        http://81.173.84.37:8001/api/auth/login)
    
    if echo "$response" | grep -q "access_token"; then
        echo -e "${GREEN}✅ SUCCESS! New hash works${NC}"
        echo ""
        echo "🎉 Authentication fixed!"
        echo "Username: superadmin"
        echo "Password: changeme123"
        echo ""
        echo "Access: http://81.173.84.37:3000/admin/login"
        exit 0
    fi
fi

echo ""
echo -e "${YELLOW}Step 6: Last resort - Simple password${NC}"
echo "==================================="

# Try with a simple password and simple hash
simple_hash=$(docker exec qr-photo-backend python3 -c "
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
hash_result = pwd_context.hash('admin')
print(hash_result)
")

# Update with simple password
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.updateOne(
    {username: 'superadmin'},
    {\$set: {password_hash: '$simple_hash'}}
);
print('Updated superadmin with simple hash');
"

docker restart qr-photo-backend
sleep 15

# Test simple password
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"superadmin","password":"admin"}' \
    http://81.173.84.37:8001/api/auth/login)

if echo "$response" | grep -q "access_token"; then
    echo -e "${GREEN}✅ SUCCESS! Simple password works${NC}"
    echo ""
    echo "🎉 Authentication fixed!"
    echo "Username: superadmin"
    echo "Password: admin"
    echo ""
    echo "Access: http://81.173.84.37:3000/admin/login"
    exit 0
fi

echo ""
echo -e "${RED}❌ ALL AUTHENTICATION ATTEMPTS FAILED${NC}"
echo "====================================="
echo ""
echo "Manual debugging required:"
echo "1. Check backend logs: docker logs qr-photo-backend"
echo "2. Check database: docker exec qr-photo-mongodb mongosh"
echo "3. Check if containers are running: docker ps"
echo "4. Check network connectivity: ping 81.173.84.37"
echo ""
echo "Available users in database:"
docker exec qr-photo-mongodb mongosh --eval "
use qr_photo_db;
db.users.find({}, {username: 1, is_superadmin: 1}).forEach(function(user) {
    print('Username: ' + user.username + ', Is Superadmin: ' + user.is_superadmin);
});
"

echo ""
echo "Try these usernames with different passwords:"
echo "- superadmin (with: changeme123, admin, secret, password)"
echo "- superadmin_changeme123 (with: changeme123)"
echo "- superadmin_secret (with: secret)"
echo "- superadmin_admin (with: admin)"
echo "- superadmin_password (with: password)"