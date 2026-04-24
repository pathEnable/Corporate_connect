import os
import shutil
import uuid
import cloudinary
import cloudinary.uploader
import cloudinary.utils
import httpx
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Query
from fastapi.responses import FileResponse, StreamingResponse, RedirectResponse, JSONResponse
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

# Configurer Cloudinary
cloudinary_url = os.getenv("CLOUDINARY_URL")
if cloudinary_url:
    # Si l'URL complète est présente, Cloudinary la parse automatiquement
    cloudinary.config(secure=True)
else:
    # Sinon on utilise les variables individuelles
    cloudinary.config(
        cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
        api_key=os.getenv("CLOUDINARY_API_KEY"),
        api_secret=os.getenv("CLOUDINARY_API_SECRET"),
        secure=True
    )

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
        version = None
        if start_idx < len(path_parts) and path_parts[start_idx].startswith('v') and path_parts[start_idx][1:].isdigit():
            version = path_parts[start_idx][1:]
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
        
        # Tentative de téléchargement depuis le backend
        async with httpx.AsyncClient() as client:
            
            # 1. On tente l'URL d'origine
            print(f"[Proxy] Tentative URL d'origine: {url}")
            # On n'envoie pas auth car Basic Auth n'est pas supporté pour la livraison
            response = await client.get(url, follow_redirects=True)
            
            # 2. Si échec (401/404), on tente de générer une URL signée avec le bon resource_type
            if response.status_code != 200:
                print(f"[Proxy] Échec URL d'origine ({response.status_code}), tentative URL signée...")
                
                # On essaie d'abord le resource_type détecté, puis 'raw' si c'est un PDF
                types_to_try = [resource_type]
                if is_pdf and resource_type != 'raw':
                    types_to_try.append('raw')
                
                # On tente une approche plus robuste: private_download_url
                try:
                    # Séparer public_id et format pour les images
                    base_id = public_id
                    fmt = None
                    if '.' in public_id:
                        base_id, fmt = public_id.rsplit('.', 1)

                    for r_type in types_to_try:
                        print(f"[Proxy] Tentative private_download_url ({r_type})...")
                        
                        # Pour 'image', on sépare. Pour 'raw', on garde tout dans le public_id.
                        curr_id = base_id if r_type == 'image' else public_id
                        curr_fmt = fmt if r_type == 'image' else None

                        download_url = cloudinary.utils.private_download_url(
                            curr_id,
                            format=curr_fmt,
                            resource_type=r_type,
                            attachment=True
                        )
                        
                        print(f"[Proxy] Download URL générée: {download_url}")
                        response = await client.get(download_url)
                        if response.status_code == 200:
                            break
                            
                except Exception as inner_e:
                    print(f"[Proxy] Erreur avec private_download_url: {str(inner_e)}")

            # 3. Retourner le flux de données
            if response.status_code == 200:
                return StreamingResponse(
                    response.aiter_bytes(), 
                    status_code=200,
                    media_type=response.headers.get("content-type")
                )
            else:
                print(f"[Proxy] Échec final pour {url}: {response.status_code}")
                return JSONResponse(
                    status_code=response.status_code, 
                    content={"detail": f"Cloudinary a retourné une erreur {response.status_code}"}
                )

    except Exception as e:
        print(f"[Proxy] Erreur critique: {str(e)}")
        return JSONResponse(status_code=500, content={"detail": str(e)})

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
