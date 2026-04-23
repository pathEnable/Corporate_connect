import os
import shutil
import uuid
import cloudinary
import cloudinary.uploader
import cloudinary.utils
import httpx
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Query
from fastapi.responses import FileResponse, StreamingResponse, RedirectResponse
from sqlalchemy.orm import Session
from database import get_db
from models import Profile
from routes_auth import get_current_user
from urllib.parse import urlsplit

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
    """Proxy pour télécharger des fichiers Cloudinary en générant une URL signée temporaire."""
    if "cloudinary.com" not in url:
        raise HTTPException(status_code=400, detail="Seules les URLs Cloudinary sont autorisées.")
    
    try:
        # Extraire les informations de l'URL Cloudinary
        # Format type: https://res.cloudinary.com/cloud_name/resource_type/upload/v123/public_id.ext
        uri = urlsplit(url)
        path_parts = [p for p in uri.path.split('/') if p]
        
        # On cherche 'upload' pour se repérer
        if 'upload' not in path_parts:
            # Fallback sur un proxy direct si l'URL est atypique
            async with httpx.AsyncClient() as client:
                config = cloudinary.config()
                auth = (config.api_key, config.api_secret) if config.api_key else None
                response = await client.get(url, auth=auth, follow_redirects=True)
                return StreamingResponse(response.aiter_bytes(), media_type=response.headers.get("content-type"))

        upload_idx = path_parts.index('upload')
        resource_type = path_parts[upload_idx - 1]
        
        # Le public_id commence après 'upload' (et saute la version si présente)
        start_idx = upload_idx + 1
        if start_idx < len(path_parts) and path_parts[start_idx].startswith('v') and path_parts[start_idx][1:].isdigit():
            start_idx += 1
        
        # On récupère le public_id avec son extension
        public_id_with_ext = "/".join(path_parts[start_idx:])
        # Pour Cloudinary, le public_id ne doit généralement pas avoir l'extension sauf pour resource_type='raw'
        public_id = os.path.splitext(public_id_with_ext)[0] if resource_type != 'raw' else public_id_with_ext

        # Générer une URL signée (valable par défaut quelques minutes)
        # On utilise 'authenticated' car c'est ce qui bloque le 401
        signed_url, _ = cloudinary.utils.cloudinary_url(
            public_id,
            resource_type=resource_type,
            type="authenticated",
            sign_url=True,
            secure=True
        )
        
        print(f"[Proxy] Redirection vers URL signée: {signed_url}")
        return RedirectResponse(url=signed_url)

    except Exception as e:
        print(f"[Proxy] Erreur: {str(e)}")
        # Ultime fallback : proxy direct sans signature (ce qu'on faisait avant)
        try:
            async with httpx.AsyncClient() as client:
                config = cloudinary.config()
                auth = (config.api_key, config.api_secret) if config.api_key else None
                resp = await client.get(url, auth=auth, follow_redirects=True)
                return StreamingResponse(resp.aiter_bytes(), media_type=resp.headers.get("content-type"))
        except:
            raise HTTPException(status_code=500, detail=f"Erreur proxy finale: {str(e)}")

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
