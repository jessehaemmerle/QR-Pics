# QR Photo Upload - Docker Deployment

This document explains how to deploy the QR Photo Upload application using Docker.

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 2.0 or higher)
- At least 2GB of available RAM
- At least 5GB of available disk space

## Quick Start (Development)

1. **Clone the repository** (if not already done):
   ```bash
   git clone <repository-url>
   cd qr-photo-upload
   ```

2. **Start the application**:
   ```bash
   docker-compose up --build
   ```

3. **Access the application**:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8001
   - Admin Login: http://localhost:3000/admin/login
     - Username: `superadmin`
     - Password: `changeme123`

4. **Stop the application**:
   ```bash
   docker-compose down
   ```

## Production Deployment

For production deployment, use the production configuration:

1. **Update environment variables** in `docker-compose.prod.yml`:
   ```yaml
   environment:
     - MONGO_INITDB_ROOT_PASSWORD=YOUR_STRONG_PASSWORD
     - SECRET_KEY=YOUR_PRODUCTION_SECRET_KEY
     - FRONTEND_URL=https://yourdomain.com
     - REACT_APP_BACKEND_URL=https://yourdomain.com
   ```

2. **Start production services**:
   ```bash
   docker-compose -f docker-compose.prod.yml up --build -d
   ```

3. **Set up SSL certificates** (recommended):
   - Place SSL certificates in `./ssl/` directory
   - Update `nginx.prod.conf` with your SSL configuration

## Docker Services

### Backend Service
- **Container**: `qr-photo-backend`
- **Port**: 8001
- **Technology**: FastAPI + Python
- **Dependencies**: MongoDB

### Frontend Service
- **Container**: `qr-photo-frontend`
- **Port**: 3000 (development) / 80 (production)
- **Technology**: React + Nginx
- **Dependencies**: Backend service

### Database Service
- **Container**: `qr-photo-mongodb`
- **Port**: 27017
- **Technology**: MongoDB 7.0
- **Persistence**: Docker volume `mongodb_data`

## Configuration

### Environment Variables

#### Backend
- `MONGO_URL`: MongoDB connection string
- `DB_NAME`: Database name
- `SECRET_KEY`: JWT secret key
- `FRONTEND_URL`: Frontend URL for CORS

#### Frontend
- `REACT_APP_BACKEND_URL`: Backend API URL

### Volumes

- `mongodb_data`: Persistent storage for MongoDB data
- `./backend:/app`: Backend source code (development only)

### Networks

- `qr-photo-network`: Internal network for service communication

## Docker Commands

### Build and Start
```bash
# Development
docker-compose up --build

# Production (detached)
docker-compose -f docker-compose.prod.yml up --build -d
```

### Stop Services
```bash
# Development
docker-compose down

# Production
docker-compose -f docker-compose.prod.yml down
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f mongodb
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
# Check service health
docker-compose ps

# Backend health
curl http://localhost:8001/api/

# Frontend health
curl http://localhost:3000/health
```

## Troubleshooting

### Common Issues

1. **Port conflicts**:
   ```bash
   # Check if ports are in use
   lsof -i :3000
   lsof -i :8001
   lsof -i :27017
   ```

2. **Permission issues**:
   ```bash
   # Fix file permissions
   chmod +x frontend-entrypoint.sh
   ```

3. **Database connection issues**:
   ```bash
   # Check MongoDB logs
   docker-compose logs mongodb
   
   # Verify network connectivity
   docker exec qr-photo-backend ping mongodb
   ```

4. **Frontend not loading**:
   ```bash
   # Check nginx logs
   docker-compose logs frontend
   
   # Verify backend connectivity
   curl http://localhost:8001/api/
   ```

### Performance Optimization

1. **Increase MongoDB memory**:
   ```yaml
   mongodb:
     deploy:
       resources:
         limits:
           memory: 1G
         reservations:
           memory: 512M
   ```

2. **Enable horizontal scaling**:
   ```bash
   # Scale backend service
   docker-compose up --scale backend=3
   ```

3. **Use production build**:
   ```bash
   # Build optimized images
   docker-compose -f docker-compose.prod.yml build --no-cache
   ```

## Security Considerations

1. **Change default passwords**:
   - Update MongoDB root password
   - Change JWT secret key
   - Update superadmin password

2. **Use HTTPS in production**:
   - Set up SSL certificates
   - Configure nginx for HTTPS

3. **Network security**:
   - Use Docker networks for service isolation
   - Implement rate limiting
   - Configure firewall rules

4. **Data backup**:
   - Regular database backups
   - Backup encryption
   - Offsite storage

## Monitoring

### Health Checks
All services include health checks:
- Backend: `/api/` endpoint
- Frontend: `/health` endpoint
- MongoDB: Connection ping

### Logs
Structured logging is available for all services:
```bash
# Real-time logs
docker-compose logs -f --tail=100

# Export logs
docker-compose logs > application.log
```

## Updates and Maintenance

### Application Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose up --build -d
```

### Database Maintenance
```bash
# MongoDB maintenance
docker exec qr-photo-mongodb mongosh --eval "db.runCommand({compact: 'photos'})"
```

### Cleanup
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Complete cleanup
docker system prune -a --volumes
```

## Support

For issues and questions:
1. Check the logs using `docker-compose logs`
2. Verify all services are healthy using `docker-compose ps`
3. Review this documentation for common solutions
4. Check the main application README for additional information