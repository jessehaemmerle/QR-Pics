// MongoDB initialization script
db = db.getSiblingDB('qr_photo_db');

// Create collections
db.createCollection('users');
db.createCollection('sessions');
db.createCollection('photos');

// Create indexes for better performance
db.users.createIndex({ "username": 1 }, { unique: true });
db.sessions.createIndex({ "created_by": 1 });
db.sessions.createIndex({ "created_at": -1 });
db.sessions.createIndex({ "is_active": 1 });
db.photos.createIndex({ "session_id": 1 });
db.photos.createIndex({ "uploaded_at": -1 });

print('Database initialized successfully');