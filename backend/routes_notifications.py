from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from schemas import RegisterTokenRequest
from routes_auth import get_current_user
from models import Profile

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.post("/register-token")
def register_fcm_token(
    request: RegisterTokenRequest,
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Enregistre ou met à jour le token FCM de l'utilisateur."""
    current_user.fcm_token = request.fcm_token
    db.commit()
    return {"message": "Token FCM enregistré avec succès"}
