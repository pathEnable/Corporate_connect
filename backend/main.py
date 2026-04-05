from fastapi import FastAPI, Depends, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse, FileResponse, RedirectResponse
import httpx
from starlette.types import ASGIApp, Receive, Scope, Send
from sqlalchemy.orm import Session
from database import engine, get_db
from models import Base, Profile
from routes_auth import router as auth_router
from routes_chat import router as chat_router
from routes_rooms import router as rooms_router
from routes_profiles import router as profiles_router
from routes_media import router as media_router
from routes_status import router as status_router
from routes_search import router as search_router
from routes_admin import router as admin_router
from routes_notifications import router as notifications_router
from routes_agora import router as agora_router
from routes_calls import router as calls_router
import time
import os
from collections import defaultdict

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
GITHUB_REPO = "pathEnable/Corporate_connect"

# Créer les tables au démarrage
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Corporate Connect API", version="1.0.0")

# ── Headers de sécurité (Middleware ASGI pur — compatible WebSocket) ──
class SecurityHeadersMiddleware:
    """Middleware ASGI pur qui n'interfère pas avec les WebSockets."""
    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        # Les WebSockets passent directement sans modification
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_headers(message):
            if message["type"] == "http.response.start":
                headers = dict(message.get("headers", []))
                extra = [
                    (b"x-content-type-options", b"nosniff"),
                    (b"x-frame-options", b"DENY"),
                    (b"x-xss-protection", b"1; mode=block"),
                    (b"strict-transport-security", b"max-age=31536000; includeSubDomains"),
                ]
                message["headers"] = list(message.get("headers", [])) + extra
            await send(message)

        await self.app(scope, receive, send_with_headers)

app.add_middleware(SecurityHeadersMiddleware)

# ── Rate Limiter basique (Middleware ASGI pur — compatible WebSocket) ──
request_counts: dict = defaultdict(list)
RATE_LIMIT = 60  # requêtes max
RATE_WINDOW = 60  # par fenêtre de 60 secondes

class RateLimiterMiddleware:
    """Middleware ASGI pur qui n'interfère pas avec les WebSockets."""
    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        # Les WebSockets passent directement sans limitation
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        client = scope.get("client")
        client_ip = client[0] if client else "unknown"
        now = time.time()
        request_counts[client_ip] = [t for t in request_counts[client_ip] if now - t < RATE_WINDOW]
        if len(request_counts[client_ip]) >= RATE_LIMIT:
            response = JSONResponse(status_code=429, content={"detail": "Trop de requêtes. Réessayez plus tard."})
            await response(scope, receive, send)
            return
        request_counts[client_ip].append(now)
        await self.app(scope, receive, send)

app.add_middleware(RateLimiterMiddleware)

# ── CORS (Doit être le dernier ajouté pour être le premier/dernier exécuté) ──
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Plus robuste pour le développement avec ngrok/flutter web
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],  # Permet au frontend de voir tous les headers si nécessaire
)

# Les montages statiques seront placés après l'enregistrement des routes pour éviter les conflits.

@app.get("/download")
async def download_page():
    """Page web pour télécharger l'APK."""
    return FileResponse(os.path.join(BASE_DIR, "static/download.html"))

@app.get("/version")
async def get_latest_version(request: Request):
    """Retourne la dernière version disponible et les URLs de téléchargement stable."""
    base_url = str(request.base_url).rstrip("/")
    return {
        "version_code": 4, 
        "version_name": "2.1.0",
        "apk_url": f"{base_url}/download/apk/arm64-v8a",
        "variants": {
            "arm64-v8a": f"{base_url}/download/apk/arm64-v8a",
            "armeabi-v7a": f"{base_url}/download/apk/armeabi-v7a",
            "x86_64": f"{base_url}/download/apk/x86_64"
        }
    }

@app.get("/download/apk/{variant}")
async def redirect_to_github_apk(variant: str):
    """Redirige vers le bon asset de la dernière Release GitHub."""
    async with httpx.AsyncClient() as client:
        try:
            # Récupérer les infos de la dernière release
            response = await client.get(
                f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest",
                follow_redirects=True,
                headers={"User-Agent": "Corporate-Connect-Server"}
            )
            if response.status_code != 200:
                return JSONResponse(status_code=502, content={"detail": "Impossible de contacter GitHub."})
            
            data = response.json()
            assets = data.get("assets", [])
            
            # Chercher l'asset qui correspond à la variante
            # On cherche par exemple "arm64-v8a" dans le nom du fichier
            target_url = None
            for asset in assets:
                name = asset.get("name", "").lower()
                if variant.lower() in name and name.endswith(".apk"):
                    target_url = asset.get("browser_download_url")
                    break
            
            if not target_url:
                # Fallback si on ne trouve pas l'architecture précise
                return JSONResponse(status_code=404, content={"detail": f"APK pour {variant} non trouvé dans la dernière release."})
                
            return RedirectResponse(url=target_url)
            
        except Exception as e:
            return JSONResponse(status_code=500, content={"detail": f"Erreur lors de la redirection : {str(e)}"})

@app.get("/api/releases/history")
async def get_releases_history():
    """Retourne les 3 dernières releases GitHub avec leurs infos."""
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                f"https://api.github.com/repos/{GITHUB_REPO}/releases",
                follow_redirects=True,
                headers={"User-Agent": "Corporate-Connect-Server"}
            )
            if response.status_code != 200:
                return JSONResponse(status_code=502, content={"detail": "GitHub API inaccessible."})
            
            all_releases = response.json()
            history = []
            
            # On prend les 3 premières releases
            for rel in all_releases[:3]:
                # On cherche un APK dans les assets
                apk_asset = next((a for a in rel.get("assets", []) if a.get("name", "").endswith(".apk")), None)
                
                history.append({
                    "name": rel.get("name") or rel.get("tag_name"),
                    "tag": rel.get("tag_name"),
                    "published_at": rel.get("published_at"),
                    "download_url": apk_asset.get("browser_download_url") if apk_asset else rel.get("html_url"),
                    "body": rel.get("body", "")[:100] + "..." if rel.get("body") and len(rel.get("body")) > 100 else rel.get("body", "")
                })
                
            return history
            
        except Exception as e:
            return JSONResponse(status_code=500, content={"detail": f"Erreur historique : {str(e)}"})

# Enregistrement des routes
app.include_router(auth_router)
app.include_router(chat_router)
app.include_router(rooms_router)
app.include_router(profiles_router)
app.include_router(media_router)
app.include_router(status_router)
app.include_router(search_router)
app.include_router(admin_router)
app.include_router(notifications_router)
app.include_router(agora_router)
app.include_router(calls_router)

# ── Diagnostic & Fichiers statiques ──

@app.get("/debug/files")
async def debug_files():
    """Route de diagnostic pour vérifier la présence des APK."""
    uploads_path = os.path.join(BASE_DIR, "uploads")
    exists = os.path.exists(uploads_path)
    files = os.listdir(uploads_path) if exists else []
    return {
        "base_dir": BASE_DIR,
        "uploads_path": uploads_path,
        "exists": exists,
        "files": files,
        "cwd": os.getcwd()
    }

# Fichiers statiques (après les routes pour priorité)
app.mount("/uploads", StaticFiles(directory=os.path.join(BASE_DIR, "uploads")), name="uploads")
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")

@app.get("/")
async def root():
    return {"message": "Welcome to Corporate Connect API", "status": "active"}

@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    """Nouvelle route pour apprendre : compte le nombre d'utilisateurs."""
    user_count = db.query(Profile).count()
    return {
        "total_users": user_count,
        "server_time": "Now" # On pourrait ajouter plus d'infos !
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

