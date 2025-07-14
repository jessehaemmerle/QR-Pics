#!/bin/sh

# Replace environment variables in JavaScript files
if [ -n "$REACT_APP_BACKEND_URL" ]; then
    # Replace the backend URL in the built JavaScript files
    find /usr/share/nginx/html -name "*.js" -exec sed -i "s|REACT_APP_BACKEND_URL_PLACEHOLDER|$REACT_APP_BACKEND_URL|g" {} \;
fi

# Start nginx
exec "$@"