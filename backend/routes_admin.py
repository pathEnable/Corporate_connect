from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from database import get_db
from models import Profile, Message, Room, RoomMember, Status
from routes_auth import get_current_user

router = APIRouter(prefix="/admin", tags=["Admin"])

def check_admin(current_user: Profile = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Accès réservé aux administrateurs.")
    return current_user

@router.get("/stats")
def get_stats(
    db: Session = Depends(get_db),
    admin: Profile = Depends(check_admin)
):
    """Statistiques globales de l'organisation."""
    total_users = db.query(Profile).count()
    active_users = db.query(Profile).filter(Profile.is_online == True).count()
    banned_users = db.query(Profile).filter(Profile.is_active == False).count()
    total_messages = db.query(Message).count()
    total_rooms = db.query(Room).count()
    total_groups = db.query(Room).filter(Room.is_group == True).count()
    total_statuses = db.query(Status).count()

    return {
        "total_users": total_users,
        "active_users": active_users,
        "banned_users": banned_users,
        "total_messages": total_messages,
        "total_rooms": total_rooms,
        "total_groups": total_groups,
        "total_statuses": total_statuses,
    }

@router.get("/users")
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: Profile = Depends(check_admin)
):
    """Lister les utilisateurs avec pagination."""
    total = db.query(Profile).count()
    users = db.query(Profile).offset(skip).limit(limit).all()
    return {
        "total": total,
        "users": [
            {
                "id": str(u.id),
                "full_name": u.full_name,
                "username": u.username,
                "email": u.email,
                "is_online": u.is_online,
                "is_active": u.is_active,
                "is_admin": u.is_admin,
                "avatar_url": u.avatar_url,
            }
            for u in users
        ]
    }

@router.post("/users/{user_id}/toggle-active")
def toggle_user_active(
    user_id: str,
    db: Session = Depends(get_db),
    admin: Profile = Depends(check_admin)
):
    """Activer ou désactiver (bannir) un utilisateur."""
    user = db.query(Profile).filter(Profile.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé.")
    
    user.is_active = not user.is_active
    db.commit()
    return {"id": user_id, "is_active": user.is_active, "message": "Statut mis à jour."}
