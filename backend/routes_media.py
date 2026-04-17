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

router = APIRouter(prefix="/media", tags=["Media"])

UPLOAD_DIR = "uploads"
IMAGES_DIR = os.path.join(UPLOAD_DIR, "images")
DOCS_DIR = os.path.join(UPLOAD_DIR, "docs")

for d in [IMAGES_DIR, DOCS_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

# Configurer Cloudinary (récupère automatiquement CLOUDINARY_URL depuis l'environnement)
cloudinary.config(secure=True)

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    current_user: Profile = Depends(get_current_user),
):
    """Télécharger un fichier directement sur Cloudinary."""
    
    try:
        # L'argument resource_type="auto" détecte automatiquement s'il s'agit d'une image, audio, ou document
        response = cloudinary.uploader.upload(
            file.file, 
            resource_type="auto", 
            folder="corporate_connect_uploads"
        )
        file_url = response.get("secure_url")
        file_size = response.get("bytes", 0)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Échec de l'upload Cloudinary: {str(e)}")

    return {
        "filename": file.filename,
        "url": file_url,
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
