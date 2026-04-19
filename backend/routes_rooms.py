import uuid
import asyncio
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from database import get_db
from models import Message, Room, RoomMember, Profile
from schemas import RoomResponse, MessageResponse, RoomMemberResponse
from routes_auth import get_current_user
from security_utils import decrypt_data
from dependencies import get_current_room_member
from collections import defaultdict
from routes_chat import broadcast_to_users

router = APIRouter(prefix="/rooms", tags=["Rooms"])


async def _broadcast_room_created(member_ids: list, event: dict):
    """Helper async pour broadcaster la création d'un salon."""
    await broadcast_to_users(member_ids, event)

@router.get("", response_model=List[RoomResponse])
@router.get("/", response_model=List[RoomResponse], include_in_schema=False)
def list_rooms(
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Lister tous les salons de l'utilisateur connecté."""
    memberships = db.query(RoomMember).filter(RoomMember.profile_id == current_user.id).all()
    room_ids = [m.room_id for m in memberships]

    if not room_ids:
        return []

    rooms = db.query(Room).filter(Room.id.in_(room_ids)).all()

    # Optimisation N+1 : Récupérer le dernier message de chaque salon en une requête structurée
    latest_messages = (
        db.query(Message)
        .filter(Message.room_id.in_(room_ids))
        .distinct(Message.room_id)
        .order_by(Message.room_id, Message.created_at.desc())
        .all()
    )
    last_msg_map = {m.room_id: m.content for m in latest_messages}

    # Optimisation N+1 (Contacts) : Récupérer tous les membres pour résoudre le nom des discussions privées (1:1)
    all_members = db.query(RoomMember).filter(RoomMember.room_id.in_(room_ids)).all()
    members_by_room = defaultdict(list)
    for m in all_members:
        members_by_room[m.room_id].append(m)
        
    profile_ids = {m.profile_id for m in all_members}
    profiles = db.query(Profile).filter(Profile.id.in_(profile_ids)).all()
    profiles_dict = {p.id: p for p in profiles}

    result = []
    for room in rooms:
        last_content = last_msg_map.get(room.id)
        
        display_name = room.name
        if not room.is_group:
            # Trouver l'autre membre
            other_m = next((m for m in members_by_room.get(room.id, []) if str(m.profile_id) != str(current_user.id)), None)
            if other_m and other_m.profile_id in profiles_dict:
                display_name = profiles_dict[other_m.profile_id].full_name

        result.append(RoomResponse(
            id=room.id,
            name=display_name,
            is_group=room.is_group,
            last_message=last_content,
        ))

    return result

@router.post("", response_model=RoomResponse)
@router.post("/", response_model=RoomResponse, include_in_schema=False)
def create_room(
    room_data: dict,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Créer un nouveau salon (1:1 ou Groupe)."""
    name = room_data.get("name")
    is_group = room_data.get("is_group", False)
    member_ids = room_data.get("member_ids", [])

    # --- ANTI-DOUBLON : Pour les discussions privées (1:1), vérifier si un salon existe déjà ---
    if not is_group and len(member_ids) == 1:
        target_id = str(member_ids[0])
        current_id = str(current_user.id)
        
        # Trouver tous les salons privés de l'utilisateur courant
        my_rooms = db.query(RoomMember.room_id).filter(
            RoomMember.profile_id == current_id
        ).subquery()
        
        # Trouver les salons où l'autre membre est aussi présent ET qui ne sont pas des groupes
        existing_room = (
            db.query(Room)
            .join(RoomMember, Room.id == RoomMember.room_id)
            .filter(
                Room.id.in_(db.query(my_rooms.c.room_id)),
                Room.is_group == False,
                RoomMember.profile_id == target_id,
            )
            .first()
        )
        
        if existing_room:
            # Résoudre le nom d'affichage (nom de l'autre membre)
            other_profile = db.query(Profile).filter(Profile.id == target_id).first()
            display_name = other_profile.full_name if other_profile else existing_room.name
            
            return RoomResponse(
                id=existing_room.id,
                name=display_name,
                is_group=False,
            )
    # -------------------------------------------------------------------

    # Créer le salon
    new_room = Room(id=uuid.uuid4(), name=name, is_group=is_group)
    db.add(new_room)
    db.flush() # Pour avoir l'ID du salon

    # Ajouter le créateur comme membre et ADMIN
    creator_member = RoomMember(
        room_id=new_room.id,
        profile_id=current_user.id,
        is_admin_member=True # Le créateur est toujours admin
    )
    db.add(creator_member)

    # Ajouter les autres membres
    for m_id in member_ids:
        if str(m_id) != str(current_user.id):
            # SQLAlchemy requiert des objets UUID pour les insertions en batch sur PostgreSQL
            profile_uuid = uuid.UUID(str(m_id)) if isinstance(m_id, str) else m_id
            
            new_member = RoomMember(
                room_id=new_room.id,
                profile_id=profile_uuid,
                is_admin_member=False
            )
            db.add(new_member)

    db.commit()

    # --- Broadcast temps réel : Notifier tous les membres du nouveau salon ---
    all_member_ids = [str(current_user.id)] + [str(m) for m in member_ids]
    room_event = {
        "type": "room_created",
        "room_id": str(new_room.id),
        "room_name": new_room.name,
        "is_group": new_room.is_group,
        "created_by": str(current_user.id),
        "member_ids": all_member_ids,
    }
    background_tasks.add_task(asyncio.get_event_loop().run_until_complete if False else _broadcast_room_created, all_member_ids, room_event)
    
    return RoomResponse(
        id=new_room.id,
        name=new_room.name,
        is_group=new_room.is_group,
    )

@router.post("/{room_id}/members/promote")
def promote_member(
    room_id: str,
    target_user_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
    membership: RoomMember = Depends(get_current_room_member)
):
    """Promouvoir un membre au statut d'admin."""
    # Vérifier que l'appelant est admin de ce salon
    if not membership.is_admin_member:
        raise HTTPException(status_code=403, detail="Seuls les administrateurs peuvent promouvoir d'autres membres.")

    # Trouver la cible
    target = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.profile_id == target_user_id
    ).first()

    if not target:
        raise HTTPException(status_code=404, detail="Membre non trouvé dans ce salon.")

    target.is_admin_member = True
    db.commit()
    return {"message": "Utilisateur promu admin."}

@router.post("/{room_id}/members/demote")
def demote_member(
    room_id: str,
    target_user_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
    membership: RoomMember = Depends(get_current_room_member)
):
    """Rétrograder un administrateur."""
    # Vérifier que l'appelant est admin
    if not membership.is_admin_member:
        raise HTTPException(status_code=403, detail="Seuls les administrateurs peuvent rétrograder d'autres membres.")

    target = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.profile_id == target_user_id
    ).first()

    if not target:
        raise HTTPException(status_code=404, detail="Membre non trouvé.")

    target.is_admin_member = False
    db.commit()
    return {"message": "Utilisateur rétrogradé."}


@router.get("/{room_id}/messages", response_model=List[MessageResponse])
def get_messages(
    room_id: str,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
    _membership: RoomMember = Depends(get_current_room_member)
):
    """Récupérer l'historique des messages d'un salon."""
    messages = (
        db.query(Message)
        .filter(Message.room_id == room_id)
        .filter(Message.message_type != 'reaction')
        .order_by(Message.created_at.desc())
        .limit(limit)
        .all()
    )


    return [
        MessageResponse(
            id=msg.id,
            sender_id=msg.sender_id,
            content=msg.content, # Contenu chiffré E2EE envoyé tel quel
            message_type=msg.message_type,
            reply_to_id=msg.reply_to_id,
            is_read=msg.is_read,
            reactions=msg.metadata_.get("reactions") if msg.metadata_ else None,
            metadata_=msg.metadata_,
            created_at=msg.created_at.isoformat() if msg.created_at else "",
        )
        for msg in reversed(messages)
    ]

@router.get("/{room_id}/members", response_model=List[RoomMemberResponse])
def get_room_members(
    room_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
    _membership: RoomMember = Depends(get_current_room_member)
):
    """Lister les membres d'un salon avec leurs clés publiques."""
    from sqlalchemy.orm import joinedload
    members = db.query(RoomMember).options(joinedload(RoomMember.profile)).filter(RoomMember.room_id == room_id).all()
    
    result = []
    for m in members:
        p = m.profile
        result.append(RoomMemberResponse(
            id=p.id,
            full_name=p.full_name,
            public_key=p.public_key,
            is_admin_member=m.is_admin_member
        ))
    return result

@router.post("/{room_id}/members")
def add_member(
    room_id: str,
    target_user_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
    _membership: RoomMember = Depends(get_current_room_member)
):
    """Ajouter un membre à un salon (Admin seulement pour les groupes)."""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Salon non trouvé.")

    # Si c'est un groupe, seul un admin peut ajouter
    if room.is_group:
        caller = db.query(RoomMember).filter(
            RoomMember.room_id == room_id,
            RoomMember.profile_id == current_user.id
        ).first()
        if not caller or not caller.is_admin_member:
            raise HTTPException(status_code=403, detail="Seuls les administrateurs peuvent ajouter des membres.")

    # Vérifier si déjà membre
    existing = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.profile_id == target_user_id
    ).first()
    if existing:
        return {"message": "Déjà membre."}

    # Utilisation d'objets UUID pour éviter le KeyError SQLAlchemy (batch inserts)
    room_uuid = uuid.UUID(str(room_id)) if isinstance(room_id, str) else room_id
    target_uuid = uuid.UUID(str(target_user_id)) if isinstance(target_user_id, str) else target_user_id
    
    new_member = RoomMember(room_id=room_uuid, profile_id=target_uuid, is_admin_member=False)
    db.add(new_member)
    db.commit()
    return {"message": "Membre ajouté."}

@router.delete("/{room_id}/members/{profile_id}")
def remove_member(
    room_id: str,
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
    _membership: RoomMember = Depends(get_current_room_member)
):
    """Retirer un membre (Admin seulement)."""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Salon non trouvé.")

    # Seul un admin peut retirer (sauf si on se retire soi-même ?)
    # Pour l'instant, on impose admin pour retirer QUELQU'UN. 
    # Un utilisateur peut se retirer lui-même (Leave Room).
    
    is_self_removal = str(profile_id) == str(current_user.id)
    
    if not is_self_removal:
        caller = db.query(RoomMember).filter(
            RoomMember.room_id == room_id,
            RoomMember.profile_id == current_user.id
        ).first()
        if not caller or not caller.is_admin_member:
            raise HTTPException(status_code=403, detail="Seuls les administrateurs peuvent retirer des membres.")

    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.profile_id == profile_id
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Membre non trouvé.")

    db.delete(member)
    db.commit()
    return {"message": "Membre retiré."}
