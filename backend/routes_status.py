from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models import Status, Profile
from routes_auth import get_current_user
from schemas import StatusResponse, StatusCreate
import uuid

router = APIRouter(prefix="/status", tags=["Status"])

@router.post("", response_model=StatusResponse)
@router.post("/", response_model=StatusResponse, include_in_schema=False)
async def create_status(
    status_data: StatusCreate,
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Créer un nouveau statut expirant dans 24h."""
    expires_at = datetime.utcnow() + timedelta(hours=24)
    
    new_status = Status(
        id=uuid.uuid4(),
        user_id=current_user.id,
        media_url=status_data.media_url,
        text=status_data.text,
        expires_at=expires_at
    )
    db.add(new_status)
    db.commit()
    db.refresh(new_status)
    
    return StatusResponse(
        id=new_status.id,
        user_id=new_status.user_id,
        user_name=current_user.full_name,
        user_avatar=current_user.avatar_url,
        media_url=new_status.media_url,
        text=new_status.text,
        created_at=new_status.created_at.isoformat()
    )

@router.get("", response_model=List[StatusResponse])
@router.get("/", response_model=List[StatusResponse], include_in_schema=False)
async def get_statuses(
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user)
):
    """Récupérer tous les statuts actifs (non expirés)."""
    now = datetime.utcnow()
    statuses = db.query(Status).filter(Status.expires_at > now).all()
    
    return [
        StatusResponse(
            id=s.id,
            user_id=s.user_id,
            user_name=s.user.full_name,
            user_avatar=s.user.avatar_url,
            media_url=s.media_url,
            text=s.text,
            created_at=s.created_at.isoformat()
        )
        for s in statuses
    ]
