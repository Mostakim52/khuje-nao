import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "mysecretkey")
    
    # Supabase configuration
    SUPABASE_URL = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
    
    # AppWrite Storage configuration
    APPWRITE_ENDPOINT = os.getenv("APPWRITE_ENDPOINT", "")
    APPWRITE_PROJECT_ID = os.getenv("APPWRITE_PROJECT_ID", "")
    APPWRITE_API_KEY = os.getenv("APPWRITE_API_KEY", "")
    APPWRITE_STORAGE_BUCKET_ID = os.getenv("APPWRITE_STORAGE_BUCKET_ID", "")
