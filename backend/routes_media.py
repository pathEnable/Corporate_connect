import os
import shutil
import uuid
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

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    current_user: Profile = Depends(get_current_user),
):
    """Télécharger un fichier sur le serveur."""
    file_ext = os.path.splitext(file.filename)[1].lower()
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    
    is_image = file_ext in [".png", ".jpg", ".jpeg", ".gif", ".webp"]
    target_dir = IMAGES_DIR if is_image else DOCS_DIR
    file_path = os.path.join(target_dir, unique_filename)

    with open(file_path, "wb") as buffer:
        file.file.seek(0, os.SEEK_END)
        file_size = file.file.tell()
        file.file.seek(0)
        shutil.copyfileobj(file.file, buffer)

    # URL sécurisée via le backend
    file_url = f"/media/download/{unique_filename}"

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
    token: str = Query(None),
    current_user: Profile = Depends(get_current_user),
):
    """Téléchargement sécurisé via JWT (Header OU Query param ?token=).
    
    Le query param est nécessaire pour Flutter Image.network qui ne
    supporte pas facilement les headers d'authentification.
    """
    
    # Chercher d'abord dans images, puis docs
    img_path = os.path.join(IMAGES_DIR, filename)
    doc_path = os.path.join(DOCS_DIR, filename)

    if os.path.exists(img_path):
        return FileResponse(img_path, headers={"Cache-Control": "public, max-age=86400"})
    if os.path.exists(doc_path):
        return FileResponse(doc_path, headers={"Cache-Control": "public, max-age=86400"})
        
    raise HTTPException(status_code=404, detail="Fichier introuvable.")
