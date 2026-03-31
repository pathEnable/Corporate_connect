from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models import RoomMember, Profile
from auth import get_current_user

def get_current_room_member(
    room_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user)
) -> RoomMember:
    """
    Vérifie si l'utilisateur actuel est membre du salon spécifié.
    Lève une exception 403 s'il n'est pas membre.
    """
    membership = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.profile_id == current_user.id
    ).first()

    if not membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous n'êtes pas membre de ce salon et ne pouvez pas accéder à ses données."
        )
    
    return membership
