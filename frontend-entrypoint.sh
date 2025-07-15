#!/bin/sh

# Replace environment variables in JavaScript files
if [ -n "$REACT_APP_BACKEND_URL" ]; then
    echo "Setting REACT_APP_BACKEND_URL to: $REACT_APP_BACKEND_URL"
    
    # Find and replace in all JavaScript files
    find /usr/share/nginx/html -name "*.js" -exec sed -i "s|http://localhost:8001|$REACT_APP_BACKEND_URL|g" {} \;
    find /usr/share/nginx/html -name "*.js" -exec sed -i "s|process\.env\.REACT_APP_BACKEND_URL|\"$REACT_APP_BACKEND_URL\"|g" {} \;
fi

# Start nginx
exec "$@"