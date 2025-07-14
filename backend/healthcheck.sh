#!/bin/sh
# Health check script for backend service

# Check if the API endpoint is responding
if curl -f http://localhost:8001/api/ >/dev/null 2>&1; then
    echo "Backend is healthy"
    exit 0
else
    echo "Backend is not responding"
    exit 1
fi