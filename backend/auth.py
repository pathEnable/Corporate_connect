from datetime import datetime, timedelta, timezone
from typing import Optional
import secrets
import bcrypt
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES
from database import get_db
from models import Profile

# Suppression de passlib context qui bug avec bcrypt 4.0+/Python 3.14
#oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def hash_password(password: str) -> str:
    """Hache un mot de passe en utilisant bcrypt."""
    if not password:
        raise ValueError("Le mot de passe ne peut pas être vide.")
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Vérifie un mot de passe haché."""
    if not plain_password or not hashed_password:
        return False
    try:
        return bcrypt.checkpw(
            plain_password.encode('utf-8'),
            hashed_password.encode('utf-8')
        )
    except Exception:
        return False


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


from models import RefreshToken

def create_refresh_token(db: Session, user_id: str) -> str:
    """Génère un token de rafraîchissement et le stocke en base de données."""
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(days=30)  # Valide 30 jours
    
    db_token = RefreshToken(
        user_id=user_id,
        token=token,
        expires_at=expires_at
    )
    db.add(db_token)
    return token


from fastapi import Depends, HTTPException, status, Query

def get_current_user(
    token: str = Depends(oauth2_scheme), 
    db: Session = Depends(get_db)
) -> Profile:
    """Authentification par header Authorization (routes REST uniquement)."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token invalide ou expiré",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    if not token or not token.strip():
        raise credentials_exception

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str: str = payload.get("sub")
        token_version = payload.get("version")
        if user_id_str is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(Profile).filter(Profile.id == user_id_str).first()
    if user is None:
        raise credentials_exception

    # Vérification de la version du token (invalidation multi-appareils)
    if token_version is None or token_version != user.token_version:
        raise credentials_exception
    
    # Vérifier que le compte est actif
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce compte a été désactivé."
        )
    return user


def get_current_user_ws(
    token: Optional[str] = None, 
    token_query: Optional[str] = Query(None, alias="token"),
    db: Session = Depends(get_db)
) -> Profile:
    """Authentification pour WebSockets (accepté en query param car les WS 
    ne supportent pas les headers Authorization). NE PAS utiliser pour les routes REST."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token invalide ou expiré",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    actual_token = token if (token and token.strip()) else token_query
    
    if not actual_token:
        raise credentials_exception

    try:
        payload = jwt.decode(actual_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str: str = payload.get("sub")
        token_version = payload.get("version")
        if user_id_str is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(Profile).filter(Profile.id == user_id_str).first()
    if user is None:
        raise credentials_exception

    # Vérification de la version du token
    if token_version is None or token_version != user.token_version:
        raise credentials_exception
        
    return user
