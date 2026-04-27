import os
from dotenv import load_dotenv

load_dotenv()

# ── Environnement ──────────────────────────────────────────────────────────────
ENV = os.getenv("ENV", "development")  # "development" | "production"
IS_PRODUCTION = ENV == "production"

# ── Base de données ───────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/connect_db")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# ── Sécurité JWT ──────────────────────────────────────────────────────────────
_INSECURE_DEFAULT = "super-secret-key-change-in-production"
SECRET_KEY = os.getenv("SECRET_KEY", _INSECURE_DEFAULT)

# Bloquer le démarrage en production si la SECRET_KEY n'a pas été changée
if IS_PRODUCTION and (SECRET_KEY == _INSECURE_DEFAULT or len(SECRET_KEY) < 32):
    raise RuntimeError(
        "🔴 CRITICAL: SECRET_KEY is insecure. "
        "Set a strong SECRET_KEY (≥64 chars) via environment variable before deploying."
    )

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 365 * 10  # 10 ans (Session persistante façon WhatsApp)

# ── Services tiers ────────────────────────────────────────────────────────────
AGORA_APP_ID = os.getenv("AGORA_APP_ID")
AGORA_APP_CERTIFICATE = os.getenv("AGORA_APP_CERTIFICATE")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY")

# ── CORS ──────────────────────────────────────────────────────────────────────
# En production : whitelist stricte. En dev : ouvert pour faciliter le développement.
_DEFAULT_ORIGINS = "https://corporate-connect.onrender.com" if IS_PRODUCTION else "*"
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", _DEFAULT_ORIGINS).split(",")
