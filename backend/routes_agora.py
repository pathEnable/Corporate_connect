import time
import os
from fastapi import APIRouter, Depends, HTTPException
from agora_token_builder import RtcTokenBuilder
from config import AGORA_APP_ID, AGORA_APP_CERTIFICATE
from routes_auth import get_current_user
from models import Profile

router = APIRouter(prefix="/agora", tags=["Agora"])

@router.get("/token")
def get_agora_token(
    channel_name: str,
    uid: int = 0,
    current_user: Profile = Depends(get_current_user)
):
    """
    Génère un token RTC Agora pour un canal spécifique.
    uid=0 permet à Agora d'attribuer un UID automatiquement ou d'utiliser celui fourni.
    """
    if not AGORA_APP_ID or not AGORA_APP_CERTIFICATE:
        raise HTTPException(status_code=500, detail="Agora configuration is missing on server")

    # Rôle 1 = Attendee (peut publier et souscrire)
    role = 1
    # Expiration du token (1 heure par défaut)
    expiration_time_in_seconds = 3600
    current_timestamp = int(time.time())
    privilege_expired_ts = current_timestamp + expiration_time_in_seconds

    try:
        token = RtcTokenBuilder.buildTokenWithUid(
            AGORA_APP_ID, 
            AGORA_APP_CERTIFICATE, 
            channel_name, 
            uid, 
            role, 
            privilege_expired_ts
        )
        return {"token": token, "app_id": AGORA_APP_ID}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating token: {str(e)}")
