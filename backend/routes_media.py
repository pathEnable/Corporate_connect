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
        # Les nouveaux comptes Cloudinary bloquent par défaut la livraison des PDF publics (type='upload').
        # Pour pouvoir les lire/télécharger, il faut les uploader avec type="private"
        # et générer une URL signée via notre proxy.
        is_pdf = file.filename.lower().endswith('.pdf')
        delivery_type = "private" if is_pdf else "upload"
        
        # On force le resource_type à 'raw' pour les documents/PDF afin d'éviter les soucis de conversion d'image
        r_type = "raw" if is_pdf else "auto"

        response = cloudinary.uploader.upload(
            file.file, 
            resource_type=r_type, 
            type=delivery_type,
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
        
        # On définit les types à tester
        types_to_try = [resource_type]
        if is_pdf and resource_type != 'raw':
            types_to_try.append('raw')

        async with httpx.AsyncClient() as client:
            # 1. On tente l'URL d'origine
            print(f"[Proxy] Tentative URL d'origine: {url}")
            response = await client.get(url, follow_redirects=True)
            
            # 2. Si échec (401/404), on va générer l'URL d'accès sécurisée
            if response.status_code != 200:
                print(f"[Proxy] Échec URL d'origine ({response.status_code}).")
                
                # IMPORTANT: Les nouveaux comptes bloquent les PDF en type="upload".
                # Nous avons changé l'upload pour utiliser type="private" et resource_type="raw".
                # Pour les fichiers "private", la SEULE façon de les récupérer est private_download_url.
                
                base_id = public_id_with_ext
                fmt = None
                if '.' in public_id_with_ext:
                    base_id, fmt = public_id_with_ext.rsplit('.', 1)

                try:
                    if delivery_type in ["private", "authenticated"]:
                        # Pour les nouveaux fichiers (private/raw)
                        signed_url = cloudinary.utils.private_download_url(
                            public_id_with_ext if resource_type == 'raw' else base_id,
                            format=None if resource_type == 'raw' else fmt,
                            resource_type=resource_type,
                            attachment=True
                        )
                        print(f"[Proxy] Tentative private_download_url: {signed_url}")
                    else:
                        # Pour les anciens fichiers (upload/image)
                        signed_url, _ = cloudinary.utils.cloudinary_url(
                            base_id if resource_type == 'image' else public_id_with_ext,
                            resource_type=resource_type,
                            type=delivery_type,
                            format=fmt if resource_type == 'image' else None,
                            version=version,
                            flags="attachment",
                            sign_url=True
                        )
                        print(f"[Proxy] Tentative URL signée: {signed_url}")
                        
                    response = await client.get(signed_url, follow_redirects=True)
                except Exception as sign_e:
                    print(f"[Proxy] Erreur génération URL sécurisée: {str(sign_e)}")

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
