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
    department: Optional[str] = None   # Nouveau
    skills: Optional[str] = None       # Nouveau (CSV : "Python,Flutter,SQL")
    public_key: Optional[str] = None
    presence_status: Optional[str] = None


class ProfileResponse(BaseModel):
    id: UUID
    email: Optional[str]
    phone_number: Optional[str]
    full_name: str
    username: str
    avatar_url: Optional[str]
    bio: Optional[str] = None
    job_title: Optional[str] = None
    is_online: bool
    presence_status: str
    is_active: bool = True
    is_admin: bool = False
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
    if request.department is not None:
        current_user.department = request.department
    if request.skills is not None:
        current_user.skills = request.skills
    if request.public_key is not None:
        current_user.public_key = request.public_key
    if request.presence_status is not None:
        current_user.presence_status = request.presence_status

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
    q: Optional[str] = None,
    department: Optional[str] = None,
    presence_status: Optional[str] = None,
    skills: Optional[str] = None,
):
    """Lister tous les employés de l'entreprise avec filtres optionnels."""
    query = db.query(Profile).filter(Profile.id != current_user.id, Profile.is_active == True)

    if q:
        query = query.filter(
            (Profile.full_name.ilike(f"%{q}%")) |
            (Profile.username.ilike(f"%{q}%")) |
            (Profile.job_title.ilike(f"%{q}%"))
        )
    if department:
        query = query.filter(Profile.department.ilike(f"%{department}%"))
    if presence_status:
        query = query.filter(Profile.presence_status == presence_status)
    if skills:
        # Chercher dans le champ CSV de compétences
        query = query.filter(Profile.skills.ilike(f"%{skills}%"))

    users = query.order_by(Profile.is_online.desc(), Profile.full_name).all()
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
