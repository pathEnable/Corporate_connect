import secrets
import re
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks, Request
from sqlalchemy.orm import Session
from database import get_db, redis_client
from models import Profile, RefreshToken
from schemas import RegisterRequest, LoginRequest, OTPRequest, OTPVerify, TokenResponse, ProfileResponse, TokenRefreshRequest
from auth import hash_password, verify_password, create_access_token, get_current_user, create_refresh_token
import uuid
from datetime import datetime, timezone
from config import IS_PRODUCTION
from routes_chat import broadcast_to_all_globals

router = APIRouter(prefix="/auth", tags=["Authentication"])

# ── Constantes de sécurité ─────────────────────────────────────────────────────
LOGIN_RATE_LIMIT = 10        # Max tentatives par fenêtre
LOGIN_RATE_WINDOW = 60       # Fenêtre en secondes
MIN_PASSWORD_LENGTH = 8


async def _broadcast_user_registered(user_data: dict):
    """Helper async pour broadcaster l'inscription d'un utilisateur."""
    await broadcast_to_all_globals(user_data)


@router.post("/register", response_model=TokenResponse)
def register(request: RegisterRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Créer un nouveau compte utilisateur."""
    if not request.email and not request.phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email ou numéro de téléphone requis."
        )

    # ── Validation de la complexité du mot de passe ──
    if request.password:
        if len(request.password) < MIN_PASSWORD_LENGTH:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Le mot de passe doit contenir au moins {MIN_PASSWORD_LENGTH} caractères."
            )
        if not re.search(r'[A-Z]', request.password) or not re.search(r'[0-9]', request.password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Le mot de passe doit contenir au moins une majuscule et un chiffre."
            )

    existing = db.query(Profile).filter(
        (Profile.email == request.email) | (Profile.username == request.username)
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cet email ou ce nom d'utilisateur est déjà pris."
        )

    hashed_pw = hash_password(request.password) if request.password else None

    new_user = Profile(
        email=request.email,
        phone_number=request.phone_number,
        hashed_password=hashed_pw,
        full_name=request.full_name,
        username=request.username,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    token = create_access_token(data={"sub": str(new_user.id), "version": new_user.token_version})
    refresh_token = create_refresh_token(db, str(new_user.id))

    # --- Broadcast temps réel : Notifier tous les utilisateurs connectés ---
    background_tasks.add_task(_broadcast_user_registered, {
        "type": "user_registered",
        "user_id": str(new_user.id),
        "full_name": new_user.full_name,
        "username": new_user.username,
    })
    
    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=str(new_user.id),
        full_name=new_user.full_name
    )


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, http_request: Request, db: Session = Depends(get_db)):
    """Connexion par Email et mot de passe (rate-limited)."""
    if not request.email or not request.password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email et mot de passe requis."
        )

    # ── Rate limiting spécifique au login (par IP) ──
    client_ip = http_request.client.host if http_request.client else "unknown"
    rate_key = f"login_rate:{client_ip}"
    try:
        attempt_count = await redis_client.incr(rate_key)
        if attempt_count == 1:
            await redis_client.expire(rate_key, LOGIN_RATE_WINDOW)
        if attempt_count > LOGIN_RATE_LIMIT:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Trop de tentatives. Réessayez dans {LOGIN_RATE_WINDOW} secondes."
            )
    except HTTPException:
        raise
    except Exception:
        pass  # Si Redis est down, on laisse passer (graceful degradation)

    # ── Vérification des identifiants ──
    # Message d'erreur identique pour email inconnu et mot de passe erroné
    # (évite l'énumération d'utilisateurs)
    user = db.query(Profile).filter(Profile.email == request.email).first()
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect."
        )

    # ── Vérification du compte actif ──
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce compte a été désactivé. Contactez l'administrateur."
        )

    token = create_access_token(data={"sub": str(user.id), "version": user.token_version})
    refresh_token = create_refresh_token(db, str(user.id))

    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=str(user.id),
        full_name=user.full_name
    )


@router.post("/otp/send")
async def send_otp(payload: OTPRequest, request: Request):
    """Envoyer un code OTP par SMS (simulé) avec stockage Redis."""
    # ── Strict Rate limit sur l'envoi de SMS ──
    client_ip = request.client.host if request.client else 'unknown'
    spam_key = f"otp_spam:{client_ip}"
    spam_count = await redis_client.incr(spam_key)
    if spam_count == 1:
        await redis_client.expire(spam_key, 60)  # 1 SMS par minute max par IP
    if spam_count > 1:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Veuillez patienter 1 minute entre chaque demande.")

    # Génération sécurisée d'un code à 6 chiffres
    otp_code = "".join([secrets.choice("0123456789") for _ in range(6)])
    
    # Stockage dans Redis avec expiration (5 minutes / 300 secondes)
    redis_key = f"otp:{payload.phone_number}"
    await redis_client.set(redis_key, otp_code, ex=300)
    
    # En production : intégrer Twilio ou un service SMS
    if IS_PRODUCTION:
        return {"message": "Code OTP envoyé par SMS."}
    return {"message": f"Code OTP envoyé (dev: {otp_code})"}


@router.post("/otp/verify", response_model=TokenResponse)
async def verify_otp(payload: OTPVerify, db: Session = Depends(get_db)):
    """Vérifier le code OTP stocké dans Redis et connecter l'utilisateur."""
    redis_key = f"otp:{payload.phone_number}"
    stored_otp = await redis_client.get(redis_key)
    
    if not stored_otp or stored_otp != payload.otp_code:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Code OTP invalide ou expiré."
        )

    # Supprimer l'OTP après vérification réussie
    await redis_client.delete(redis_key)

    user = db.query(Profile).filter(Profile.phone_number == payload.phone_number).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucun compte associé à ce numéro."
        )

    token = create_access_token(data={"sub": str(user.id), "version": user.token_version})
    refresh_token = create_refresh_token(db, str(user.id))

    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=str(user.id),
        full_name=user.full_name
    )

@router.post("/logout")
def logout(payload: TokenRefreshRequest, db: Session = Depends(get_db)):
    """Révoquer le Refresh Token d'un utilisateur pour le déconnecter."""
    db_token = db.query(RefreshToken).filter(RefreshToken.token == payload.refresh_token).first()
    if db_token:
        db.delete(db_token)
        db.commit()
    return {"message": "Déconnexion réussie et backend nettoyé."}

@router.post("/logout-all")
def logout_all_devices(current_user: Profile = Depends(get_current_user), db: Session = Depends(get_db)):
    """Invalider toutes les sessions actives sur tous les appareils."""
    # Incrémenter la version du token rend instantanément invalides tous les JWT existants
    current_user.token_version += 1
    
    # Révoquer également tous les refresh tokens existants
    db.query(RefreshToken).filter(RefreshToken.user_id == current_user.id).delete()
    
    db.commit()
    return {"message": "Déconnexion de tous les appareils réussie."}

@router.post("/refresh", response_model=TokenResponse)
def refresh_token(request: TokenRefreshRequest, db: Session = Depends(get_db)):
    """Échanger un Refresh Token contre un nouveau duo de tokens."""
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == request.refresh_token,
        RefreshToken.expires_at > datetime.now(timezone.utc)
    ).first()

    if not db_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide ou expiré."
        )

    # Récupérer l'utilisateur
    user = db.query(Profile).filter(Profile.id == db_token.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé.")

    # Générer de nouveaux tokens
    new_access_token = create_access_token(data={"sub": str(user.id), "version": user.token_version})
    # On peut optionnellement générer un nouveau refresh token (rotation) 
    # ou garder le même. Ici on va le faire tourner pour plus de sécurité.
    new_refresh_token = create_refresh_token(db, str(user.id))

    # Supprimer l'ancien refresh token
    db.delete(db_token)
    db.commit()

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        user_id=str(user.id),
        full_name=user.full_name
    )


@router.get("/me", response_model=ProfileResponse)
def get_me(current_user: Profile = Depends(get_current_user)):
    """Récupérer le profil de l'utilisateur connecté."""
    return current_user
