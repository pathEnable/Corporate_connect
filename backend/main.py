from fastapi import FastAPI, Depends, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
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
import time
from collections import defaultdict

# Créer les tables au démarrage
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Corporate Connect API", version="1.0.0")

# ── CORS ──
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production, restreindre aux domaines autorisés
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Headers de sécurité ──
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response

app.add_middleware(SecurityHeadersMiddleware)

# ── Rate Limiter basique (en mémoire) ──
request_counts: dict = defaultdict(list)
RATE_LIMIT = 60  # requêtes max
RATE_WINDOW = 60  # par fenêtre de 60 secondes

class RateLimiterMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host if request.client else "unknown"
        now = time.time()
        # Nettoyer les anciennes entrées
        request_counts[client_ip] = [t for t in request_counts[client_ip] if now - t < RATE_WINDOW]
        if len(request_counts[client_ip]) >= RATE_LIMIT:
            return JSONResponse(status_code=429, content={"detail": "Trop de requêtes. Réessayez plus tard."})
        request_counts[client_ip].append(now)
        return await call_next(request)

app.add_middleware(RateLimiterMiddleware)

# Fichiers statiques pour les uploads
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

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

