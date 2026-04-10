from fastapi import FastAPI, Depends, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse, FileResponse, RedirectResponse, StreamingResponse
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
from config import ALLOWED_ORIGINS, GITHUB_TOKEN
import time
import os

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

from database import redis_client

# ── Rate Limiter Distribué (Redis) ──
RATE_LIMIT = 60  # requêtes max
RATE_WINDOW = 60  # par fenêtre de 60 secondes

class RateLimiterMiddleware:
    """Middleware ASGI de Rate Limiting utilisant Redis pour le clustering."""
    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        # Les WebSockets passent directement sans limitation globale
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        client = scope.get("client")
        client_ip = client[0] if client else "unknown"
        now = time.time()
        
        # Clé Redis spécifique pour le rate limiting
        key = f"rate_limit:{client_ip}"
        
        try:
            # Utilisation d'un pipeline pour l'atomicité et l'optimisation réseau
            async with redis_client.pipeline(transaction=True) as pipe:
                pipe.zremrangebyscore(key, 0, now - RATE_WINDOW)
                pipe.zcard(key)
                pipe.zadd(key, {str(now): now})
                pipe.expire(key, RATE_WINDOW)
                results = await pipe.execute()
                
            request_count = results[1]
            
            if request_count > RATE_LIMIT:
                response = JSONResponse(status_code=429, content={"detail": "Trop de requêtes. Réessayez plus tard."})
                await response(scope, receive, send)
                return
        except Exception as e:
            # En cas de panne Redis, on laisse passer pour ne pas bloquer l'usage (ou on peut logguer)
            print(f"[RateLimit] Erreur Redis: {e}")

        await self.app(scope, receive, send)

app.add_middleware(RateLimiterMiddleware)

# ── CORS (Doit être le dernier ajouté pour être le premier/dernier exécuté) ──
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # Défini dans config.py (depuis env ALLOWED_ORIGINS)
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
    """Retourne la dernière version disponible et les URLs de téléchargement persistantes."""
    base_url = str(request.base_url).rstrip("/")
    return {
        "version_code": 2009, 
        "version_name": "Version 2.1.0+2009",
        "apk_url": f"{base_url}/download-apk/arm64-v8a",
        "variants": {
            "arm64-v8a": f"{base_url}/download-apk/arm64-v8a",
            "armeabi-v7a": f"{base_url}/download-apk/armeabi-v7a",
            "x86_64": f"{base_url}/download-apk/x86_64"
        }
    }

@app.get("/download-apk/{variant}")
async def proxy_github_apk(variant: str):
    """Télécharge l'APK depuis GitHub et le retourne à l'application avec authentification."""
    print(f"DEBUG: Proxy APK appelé pour variante: {variant}")
    if not GITHUB_TOKEN:
        print("DEBUG: GITHUB_TOKEN manquant")
        return JSONResponse(status_code=500, content={"detail": "GITHUB_TOKEN non configuré sur le serveur."})

    headers_auth = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "User-Agent": "Corporate-Connect-Server"
    }

    try:
        # Client unique pour toute l'opération, pas de context manager = pas de fermeture prématurée
        client = httpx.AsyncClient(follow_redirects=True, timeout=300.0)

        # 1. Récupérer les infos de la dernière release
        print(f"DEBUG: Récupération de la dernière release pour {GITHUB_REPO}")
        response = await client.get(
            f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest",
            headers=headers_auth
        )

        if response.status_code != 200:
            await client.aclose()
            print(f"DEBUG: Erreur GitHub API: {response.status_code}")
            return JSONResponse(status_code=502, content={"detail": f"Erreur GitHub: {response.status_code}"})

        data = response.json()
        assets = data.get("assets", [])

        # 2. Chercher l'asset correspondant à la variante
        target_url = None
        filename = "app-release.apk"
        for asset in assets:
            name = asset.get("name", "").lower()
            if variant.lower() in name and name.endswith(".apk"):
                target_url = asset.get("browser_download_url")
                filename = asset.get("name")
                break

        if not target_url:
            await client.aclose()
            print(f"DEBUG: Variante {variant} non trouvée dans les assets")
            return JSONResponse(status_code=404, content={"detail": f"APK pour {variant} non trouvé."})

        print(f"DEBUG: Debut stream APK: {filename}")

        # 3. Générateur qui utilise le MÊME client ouvert, le ferme proprement après
        async def stream_and_close():
            try:
                async with client.stream(
                    "GET",
                    target_url,
                    headers={**headers_auth, "Accept": "application/octet-stream"},
                ) as r:
                    if r.status_code != 200:
                        print(f"DEBUG: Erreur stream GitHub: {r.status_code}")
                        yield b""
                        return
                    async for chunk in r.aiter_bytes(chunk_size=65536):
                        yield chunk
            finally:
                await client.aclose()
                print("DEBUG: Client fermé proprement après stream")

        return StreamingResponse(
            stream_and_close(),
            media_type="application/vnd.android.package-archive",
            headers={
                "Content-Disposition": f"attachment; filename={filename}",
            }
        )

    except Exception as e:
        print(f"DEBUG: Exception dans le proxy: {str(e)}")
        return JSONResponse(status_code=500, content={"detail": f"Erreur Proxy: {str(e)}"})

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

# ── Listener Redis Pub/Sub ──
from routes_chat import start_redis_listener
import asyncio

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(start_redis_listener())

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

