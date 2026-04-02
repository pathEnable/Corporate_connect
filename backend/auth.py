from datetime import datetime, timedelta
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
        return None
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
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


from models import RefreshToken

def create_refresh_token(db: Session, user_id: str) -> str:
    """Génère un token de rafraîchissement et le stocke en base de données."""
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(days=30) # Valide 30 jours
    
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
    token_query: Optional[str] = Query(None, alias="token"),
    db: Session = Depends(get_db)
) -> Profile:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token invalide ou expiré",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # Utiliser le token du query param si le header est vide ou invalide
    # oauth2_scheme peut retourner une chaîne vide ou None avec auto_error=False
    actual_token = token if (token and token.strip()) else token_query
    
    if not actual_token:
        # Si aucun token n'est fourni, on lève l'exception standard
        raise credentials_exception

    try:
        payload = jwt.decode(actual_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str: str = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
        user_id = user_id_str
    except JWTError:
        raise credentials_exception

    user = db.query(Profile).filter(Profile.id == user_id).first()
    if user is None:
        raise credentials_exception
    return user
