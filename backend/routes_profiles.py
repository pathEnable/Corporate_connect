from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from uuid import UUID
from database import get_db
from models import Profile
from routes_auth import get_current_user

router = APIRouter(prefix="/profiles", tags=["Profiles"])


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    username: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    job_title: Optional[str] = None
    public_key: Optional[str] = None


class ProfileResponse(BaseModel):
    id: UUID
    email: Optional[str]
    phone_number: Optional[str]
    full_name: str
    username: str
    avatar_url: Optional[str]
    is_online: bool
    public_key: Optional[str] = None

    class Config:
        from_attributes = True


@router.put("/me", response_model=ProfileResponse)
def update_profile(
    request: ProfileUpdateRequest,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Mettre à jour le profil de l'utilisateur connecté."""
    if request.full_name is not None:
        current_user.full_name = request.full_name
    if request.username is not None:
        existing = db.query(Profile).filter(
            Profile.username == request.username,
            Profile.id != current_user.id,
        ).first()
        if existing:
            raise HTTPException(status_code=409, detail="Ce nom d'utilisateur est déjà pris.")
        current_user.username = request.username
    if request.avatar_url is not None:
        current_user.avatar_url = request.avatar_url
    if request.bio is not None:
        current_user.bio = request.bio
    if request.job_title is not None:
        current_user.job_title = request.job_title
    if request.public_key is not None:
        current_user.public_key = request.public_key

    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/search", response_model=List[ProfileResponse])
def search_users(
    q: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Rechercher des utilisateurs par nom ou username."""
    results = db.query(Profile).filter(
        Profile.id != current_user.id,
        (Profile.full_name.ilike(f"%{q}%")) | (Profile.username.ilike(f"%{q}%"))
    ).limit(20).all()
    return results


@router.get("/directory", response_model=List[ProfileResponse])
def company_directory(
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Lister tous les employés de l'entreprise (annuaire)."""
    users = db.query(Profile).filter(
        Profile.id != current_user.id
    ).order_by(Profile.full_name).all()
    return users


@router.get("/{user_id}", response_model=ProfileResponse)
def get_profile(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Récupérer le profil d'un utilisateur spécifique."""
    user = db.query(Profile).filter(Profile.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé.")
    return user
