from fastapi import FastAPI, Depends, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse, FileResponse
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
from collections import defaultdict

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

# Fichiers statiques pour les uploads et la page de téléchargement
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/download")
async def download_page():
    """Page web pour télécharger l'APK."""
    return FileResponse("static/download.html")

@app.get("/version")
async def get_latest_version():
    """Retourne la dernière version disponible (version_code)."""
    return {
        "version_code": 2, 
        "version_name": "1.0.1",
        "apk_url": "https://corporate-connect.onrender.com/uploads/app-release.apk"
    }

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

