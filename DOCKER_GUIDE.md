# QR Photo Upload - Docker Setup

This application is now fully containerized and ready for deployment using Docker!

## 🚀 Quick Start

### Prerequisites
- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 10GB disk space

### Start the Application

```bash
# Simple start (development)
./deploy.sh

# Or manually:
docker-compose up --build

# Production deployment
./deploy.sh --environment production --detached --build
```

### Access the Application
- **Frontend**: http://localhost:3000
- **Admin Login**: http://localhost:3000/admin/login
- **Backend API**: http://localhost:8001/api/

### Default Credentials
- **Username**: `superadmin`
- **Password**: `changeme123`

## 🐳 Docker Architecture

### Services

1. **Frontend Container**
   - **Image**: nginx:alpine + React build
   - **Port**: 3000
   - **Features**: Production-optimized, GZIP compression, caching

2. **Backend Container**
   - **Image**: python:3.11-slim + FastAPI
   - **Port**: 8001
   - **Features**: JWT auth, QR generation, photo upload

3. **MongoDB Container**
   - **Image**: mongo:7.0
   - **Port**: 27017
   - **Features**: Persistent data, indexes, health checks

### Networks
- Internal Docker network for service communication
- Only frontend and backend exposed to host

### Volumes
- `mongodb_data`: Persistent database storage
- Source code mounting (development only)

## 📋 Deployment Options

### Development
```bash
# Start with live reload
docker-compose up

# Background mode
docker-compose up -d

# Rebuild images
docker-compose up --build
```

### Production
```bash
# Production config
docker-compose -f docker-compose.prod.yml up -d

# With SSL and custom domain
# Edit docker-compose.prod.yml first
docker-compose -f docker-compose.prod.yml up -d
```

## 🔧 Configuration

### Environment Variables

#### Backend (.env)
```
MONGO_URL=mongodb://mongodb:27017
DB_NAME=qr_photo_db
SECRET_KEY=your-secret-key-here
FRONTEND_URL=http://localhost:3000
```

#### Frontend (.env.docker)
```
REACT_APP_BACKEND_URL=http://localhost:8001
GENERATE_SOURCEMAP=false
```

### Docker Compose Files

1. **docker-compose.yml** - Development setup
2. **docker-compose.prod.yml** - Production setup with security
3. **nginx.conf** - Nginx configuration for production
4. **mongo-init.js** - MongoDB initialization script

## 🛠️ Management Commands

### Service Management
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart specific service
docker-compose restart backend

# View logs
docker-compose logs -f backend

# Scale services
docker-compose up --scale backend=3
```

### Database Management
```bash
# Connect to MongoDB
docker exec -it qr-photo-mongodb mongosh

# Backup database
docker exec qr-photo-mongodb mongodump --out /tmp/backup
docker cp qr-photo-mongodb:/tmp/backup ./backup

# Restore database
docker cp ./backup qr-photo-mongodb:/tmp/backup
docker exec qr-photo-mongodb mongorestore /tmp/backup
```

### Health Checks
```bash
# Check all services
docker-compose ps

# Test backend
curl http://localhost:8001/api/

# Test frontend
curl http://localhost:3000/health
```

## 🔐 Security Features

### Production Security
- Rate limiting on API endpoints
- CORS protection
- Security headers
- JWT authentication
- Input validation
- File upload limits

### Recommended Production Setup
1. Use HTTPS with SSL certificates
2. Configure firewall rules
3. Use strong passwords
4. Enable database authentication
5. Regular security updates

## 📊 Monitoring

### Health Checks
All services include health checks:
- **Backend**: `/api/` endpoint check
- **Frontend**: `/health` endpoint
- **MongoDB**: Connection ping

### Logging
```bash
# View all logs
docker-compose logs

# Follow logs
docker-compose logs -f

# Specific service logs
docker-compose logs backend
```

## 🚀 Production Deployment

### 1. Server Setup
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Application Deployment
```bash
# Clone repository
git clone <your-repo-url>
cd qr-photo-upload

# Configure environment
cp docker-compose.prod.yml docker-compose.yml
# Edit environment variables

# Deploy
./deploy.sh --environment production --detached --build
```

### 3. SSL Setup (Optional)
```bash
# Install certbot
sudo apt-get install certbot

# Generate certificates
sudo certbot certonly --standalone -d yourdomain.com

# Update nginx configuration
# Copy certificates to ./ssl/ directory
# Uncomment SSL configuration in nginx.prod.conf
```

### 4. Domain Configuration
Update your domain's DNS to point to your server IP address.

## 🔧 Troubleshooting

### Common Issues

1. **Port conflicts**
   ```bash
   # Check port usage
   sudo netstat -tlnp | grep :3000
   sudo netstat -tlnp | grep :8001
   ```

2. **Database connection**
   ```bash
   # Check MongoDB container
   docker-compose logs mongodb
   
   # Test connection
   docker exec qr-photo-mongodb mongosh --eval "db.runCommand('ping')"
   ```

3. **Permission issues**
   ```bash
   # Fix file permissions
   sudo chown -R $USER:$USER .
   chmod +x deploy.sh
   chmod +x frontend-entrypoint.sh
   ```

4. **Image build failures**
   ```bash
   # Clean build cache
   docker builder prune -a
   
   # Rebuild without cache
   docker-compose build --no-cache
   ```

### Performance Optimization

1. **Resource limits**
   ```yaml
   services:
     backend:
       deploy:
         resources:
           limits:
             memory: 512M
             cpus: 0.5
   ```

2. **Caching**
   - Enable Redis for session storage
   - Configure nginx caching
   - Use CDN for static assets

3. **Database optimization**
   - MongoDB indexes (already included)
   - Connection pooling
   - Query optimization

## 🔄 Updates and Maintenance

### Application Updates
```bash
# Pull latest changes
git pull origin main

# Update and restart
docker-compose down
docker-compose up --build -d
```

### System Maintenance
```bash
# Clean unused images
docker image prune -a

# Clean unused volumes
docker volume prune

# System cleanup
docker system prune -a --volumes
```

## 📋 Backup Strategy

### Database Backup
```bash
# Automated backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec qr-photo-mongodb mongodump --out /tmp/backup_$DATE
docker cp qr-photo-mongodb:/tmp/backup_$DATE ./backups/
```

### Full System Backup
```bash
# Backup volumes
docker run --rm -v mongodb_data:/data -v $(pwd):/backup alpine tar czf /backup/mongodb_backup.tar.gz /data

# Backup application
tar czf app_backup.tar.gz --exclude=node_modules --exclude=__pycache__ .
```

## 🎯 Next Steps

1. **Production Setup**
   - Configure SSL certificates
   - Set up monitoring
   - Configure backups

2. **Scaling**
   - Load balancer setup
   - Database replication
   - CDN integration

3. **Security**
   - Security audit
   - Penetration testing
   - Regular updates

## 📞 Support

For issues:
1. Check logs: `docker-compose logs`
2. Verify health: `docker-compose ps`
3. Review this documentation
4. Check the main README.md

---

**The application is now fully containerized and production-ready!** 🎉