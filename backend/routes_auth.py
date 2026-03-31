import secrets
import redis
from config import REDIS_URL
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models import Profile
from schemas import RegisterRequest, LoginRequest, OTPRequest, OTPVerify, TokenResponse, ProfileResponse, TokenRefreshRequest
from auth import hash_password, verify_password, create_access_token, get_current_user, create_refresh_token
from models import RefreshToken
import uuid
from datetime import datetime
router = APIRouter(prefix="/auth", tags=["Authentication"])

# Connexion Redis pour le stockage des OTP
redis_client = redis.from_url(REDIS_URL, decode_responses=True)


@router.post("/register", response_model=TokenResponse)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    """Créer un nouveau compte utilisateur."""
    if not request.email and not request.phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email ou numéro de téléphone requis."
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

    token = create_access_token(data={"sub": str(new_user.id)})
    refresh_token = create_refresh_token(db, str(new_user.id))
    
    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=str(new_user.id),
        full_name=new_user.full_name
    )


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Connexion par Email et mot de passe."""
    if not request.email or not request.password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email et mot de passe requis."
        )

    user = db.query(Profile).filter(Profile.email == request.email).first()
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect."
        )

    token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(db, str(user.id))

    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=str(user.id),
        full_name=user.full_name
    )


@router.post("/otp/send")
def send_otp(request: OTPRequest):
    """Envoyer un code OTP par SMS (simulé) avec stockage Redis."""
    # Génération sécurisée d'un code à 6 chiffres
    otp_code = "".join([secrets.choice("0123456789") for _ in range(6)])
    
    # Stockage dans Redis avec expiration (5 minutes / 300 secondes)
    redis_key = f"otp:{request.phone_number}"
    redis_client.set(redis_key, otp_code, ex=300)
    
    # En production : intégrer Twilio ou un service SMS
    return {"message": f"Code OTP envoyé (dev: {otp_code})"}


@router.post("/otp/verify", response_model=TokenResponse)
def verify_otp(request: OTPVerify, db: Session = Depends(get_db)):
    """Vérifier le code OTP stocké dans Redis et connecter l'utilisateur."""
    redis_key = f"otp:{request.phone_number}"
    stored_otp = redis_client.get(redis_key)
    
    if not stored_otp or stored_otp != request.otp_code:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Code OTP invalide ou expiré."
        )

    # Supprimer l'OTP après vérification réussie
    redis_client.delete(redis_key)

    user = db.query(Profile).filter(Profile.phone_number == request.phone_number).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucun compte associé à ce numéro."
        )

    token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(db, str(user.id))

    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=str(user.id),
        full_name=user.full_name
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(request: TokenRefreshRequest, db: Session = Depends(get_db)):
    """Échanger un Refresh Token contre un nouveau duo de tokens."""
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == request.refresh_token,
        RefreshToken.expires_at > datetime.utcnow()
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
    new_access_token = create_access_token(data={"sub": str(user.id)})
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
