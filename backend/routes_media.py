import os
import shutil
import uuid
import cloudinary
import cloudinary.uploader
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from database import get_db
from models import Profile
from routes_auth import get_current_user
from config import CLOUDINARY_URL

# Configurer Cloudinary si l'URL est fournie
if CLOUDINARY_URL:
    cloudinary.config(cloudinary_url=CLOUDINARY_URL)

router = APIRouter(prefix="/media", tags=["Media"])

UPLOAD_DIR = "uploads"
IMAGES_DIR = os.path.join(UPLOAD_DIR, "images")
DOCS_DIR = os.path.join(UPLOAD_DIR, "docs")

for d in [IMAGES_DIR, DOCS_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    current_user: Profile = Depends(get_current_user),
):
    """Télécharger un fichier sur Cloudinary (ou localement en fallback)."""
    file_ext = os.path.splitext(file.filename)[1].lower()
    
    # 1. Tentative d'upload sur Cloudinary
    if CLOUDINARY_URL:
        try:
            upload_result = cloudinary.uploader.upload(
                file.file,
                folder="emini_connect",
                resource_type="auto"
            )
            return {
                "filename": file.filename,
                "url": upload_result["secure_url"],
                "content_type": file.content_type,
                "size": upload_result.get("bytes", 0)
            }
        except Exception as e:
            print(f"[Cloudinary] Erreur d'upload: {e}")
            # Fallback local si Cloudinary échoue
    
    # 2. Fallback Local (Render éphémère)
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    is_image = file_ext in [".png", ".jpg", ".jpeg", ".gif", ".webp"]
    target_dir = IMAGES_DIR if is_image else DOCS_DIR
    file_path = os.path.join(target_dir, unique_filename)

    with open(file_path, "wb") as buffer:
        file.file.seek(0, os.SEEK_END)
        file_size = file.file.tell()
        file.file.seek(0)
        shutil.copyfileobj(file.file, buffer)

    return {
        "filename": file.filename,
        "url": f"/media/download/{unique_filename}",
        "content_type": file.content_type,
        "size": file_size
    }


from fastapi import Query
from auth import oauth2_scheme, SECRET_KEY, ALGORITHM
from jose import jwt, JWTError

@router.get("/download/{filename}")
async def download_file(
    filename: str,
    current_user: Profile = Depends(get_current_user),
):
    """Téléchargement sécurisé via JWT (Header)."""
    
    # Chercher d'abord dans images, puis docs
    img_path = os.path.join(IMAGES_DIR, filename)
    doc_path = os.path.join(DOCS_DIR, filename)

    if os.path.exists(img_path):
        return FileResponse(img_path, headers={"Cache-Control": "public, max-age=86400"})
    if os.path.exists(doc_path):
        return FileResponse(doc_path, headers={"Cache-Control": "public, max-age=86400"})
        
    raise HTTPException(status_code=404, detail="Fichier introuvable.")
