from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Dict
from database import get_db
from models import Profile, Room, Message, RoomMember
from routes_auth import get_current_user
from security_utils import decrypt_data

router = APIRouter(prefix="/search", tags=["Global Search"])

@router.get("/global")
def global_search(
    q: str = Query(..., min_length=2),
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user)
):
    """Recherche globale dans les profils, salons et messages."""
    
    # 1. Recherche de Profils (exclure soi-même)
    profiles = db.query(Profile).filter(
        Profile.id != current_user.id,
        Profile.is_active == True,
        (Profile.full_name.ilike(f"%{q}%")) | (Profile.username.ilike(f"%{q}%"))
    ).limit(10).all()
    
    # 2. Recherche de Salons (filtré par appartenance)
    user_room_ids = [
        m.room_id for m in db.query(RoomMember).filter(RoomMember.profile_id == current_user.id).all()
    ]
    rooms = db.query(Room).filter(
        Room.id.in_(user_room_ids),
        Room.name.ilike(f"%{q}%")
    ).limit(10).all()
    
    return {
        "profiles": [
            {"id": str(p.id), "name": p.full_name, "username": p.username, "avatar": p.avatar_url}
            for p in profiles
        ],
        "rooms": [
            {"id": str(r.id), "name": r.name, "is_group": r.is_group}
            for r in rooms
        ]
    }
