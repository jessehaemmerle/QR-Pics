from fastapi import FastAPI, APIRouter, HTTPException, Depends, UploadFile, File, Form
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional
import uuid
from datetime import datetime, timedelta
import qrcode
import io
import base64
import jwt
from passlib.context import CryptContext
import json
import zipfile
import tempfile
from fastapi.responses import StreamingResponse

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Security
SECRET_KEY = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# Create the main app without a prefix
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# Models
class User(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    username: str
    password_hash: str
    is_superadmin: bool = False
    allowed_sessions: List[str] = []  # Empty list means access to all sessions
    created_at: datetime = Field(default_factory=datetime.utcnow)
    created_by: str = ""  # ID of user who created this user

class UserCreate(BaseModel):
    username: str
    password: str
    is_superadmin: bool = False
    allowed_sessions: List[str] = []

class UserUpdate(BaseModel):
    username: Optional[str] = None
    password: Optional[str] = None
    is_superadmin: Optional[bool] = None
    allowed_sessions: Optional[List[str]] = None

class UserLogin(BaseModel):
    username: str
    password: str

class Session(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    created_by: str  # user id
    is_active: bool = True

class SessionCreate(BaseModel):
    name: str
    description: Optional[str] = None

class Photo(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    session_id: str
    filename: str
    content_type: str
    image_data: str  # base64 encoded
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    file_size: int

class PhotoUpload(BaseModel):
    session_id: str
    filename: str
    content_type: str
    image_data: str
    file_size: int

class Token(BaseModel):
    access_token: str
    token_type: str

# Utility functions
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        user = await db.users.find_one({"username": username})
        if user is None:
            raise HTTPException(status_code=401, detail="User not found")
        return User(**user)
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def get_current_superadmin(current_user: User = Depends(get_current_user)):
    if not current_user.is_superadmin:
        raise HTTPException(status_code=403, detail="Superadmin access required")
    return current_user

async def check_session_access(session_id: str, current_user: User = Depends(get_current_user)):
    """Check if user has access to a specific session"""
    if current_user.is_superadmin:
        return True  # Superadmins have access to all sessions
    
    if not current_user.allowed_sessions:
        return True  # Empty list means access to all sessions
    
    if session_id not in current_user.allowed_sessions:
        raise HTTPException(status_code=403, detail="Access denied to this session")
    
    return True

def generate_qr_code(data: str) -> str:
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    img_str = base64.b64encode(buffer.getvalue()).decode()
    return img_str

# Initialize superadmin on startup
async def create_initial_superadmin():
    existing_superadmin = await db.users.find_one({"is_superadmin": True})
    if not existing_superadmin:
        superadmin = User(
            username="superadmin",
            password_hash=get_password_hash("changeme123"),
            is_superadmin=True,
            allowed_sessions=[],  # Superadmin has access to all sessions
            created_by="system"
        )
        await db.users.insert_one(superadmin.dict())
        logger.info("Created initial superadmin user (username: superadmin, password: changeme123)")

# Routes
@api_router.get("/")
async def root():
    return {"message": "QR Photo Upload API"}

# Auth routes
@api_router.post("/auth/login", response_model=Token)
async def login(user_login: UserLogin):
    user = await db.users.find_one({"username": user_login.username})
    if not user or not verify_password(user_login.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token_expires = timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    access_token = create_access_token(
        data={"sub": user["username"]}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@api_router.get("/auth/me", response_model=User)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    return current_user

# User management routes (superadmin only)
@api_router.post("/users", response_model=User)
async def create_user(user_create: UserCreate, current_user: User = Depends(get_current_superadmin)):
    # Check if user already exists
    existing_user = await db.users.find_one({"username": user_create.username})
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # Validate session access if allowed_sessions is specified
    if user_create.allowed_sessions:
        for session_id in user_create.allowed_sessions:
            session = await db.sessions.find_one({"id": session_id})
            if not session:
                raise HTTPException(status_code=400, detail=f"Session {session_id} not found")
    
    user = User(
        username=user_create.username,
        password_hash=get_password_hash(user_create.password),
        is_superadmin=user_create.is_superadmin,
        allowed_sessions=user_create.allowed_sessions,
        created_by=current_user.id
    )
    await db.users.insert_one(user.dict())
    return user

@api_router.get("/users", response_model=List[User])
async def get_users(current_user: User = Depends(get_current_superadmin)):
    users = await db.users.find().to_list(1000)
    return [User(**user) for user in users]

@api_router.put("/users/{user_id}", response_model=User)
async def update_user(user_id: str, user_update: UserUpdate, current_user: User = Depends(get_current_superadmin)):
    existing_user = await db.users.find_one({"id": user_id})
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prepare update data
    update_data = {}
    if user_update.username is not None:
        # Check if username already exists
        if user_update.username != existing_user["username"]:
            existing_username = await db.users.find_one({"username": user_update.username})
            if existing_username:
                raise HTTPException(status_code=400, detail="Username already exists")
        update_data["username"] = user_update.username
    
    if user_update.password is not None:
        update_data["password_hash"] = get_password_hash(user_update.password)
    
    if user_update.is_superadmin is not None:
        update_data["is_superadmin"] = user_update.is_superadmin
    
    if user_update.allowed_sessions is not None:
        # Validate session access if allowed_sessions is specified
        if user_update.allowed_sessions:
            for session_id in user_update.allowed_sessions:
                session = await db.sessions.find_one({"id": session_id})
                if not session:
                    raise HTTPException(status_code=400, detail=f"Session {session_id} not found")
        update_data["allowed_sessions"] = user_update.allowed_sessions
    
    # Update user
    await db.users.update_one({"id": user_id}, {"$set": update_data})
    
    # Return updated user
    updated_user = await db.users.find_one({"id": user_id})
    return User(**updated_user)

@api_router.delete("/users/{user_id}")
async def delete_user(user_id: str, current_user: User = Depends(get_current_superadmin)):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    
    result = await db.users.delete_one({"id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="User not found")
    return {"message": "User deleted successfully"}

# Session management routes
@api_router.post("/sessions", response_model=Session)
async def create_session(session_create: SessionCreate, current_user: User = Depends(get_current_user)):
    session = Session(
        name=session_create.name,
        description=session_create.description,
        created_by=current_user.id
    )
    await db.sessions.insert_one(session.dict())
    return session

@api_router.get("/sessions", response_model=List[Session])
async def get_sessions(current_user: User = Depends(get_current_user)):
    # If user is superadmin or has no session restrictions, return all sessions
    if current_user.is_superadmin or not current_user.allowed_sessions:
        sessions = await db.sessions.find({"is_active": True}).to_list(1000)
    else:
        # Return only sessions the user has access to
        sessions = await db.sessions.find({
            "id": {"$in": current_user.allowed_sessions},
            "is_active": True
        }).to_list(1000)
    
    return [Session(**session) for session in sessions]

@api_router.get("/sessions/{session_id}", response_model=Session)
async def get_session(session_id: str, current_user: User = Depends(get_current_user)):
    # Check session access
    await check_session_access(session_id, current_user)
    
    session = await db.sessions.find_one({"id": session_id})
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return Session(**session)

@api_router.get("/sessions/{session_id}/qr")
async def get_session_qr(session_id: str, current_user: User = Depends(get_current_user)):
    # Check session access
    await check_session_access(session_id, current_user)
    
    session = await db.sessions.find_one({"id": session_id})
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Generate QR code for upload URL
    frontend_url = os.environ.get('FRONTEND_URL', 'http://localhost:3000')
    upload_url = f"{frontend_url}/upload/{session_id}"
    qr_code = generate_qr_code(upload_url)
    
    return {"qr_code": qr_code, "upload_url": upload_url}

@api_router.delete("/sessions/{session_id}")
async def delete_session(session_id: str, current_user: User = Depends(get_current_user)):
    # Check session access
    await check_session_access(session_id, current_user)
    
    result = await db.sessions.update_one(
        {"id": session_id}, 
        {"$set": {"is_active": False}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"message": "Session deactivated successfully"}

# Photo upload routes
@api_router.post("/photos", response_model=Photo)
async def upload_photo(photo_upload: PhotoUpload):
    # Verify session exists and is active
    session = await db.sessions.find_one({"id": photo_upload.session_id, "is_active": True})
    if not session:
        raise HTTPException(status_code=404, detail="Session not found or inactive")
    
    photo = Photo(
        session_id=photo_upload.session_id,
        filename=photo_upload.filename,
        content_type=photo_upload.content_type,
        image_data=photo_upload.image_data,
        file_size=photo_upload.file_size
    )
    await db.photos.insert_one(photo.dict())
    return photo

@api_router.get("/photos/session/{session_id}", response_model=List[Photo])
async def get_photos_by_session(session_id: str, current_user: User = Depends(get_current_user)):
    # Check session access
    await check_session_access(session_id, current_user)
    
    photos = await db.photos.find({"session_id": session_id}).sort("uploaded_at", -1).to_list(1000)
    return [Photo(**photo) for photo in photos]

@api_router.get("/photos/{photo_id}", response_model=Photo)
async def get_photo(photo_id: str, current_user: User = Depends(get_current_user)):
    photo = await db.photos.find_one({"id": photo_id})
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    
    # Check session access for this photo
    await check_session_access(photo["session_id"], current_user)
    
    return Photo(**photo)

@api_router.delete("/photos/{photo_id}")
async def delete_photo(photo_id: str, current_user: User = Depends(get_current_user)):
    photo = await db.photos.find_one({"id": photo_id})
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    
    # Check session access for this photo
    await check_session_access(photo["session_id"], current_user)
    
    result = await db.photos.delete_one({"id": photo_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Photo not found")
    return {"message": "Photo deleted successfully"}

@api_router.post("/photos/bulk-download")
async def bulk_download_photos(photo_ids: List[str], current_user: User = Depends(get_current_user)):
    """Download multiple photos as a ZIP file"""
    if not photo_ids:
        raise HTTPException(status_code=400, detail="No photo IDs provided")
    
    # Fetch all photos and validate access
    photos = []
    for photo_id in photo_ids:
        photo = await db.photos.find_one({"id": photo_id})
        if not photo:
            continue  # Skip missing photos
        
        # Check session access for this photo
        try:
            await check_session_access(photo["session_id"], current_user)
            photos.append(photo)
        except HTTPException:
            continue  # Skip photos user doesn't have access to
    
    if not photos:
        raise HTTPException(status_code=404, detail="No accessible photos found")
    
    # Create a temporary ZIP file
    def create_zip():
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            with zipfile.ZipFile(tmp_file.name, 'w', zipfile.ZIP_DEFLATED) as zip_file:
                for photo in photos:
                    try:
                        # Decode base64 image data
                        image_data = base64.b64decode(photo["image_data"])
                        
                        # Create a safe filename
                        safe_filename = photo["filename"]
                        if not safe_filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
                            # Try to determine extension from content type
                            content_type = photo.get("content_type", "")
                            if "jpeg" in content_type or "jpg" in content_type:
                                safe_filename += ".jpg"
                            elif "png" in content_type:
                                safe_filename += ".png"
                            elif "gif" in content_type:
                                safe_filename += ".gif"
                            else:
                                safe_filename += ".jpg"  # Default to jpg
                        
                        # Add timestamp to filename to avoid conflicts
                        name, ext = safe_filename.rsplit('.', 1)
                        uploaded_at = photo.get("uploaded_at", "")
                        if uploaded_at:
                            # Convert datetime to string if needed
                            if hasattr(uploaded_at, 'strftime'):
                                timestamp = uploaded_at.strftime("%Y%m%d_%H%M%S")
                            else:
                                timestamp = str(uploaded_at).replace(":", "-").replace(".", "-")[:19]
                        else:
                            timestamp = "unknown"
                        unique_filename = f"{name}_{timestamp}.{ext}"
                        
                        zip_file.writestr(unique_filename, image_data)
                    except Exception as e:
                        logger.error(f"Error adding photo {photo['id']} to ZIP: {e}")
                        continue
            
            return tmp_file.name
    
    # Generate ZIP file
    zip_filename = create_zip()
    
    # Stream the ZIP file
    def iterfile():
        with open(zip_filename, 'rb') as file_like:
            yield from file_like
        # Clean up temporary file
        os.unlink(zip_filename)
    
    # Get session name for ZIP filename
    session_name = "photos"
    if photos:
        session = await db.sessions.find_one({"id": photos[0]["session_id"]})
        if session:
            session_name = session["name"].replace(" ", "_").replace("/", "_")
    
    headers = {
        'Content-Disposition': f'attachment; filename="{session_name}_photos.zip"'
    }
    
    return StreamingResponse(
        iterfile(),
        media_type='application/zip',
        headers=headers
    )

# Public route for checking session
@api_router.get("/public/sessions/{session_id}/check")
async def check_session_public(session_id: str):
    session = await db.sessions.find_one({"id": session_id, "is_active": True})
    if not session:
        raise HTTPException(status_code=404, detail="Session not found or inactive")
    return {"session_name": session["name"], "session_id": session_id}

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("startup")
async def startup_event():
    await create_initial_superadmin()

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()