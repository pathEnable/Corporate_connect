import os
import shutil
import uuid
import cloudinary
import cloudinary.uploader
import cloudinary.utils
import httpx
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Query
from fastapi.responses import FileResponse, StreamingResponse
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

@router.get("/proxy")
async def proxy_cloudinary(
    url: str = Query(...),
    current_user: Profile = Depends(get_current_user),
):
    """Proxy pour télécharger des fichiers Cloudinary privés via le backend."""
    if "cloudinary.com" not in url:
        raise HTTPException(status_code=400, detail="Seules les URLs Cloudinary sont autorisées.")
    
    async with httpx.AsyncClient() as client:
        try:
            # Récupérer les identifiants Cloudinary pour l'authentification Basic
            config = cloudinary.config()
            auth = None
            if config.api_key and config.api_secret:
                auth = (config.api_key, config.api_secret)
                print(f"[Proxy] Utilisation de l'authentification pour Cloudinary: {config.cloud_name}")

            # On récupère le fichier depuis Cloudinary avec auth si disponible
            response = await client.get(url, auth=auth, follow_redirects=True)
            
            if response.status_code != 200:
                print(f"[Proxy] Erreur Cloudinary ({response.status_code}): {response.text[:100]}")
                raise HTTPException(status_code=response.status_code, detail="Impossible de récupérer le fichier depuis Cloudinary")
            
            # On renvoie le flux au client mobile
            return StreamingResponse(
                response.aiter_bytes(),
                media_type=response.headers.get("content-type", "application/octet-stream"),
                headers={
                    "Content-Disposition": response.headers.get("Content-Disposition", "attachment"),
                    "Cache-Control": "public, max-age=86400"
                }
            )
        except Exception as e:
            print(f"[Proxy] Erreur exceptionnelle: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Erreur proxy: {str(e)}")

@router.get("/download/{filename}")
async def download_file(
    filename: str,
    current_user: Profile = Depends(get_current_user),
):
    """Téléchargement sécurisé pour les fichiers locaux via JWT (Header)."""
    
    # Chercher d'abord dans images, puis docs
    img_path = os.path.join(IMAGES_DIR, filename)
    doc_path = os.path.join(DOCS_DIR, filename)

    if os.path.exists(img_path):
        return FileResponse(img_path, headers={"Cache-Control": "public, max-age=86400"})
    if os.path.exists(doc_path):
        return FileResponse(doc_path, headers={"Cache-Control": "public, max-age=86400"})
        
    raise HTTPException(status_code=404, detail="Fichier introuvable.")
