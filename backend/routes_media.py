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
):
    """Proxy pour télécharger des fichiers Cloudinary en générant une URL signée temporaire."""
    if "cloudinary.com" not in url:
        raise HTTPException(status_code=400, detail="Seules les URLs Cloudinary sont autorisées.")
    
    try:
        # Extraire les informations de l'URL Cloudinary
        # Format type: https://res.cloudinary.com/cloud_name/resource_type/upload/v123/public_id.ext
        uri = urlsplit(url)
        path_parts = [p for p in uri.path.split('/') if p]
        
        # On cherche le type de livraison (upload, authenticated, private)
        delivery_type = "upload"
        upload_idx = -1
        
        for t in ['upload', 'authenticated', 'private']:
            if t in path_parts:
                upload_idx = path_parts.index(t)
                delivery_type = t
                break

        if upload_idx == -1:
            # Fallback sur un proxy direct si l'URL est atypique
            async with httpx.AsyncClient() as client:
                config = cloudinary.config()
                auth = (config.api_key, config.api_secret) if config.api_key else None
                response = await client.get(url, auth=auth, follow_redirects=True)
                return StreamingResponse(response.aiter_bytes(), media_type=response.headers.get("content-type"))

        resource_type = path_parts[upload_idx - 1]
        
        # Le public_id commence après le type de livraison (et saute la version si présente)
        start_idx = upload_idx + 1
        if start_idx < len(path_parts) and path_parts[start_idx].startswith('v') and path_parts[start_idx][1:].isdigit():
            start_idx += 1
        
        # On récupère le public_id avec son extension
        public_id_with_ext = "/".join(path_parts[start_idx:])
        
        # Pour Cloudinary, on doit conserver l'extension pour les PDF même s'ils sont 'image', 
        # sinon Cloudinary ne sait pas comment les délivrer et renvoie 401.
        # Le plus sûr est de garder le public_id tel qu'il est dans l'URL d'origine.
        public_id = public_id_with_ext

        # Générer une URL signée (valable par défaut quelques minutes)
        # On utilise le même type que l'URL d'origine (upload, authenticated, etc.)
        # IMPORTANT: Cloudinary bloque souvent les PDF (401) pour des raisons de sécurité 
        # s'ils ne sont pas téléchargés en tant qu'attachement.
        is_pdf = public_id.lower().endswith('.pdf')
        
        signed_url, _ = cloudinary.utils.cloudinary_url(
            public_id,
            resource_type=resource_type,
            type=delivery_type,
            sign_url=True,
            secure=True,
            attachment=True if is_pdf else None
        )
        
        # Au lieu de rediriger (ce qui pose des problèmes de signature/sécurité avec les PDF),
        # on télécharge le fichier depuis le backend et on le streame au client.
        # Cela garantit que l'accès est autorisé via les credentials API du backend.
        async with httpx.AsyncClient() as client:
            config = cloudinary.config()
            auth = (config.api_key, config.api_secret) if config.api_key else None
            
            # On utilise l'URL d'origine qui est déjà complète
            response = await client.get(url, auth=auth, follow_redirects=True)
            
            if response.status_code != 200:
                print(f"[Proxy] Erreur Cloudinary: {response.status_code} pour {url}")
                # Si l'URL directe échoue, on tente avec l'URL signée que nous avons générée
                signed_url, _ = cloudinary.utils.cloudinary_url(
                    public_id,
                    resource_type=resource_type,
                    type=delivery_type,
                    sign_url=True,
                    secure=True,
                    attachment=True if is_pdf else None
                )
                response = await client.get(signed_url)

            return StreamingResponse(
                response.aiter_bytes(), 
                status_code=response.status_code,
                media_type=response.headers.get("content-type")
            )

    except Exception as e:
        print(f"[Proxy] Erreur critique: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

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
