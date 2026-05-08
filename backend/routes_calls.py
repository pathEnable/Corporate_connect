import time
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from database import get_db
from models import CallLog, Profile, RoomMember
from schemas import CallLogCreate, CallLogResponse, CallInitiateRequest, CallInitiateResponse
from routes_auth import get_current_user
from typing import List
from uuid import UUID
import datetime
from config import AGORA_APP_ID, AGORA_APP_CERTIFICATE
from agora_token_builder import RtcTokenBuilder
from firebase_admin_config import send_push_notification

router = APIRouter(prefix="/calls", tags=["Calls"])


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALISATION D'APPEL — Endpoints pour le cycle de vie complet
# ═══════════════════════════════════════════════════════════════════════════════

def _generate_agora_token(channel_name: str, uid: int = 0) -> tuple:
    """Génère un token Agora RTC et retourne (token, app_id)."""
    if not AGORA_APP_ID or not AGORA_APP_CERTIFICATE:
        raise HTTPException(status_code=500, detail="Agora configuration is missing on server")

    role = 1  # Attendee
    expiration_time = 3600
    current_ts = int(time.time())
    privilege_expired_ts = current_ts + expiration_time

    token = RtcTokenBuilder.buildTokenWithUid(
        AGORA_APP_ID, AGORA_APP_CERTIFICATE,
        channel_name, uid, role, privilege_expired_ts
    )
    return token, AGORA_APP_ID


async def _notify_user(db: Session, user_id, event_type: str, data: dict):
    """Envoie un événement via WebSocket global + push FCM."""
    from routes_chat import broadcast_to_users

    user_ids = [str(user_id)]

    # 1. WebSocket global (temps réel si l'app est ouverte)
    payload = {"type": event_type, **data}
    try:
        await broadcast_to_users(user_ids, payload)
    except Exception as e:
        print(f"[Call Signaling] Erreur WS broadcast: {e}")

    # 2. Push FCM (pour arrière-plan / app fermée)
    profile = db.query(Profile).filter(Profile.id == user_id).first()
    if profile and profile.fcm_token:
        fcm_data = {
            "type": event_type,
            "call_id": data.get("call_id", ""),
            "caller_name": data.get("caller_name", ""),
            "caller_avatar": data.get("caller_avatar", ""),
            "room_id": data.get("room_id", ""),
            "is_video": str(data.get("is_video", False)).lower(),
            "channel_name": data.get("channel_name", ""),
        }
        # Les événements d'appel utilisent is_call=True pour la priorité FCM maximale
        is_call_event = event_type in ("call_offer", "call_cancel")
        send_push_notification(
            token=profile.fcm_token,
            title=data.get("caller_name", "Appel entrant"),
            body="Appel vidéo entrant..." if data.get("is_video") else "Appel audio entrant...",
            data=fcm_data,
            is_call=is_call_event,
        )


@router.post("/initiate", response_model=CallInitiateResponse)
async def initiate_call(
    request: CallInitiateRequest,
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    L'appelant initie un appel. Crée un CallLog, génère un token Agora,
    et notifie le(s) destinataire(s) via WS global + push FCM.
    """
    # Trouver le(s) destinataire(s) dans la room
    other_members = db.query(RoomMember).filter(
        RoomMember.room_id == request.room_id,
        RoomMember.profile_id != current_user.id
    ).all()

    if not other_members:
        raise HTTPException(status_code=404, detail="Aucun autre membre dans cette conversation")

    receiver_id = other_members[0].profile_id  # Pour un chat 1-to-1

    # Créer le CallLog avec status=ringing
    channel_name = f"call_{request.room_id}_{int(time.time())}"
    
    new_call = CallLog(
        caller_id=current_user.id,
        receiver_id=receiver_id,
        room_id=request.room_id,
        start_time=datetime.datetime.now(datetime.timezone.utc),
        status="ringing",
        call_type="video" if request.is_video else "audio",
    )
    db.add(new_call)
    db.commit()
    db.refresh(new_call)

    # Générer le token Agora pour l'appelant
    token, app_id = _generate_agora_token(channel_name)

    # Notifier le(s) destinataire(s)
    for member in other_members:
        await _notify_user(db, member.profile_id, "call_offer", {
            "call_id": str(new_call.id),
            "caller_name": current_user.full_name,
            "caller_avatar": current_user.avatar_url or "",
            "room_id": str(request.room_id),
            "is_video": request.is_video,
            "channel_name": channel_name,
        })

    return CallInitiateResponse(
        call_id=new_call.id,
        agora_token=token,
        app_id=app_id,
        channel_name=channel_name,
    )


@router.post("/{call_id}/answer")
async def answer_call(
    call_id: UUID,
    data: dict = Body(...),
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Le destinataire accepte l'appel. Met à jour le statut et
    retourne le token Agora pour rejoindre le canal.
    """
    channel_name = data.get("channel_name")
    call = db.query(CallLog).filter(CallLog.id == call_id).first()
    if not call:
        raise HTTPException(status_code=404, detail="Appel introuvable")
    if call.status != "ringing":
        raise HTTPException(status_code=409, detail="L'appel n'est plus en attente")

    call.status = "answered"
    db.commit()

    # Utiliser le channel_name fourni par le client, ou le recalculer
    if not channel_name:
        channel_name = f"call_{call.room_id}_{int(call.start_time.timestamp())}"
    token, app_id = _generate_agora_token(channel_name)

    # Notifier l'appelant que B a décroché
    await _notify_user(db, call.caller_id, "call_answered", {
        "call_id": str(call_id),
        "answerer_name": current_user.full_name,
        "room_id": str(call.room_id),
    })

    return {
        "agora_token": token,
        "app_id": app_id,
        "channel_name": channel_name,
        "call_type": call.call_type,
    }


@router.post("/{call_id}/reject")
async def reject_call(
    call_id: UUID,
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Le destinataire refuse l'appel."""
    call = db.query(CallLog).filter(CallLog.id == call_id).first()
    if not call:
        raise HTTPException(status_code=404, detail="Appel introuvable")

    call.status = "rejected"
    call.end_time = datetime.datetime.now(datetime.timezone.utc)
    call.duration = 0
    db.commit()

    # Notifier l'appelant
    await _notify_user(db, call.caller_id, "call_rejected", {
        "call_id": str(call_id),
        "rejector_name": current_user.full_name,
        "room_id": str(call.room_id),
    })

    return {"detail": "Appel refusé"}


@router.post("/{call_id}/end")
async def end_call(
    call_id: UUID,
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Un des participants raccroche pendant un appel actif."""
    call = db.query(CallLog).filter(CallLog.id == call_id).first()
    if not call:
        raise HTTPException(status_code=404, detail="Appel introuvable")

    now = datetime.datetime.now(datetime.timezone.utc)
    call.status = "completed"
    call.end_time = now
    if call.start_time:
        call.duration = int((now - call.start_time).total_seconds())
    db.commit()

    # Notifier l'autre participant
    other_user_id = call.receiver_id if str(call.caller_id) == str(current_user.id) else call.caller_id
    if other_user_id:
        await _notify_user(db, other_user_id, "call_ended", {
            "call_id": str(call_id),
            "ended_by": current_user.full_name,
            "room_id": str(call.room_id),
            "duration": call.duration,
        })

    return {"detail": "Appel terminé", "duration": call.duration}


@router.post("/{call_id}/cancel")
async def cancel_call(
    call_id: UUID,
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """L'appelant annule avant que le destinataire ne décroche."""
    call = db.query(CallLog).filter(CallLog.id == call_id).first()
    if not call:
        raise HTTPException(status_code=404, detail="Appel introuvable")

    call.status = "missed"
    call.end_time = datetime.datetime.now(datetime.timezone.utc)
    call.duration = 0
    db.commit()

    # Notifier le destinataire pour arrêter la sonnerie
    if call.receiver_id:
        await _notify_user(db, call.receiver_id, "call_cancel", {
            "call_id": str(call_id),
            "room_id": str(call.room_id),
        })

    return {"detail": "Appel annulé"}


# ═══════════════════════════════════════════════════════════════════════════════
# HISTORIQUE D'APPELS — Routes existantes conservées
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/log", response_model=CallLogResponse)
def log_call(call_data: CallLogCreate, current_user: Profile = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Log a call when it ends or is rejected/missed.
    """
    receiver = None
    if call_data.receiver_id:
        receiver = db.query(Profile).filter(Profile.id == call_data.receiver_id).first()
        if not receiver:
            raise HTTPException(status_code=404, detail="Receiver not found")
    elif call_data.room_id:
        other_member = db.query(RoomMember).filter(
            RoomMember.room_id == call_data.room_id,
            RoomMember.profile_id != current_user.id
        ).first()
        if other_member:
            call_data.receiver_id = other_member.profile_id
            receiver = db.query(Profile).filter(Profile.id == call_data.receiver_id).first()

    start_dt = datetime.datetime.fromisoformat(call_data.start_time.replace("Z", "+00:00"))
    
    end_dt = None
    if call_data.end_time:
        end_dt = datetime.datetime.fromisoformat(call_data.end_time.replace("Z", "+00:00"))

    new_call = CallLog(
        caller_id=current_user.id,
        receiver_id=call_data.receiver_id,
        room_id=call_data.room_id,
        start_time=start_dt,
        end_time=end_dt,
        duration=call_data.duration,
        status=call_data.status,
        call_type=call_data.call_type
    )
    db.add(new_call)
    db.commit()
    db.refresh(new_call)

    caller_name = current_user.full_name
    receiver_name = receiver.full_name if receiver else None

    return CallLogResponse(
        id=new_call.id,
        caller_id=new_call.caller_id,
        receiver_id=new_call.receiver_id,
        room_id=new_call.room_id,
        start_time=new_call.start_time.isoformat(),
        end_time=new_call.end_time.isoformat() if new_call.end_time else None,
        duration=new_call.duration,
        status=new_call.status,
        call_type=new_call.call_type,
        caller_name=caller_name,
        receiver_name=receiver_name
    )

@router.get("/history", response_model=List[CallLogResponse])
def get_call_history(current_user: Profile = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Get the call history of the current user (calls made and received).
    """
    try:
        calls = db.query(CallLog).filter(
            (CallLog.caller_id == current_user.id) | (CallLog.receiver_id == current_user.id)
        ).order_by(CallLog.start_time.desc()).all()
    except Exception as e:
        return []

    response_calls = []
    
    profile_ids = set([c.caller_id for c in calls if c.caller_id] + [c.receiver_id for c in calls if c.receiver_id])
    if not profile_ids:
        return []
        
    profiles = db.query(Profile).filter(Profile.id.in_(profile_ids)).all()
    profile_map = {p.id: p.full_name for p in profiles}

    for c in calls:
        caller_name = profile_map.get(c.caller_id, "Unknown")
        receiver_name = profile_map.get(c.receiver_id, "Unknown")
        
        response_calls.append(CallLogResponse(
            id=c.id,
            caller_id=c.caller_id,
            receiver_id=c.receiver_id,
            room_id=c.room_id,
            start_time=c.start_time.isoformat() if c.start_time else "",
            end_time=c.end_time.isoformat() if c.end_time else None,
            duration=c.duration,
            status=c.status,
            call_type=c.call_type,
            caller_name=caller_name,  
            receiver_name=receiver_name
        ))

    return response_calls

@router.delete("/history")
async def clear_call_history(
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Supprime tout l'historique d'appels de l'utilisateur (appels émis et reçus).
    """
    try:
        db.query(CallLog).filter(
            (CallLog.caller_id == current_user.id) | (CallLog.receiver_id == current_user.id)
        ).delete(synchronize_session=False)
        db.commit()
        return {"detail": "Historique d'appels supprimé avec succès"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur lors de la suppression: {str(e)}")
