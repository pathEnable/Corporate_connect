import json
import uuid
import asyncio
from datetime import datetime, timezone
from typing import Dict, Set, Optional, List, Any
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query, status, HTTPException, Body
from pydantic import BaseModel
from sqlalchemy.orm import Session
from database import get_db
from models import Message, Room, RoomMember, Profile
from security_utils import encrypt_data, decrypt_data
from starlette.concurrency import run_in_threadpool
from firebase_admin_config import send_push_notification
from database import redis_client
from routes_auth import get_current_user

router = APIRouter(tags=["Chat"])

# ── Schemas pour les nouvelles routes ─────────────────────────────────────────

class VoteRequest(BaseModel):
    option_index: int

class TaskStatusRequest(BaseModel):
    is_done: bool

class ScheduleMessageRequest(BaseModel):
    room_id: str
    content: str
    message_type: str = "text"
    scheduled_for: str           # ISO 8601 : "2026-04-14T08:00:00Z"
    metadata_: Optional[dict] = None

# ── Route : Voter à un sondage ─────────────────────────────────────────────────

@router.post("/rooms/{room_id}/messages/{message_id}/vote")
def vote_poll(
    room_id: str,
    message_id: str,
    body: VoteRequest,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Voter pour une option d'un sondage. Chaque utilisateur ne peut voter qu'une fois."""
    msg = db.query(Message).filter(
        Message.id == message_id,
        Message.room_id == room_id,
        Message.message_type == "poll",
    ).first()
    if not msg:
        raise HTTPException(status_code=404, detail="Sondage introuvable.")

    meta = msg.metadata_ or {}
    votes: dict = meta.get("votes", {})
    user_key = str(current_user.id)

    if user_key in votes:
        raise HTTPException(status_code=409, detail="Vous avez déjà voté.")

    votes[user_key] = body.option_index
    meta["votes"] = votes
    msg.metadata_ = meta
    db.commit()
    db.refresh(msg)
    return {"detail": "Vote enregistré.", "votes": votes}


# ── Route : Mettre à jour le statut d'une tâche ────────────────────────────────

@router.patch("/rooms/{room_id}/messages/{message_id}/task")
def update_task(
    room_id: str,
    message_id: str,
    body: TaskStatusRequest,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Marquer une tâche comme faite ou non faite."""
    msg = db.query(Message).filter(
        Message.id == message_id,
        Message.room_id == room_id,
        Message.message_type == "task",
    ).first()
    if not msg:
        raise HTTPException(status_code=404, detail="Tâche introuvable.")

    meta = msg.metadata_ or {}
    meta["is_done"] = body.is_done
    if body.is_done:
        meta["completed_by"] = str(current_user.id)
        meta["completed_at"] = datetime.now(timezone.utc).isoformat()
    msg.metadata_ = meta
    db.commit()
    db.refresh(msg)
    return {"detail": "Tâche mise à jour.", "metadata_": meta}


# ── Route : Programmer un message ──────────────────────────────────────────────

@router.post("/rooms/{room_id}/messages/schedule")
def schedule_message(
    room_id: str,
    body: ScheduleMessageRequest,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user),
):
    """Enregistre un message programmé. Il sera envoyé par le scheduler automatiquement."""
    # Vérifier l'appartenance
    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.profile_id == current_user.id,
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce salon.")

    scheduled_dt = datetime.fromisoformat(body.scheduled_for.replace("Z", "+00:00"))
    if scheduled_dt <= datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="La date d'envoi doit être dans le futur.")

    new_msg = Message(
        id=uuid.uuid4(),
        room_id=room_id,
        sender_id=current_user.id,
        content=body.content,
        message_type=body.message_type,
        metadata_=body.metadata_,
        scheduled_for=scheduled_dt,
        is_sent=False,
    )
    db.add(new_msg)
    db.commit()
    return {"detail": "Message programmé avec succès.", "message_id": str(new_msg.id), "scheduled_for": scheduled_dt.isoformat()}




class ConnectionManager:
    """Gestionnaire centralisé des connexions WebSocket."""

    def __init__(self):
        # {room_id: {user_id: WebSocket}}
        self.active_connections: Dict[str, Dict[str, WebSocket]] = {}
        # {user_id: WebSocket}
        self.global_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, room_id: str, user_id: str):
        await websocket.accept()
        if room_id not in self.active_connections:
            self.active_connections[room_id] = {}
        self.active_connections[room_id][user_id] = websocket

    def disconnect(self, room_id: str, user_id: str):
        if room_id in self.active_connections:
            self.active_connections[room_id].pop(user_id, None)
            if not self.active_connections[room_id]:
                del self.active_connections[room_id]

    async def connect_global(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        self.global_connections[user_id] = websocket

    def disconnect_global(self, user_id: str):
        self.global_connections.pop(user_id, None)

    async def broadcast_to_room(self, room_id: str, message: dict, exclude_user: str = None):
        """Publier un message sur Redis pour tous les membres connectés d'un salon."""
        data = {
            "room_id": room_id,
            "exclude_user": exclude_user,
            "payload": message
        }
        try:
            await redis_client.publish("chat_broadcast", json.dumps(data))
        except Exception as e:
            print(f"Erreur pubsub room: {e}")

    def get_online_users(self, room_id: str) -> Set[str]:
        """Retourner la liste des utilisateurs connectés dans un salon."""
        if room_id in self.active_connections:
            return set(self.active_connections[room_id].keys())
        return set()

manager = ConnectionManager()

# --- Fonctions utilitaires pour les broadcasts cross-module ---
async def broadcast_to_all_globals(message: dict, exclude_user: str = None):
    """Diffuser un événement à TOUS les utilisateurs via Redis Pub/Sub."""
    data = {
        "global_action": True,
        "exclude_user": exclude_user,
        "payload": message
    }
    try:
        await redis_client.publish("chat_broadcast", json.dumps(data))
    except Exception:
        pass


async def broadcast_to_users(user_ids: list, message: dict):
    """Diffuser un événement à une liste d'utilisateurs via Redis Pub/Sub."""
    data = {
        "target_users": [str(uid) for uid in user_ids],
        "payload": message
    }
    try:
        await redis_client.publish("chat_broadcast", json.dumps(data))
    except Exception:
        pass


# --- Listener Pub/Sub Redis ---
async def start_redis_listener():
    """Tâche en arrière-plan écoutant les messages Redis et les distribuant localement."""
    pubsub = redis_client.pubsub()
    await pubsub.subscribe("chat_broadcast")
    print("🚀 Redis PubSub listener started")
    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                data = json.loads(message["data"])
                room_id = data.get("room_id")
                exclude_user = data.get("exclude_user")
                payload = data.get("payload")
                
                if room_id:
                    if room_id in manager.active_connections:
                        for user_id, ws in manager.active_connections[room_id].items():
                            if user_id != exclude_user:
                                try:
                                    await ws.send_json(payload)
                                except Exception:
                                    pass
                elif data.get("global_action"):
                    for user_id, ws in manager.global_connections.items():
                        if user_id != exclude_user:
                            try:
                                await ws.send_json(payload)
                            except Exception:
                                pass
                elif data.get("target_users"):
                    for uid in data.get("target_users"):
                        uid_str = str(uid)
                        if uid_str in manager.global_connections:
                            try:
                                await manager.global_connections[uid_str].send_json(payload)
                            except Exception:
                                pass
    except Exception as e:
        print(f"Erreur fatale Redis listener: {e}")


from auth import create_access_token, ALGORITHM, SECRET_KEY
from jose import jwt, JWTError

@router.websocket("/ws/global/{user_id}")
async def websocket_global(
    websocket: WebSocket,
    user_id: str,
    token: str = Query(None)
):
    """
    Point d'entrée global pour la présence.
    Supporte l'authentification par `?token=` (Legacy) ou via Header `Sec-WebSocket-Protocol`.
    """
    # 1. Extraction du token depuis le protocole (Recommandé) ou Query (Legacy)
    if not token:
        # Le client Flutter passe le token dans 'protocols'
        token = websocket.headers.get("sec-websocket-protocol")
    
    # Accepter d'abord pour pouvoir fermer proprement
    # Si on utilise le protocole pour le token, on doit le renvoyer dans l'acceptation
    await websocket.accept(subprotocol=token if token else None)
    
    if not token:
        print(f"❌ WS Global refusé: Token manquant pour {user_id}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_sub = payload.get("sub")
        if token_sub != user_id:
            print(f"❌ WS Global refusé: Discordance ID ({token_sub} != {user_id})")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    except Exception as e:
        print(f"❌ WS Global refusé: Erreur décodage JWT ({e})")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    print(f"✅ WS Global connecté pour {user_id}")
    # La connexion est déjà acceptée, on l'ajoute au manager directement
    manager.global_connections[user_id] = websocket

    def set_online_status(u_id: str, is_online: bool):
        db_session = next(get_db())
        try:
            user = db_session.query(Profile).filter(Profile.id == u_id).first()
            if user:
                user.is_online = is_online
                db_session.commit()
        finally:
            db_session.close()

    await run_in_threadpool(set_online_status, user_id, True)

    try:
        while True:
            data = await websocket.receive_text()
            # On écoute juste le ping, pas de traitement spécifique
            # Le heartbeat garde la connexion en vie
            pass
    except WebSocketDisconnect:
        manager.disconnect_global(user_id)
        await run_in_threadpool(set_online_status, user_id, False)

@router.websocket("/ws/chat/{room_id}/{user_id}")
async def websocket_chat(
    websocket: WebSocket,
    room_id: str,
    user_id: str,
    token: str = Query(None)
):
    """
    Point d'entrée WebSocket pour le chat temps réel sécurisé.
    Supporte Header `Sec-WebSocket-Protocol` (Recommandé) ou `?token=` (Legacy).
    """
    if not token:
        token = websocket.headers.get("sec-websocket-protocol")
        
    # Accepter d'abord pour pouvoir fermer proprement
    await websocket.accept(subprotocol=token if token else None)
    
    # Validation du token
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_user_id = payload.get("sub")
        if token_user_id != user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    except Exception as e:
        print(f"❌ WS Chat refusé: Erreur décodage JWT ({e})")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # --- Vérification de l'appartenance au salon (IDOR Fix) ---
    def check_membership(r_id, u_id):
        db_session = next(get_db())
        try:
            return db_session.query(RoomMember).filter(
                RoomMember.room_id == r_id,
                RoomMember.profile_id == u_id
            ).first() is not None
        finally:
            db_session.close()

    is_member = await run_in_threadpool(check_membership, room_id, user_id)
    if not is_member:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    # -------------------------------------------------------------------

    # Connexion déjà acceptée, enregistrer directement dans le manager
    if room_id not in manager.active_connections:
        manager.active_connections[room_id] = {}
    manager.active_connections[room_id][user_id] = websocket

    # Fonction pour mettre à jour le statut en ligne localement n'est plus utile ici
    # Elle est gérée par le WS /ws/global
    # Notifier les autres que l'utilisateur a rejoint la salle active
    await manager.broadcast_to_room(
        room_id,
        {"type": "user_joined", "user_id": user_id, "timestamp": datetime.utcnow().isoformat()},
        exclude_user=user_id,
    )

    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            msg_type = message_data.get("type", "text")

            # Signalisation WebRTC : On transfère sans sauvegarder
            if msg_type in ["call_offer", "call_answer", "call_rejected", "ice_candidate"]:
                # On envoie à tous les autres membres (le destinataire filtrera ou on pourrait utiliser un target_id)
                # Pour faire simple/robuste : broadcast entier pour le signalement WebRTC dans cette Room
                await manager.broadcast_to_room(
                    room_id, 
                    {
                        "type": msg_type,
                        "sender_id": user_id,
                        "data": message_data.get("data")
                    },
                    exclude_user=user_id
                )
                continue

            # Gestion de l'accusé de lecture
            if msg_type == "message_read":
                def mark_read_in_db(r_id, u_id):
                    db_session = next(get_db())
                    try:
                        db_session.query(Message).filter(
                            Message.room_id == r_id,
                            Message.sender_id != u_id,
                            Message.is_read == False
                        ).update({"is_read": True, "read_at": datetime.utcnow()})
                        db_session.commit()
                    finally:
                        db_session.close()
                
                await run_in_threadpool(mark_read_in_db, room_id, user_id)
                
                await manager.broadcast_to_room(
                    room_id,
                    {
                        "type": "message_read",
                        "reader_id": user_id,
                        "room_id": room_id,
                        "timestamp": datetime.utcnow().isoformat()
                    },
                    exclude_user=user_id
                )
                continue

            # Gestion du "typing indicator"
            if msg_type == "typing":
                await manager.broadcast_to_room(
                    room_id,
                    {
                        "type": "typing",
                        "user_id": user_id,
                        "is_typing": message_data.get("is_typing", True),
                        "timestamp": datetime.utcnow().isoformat()
                    },
                    exclude_user=user_id
                )
                continue

            # Le serveur ne fait plus aucun déchiffrement/chiffrement (E2EE pur). 
            # Le contenu reçu est déjà chiffré par l'expéditeur (ou est une URL média).
            stored_content = message_data.get("content", "")

            # Fonction synchrone isolée pour ne pas bloquer l'Event Loop
            def save_to_db(r_id, s_id, text_content, m_type, reply_id=None, meta=None):
                db_session = next(get_db())
                try:
                    new_msg = Message(
                        id=uuid.uuid4(),
                        room_id=r_id,
                        sender_id=s_id,
                        content=text_content,
                        message_type=m_type,
                        reply_to_id=reply_id,
                        metadata_=meta,
                    )
                    db_session.add(new_msg)
                    db_session.commit()
                    return new_msg.id, new_msg.message_type, meta
                except Exception as e:
                    db_session.rollback()
                    raise e
                finally:
                    db_session.close()

            try:
                # Exécution dans un thread séparé ! (OPTIMISATION MAJEURE)
                msg_reply_id = message_data.get("reply_to_id")
                extra_data = message_data.get("data")
                metadata_to_save = extra_data.get("metadata_") if extra_data and isinstance(extra_data, dict) else None
                
                msg_id, final_m_type, saved_meta = await run_in_threadpool(
                    save_to_db, room_id, user_id, stored_content, msg_type, msg_reply_id, metadata_to_save
                )

                # Préparer le message de diffusion
                broadcast_msg = {
                    "type": "new_message",
                    "message_id": str(msg_id),
                    "room_id": room_id,
                    "metadata_": saved_meta,
                    "sender_id": user_id,
                    "content": stored_content, # Transmis tel quel (chiffré E2EE)
                    "message_type": final_m_type,
                    "reply_to_id": msg_reply_id,
                    "timestamp": datetime.utcnow().isoformat(),
                }

                # Diffuser à tous les membres du salon
                await manager.broadcast_to_room(room_id, broadcast_msg)

                # --- NOUVEAU : Notifications Push pour les membres hors-ligne ---
                def notify_offline_members(r_id, s_id, raw_content, m_type):
                    db_session = next(get_db())
                    try:
                        members = db_session.query(RoomMember).filter(RoomMember.room_id == r_id).all()
                        online_user_ids = manager.get_online_users(str(r_id))
                        sender = db_session.query(Profile).filter(Profile.id == s_id).first()
                        sender_name = sender.full_name if sender else "Un collègue"

                        room = db_session.query(Room).filter(Room.id == r_id).first()
                        is_group = str(room.is_group).lower() if room else "false"
                        room_name = room.name if room and room.name else sender_name

                        notification_body = raw_content
                        if m_type == "image": notification_body = "📸 Image reçue"
                        elif m_type == "file": notification_body = "📄 Fichier reçu"
                        elif m_type == "audio": notification_body = "🎤 Message vocal"

                        for member in members:
                            m_u_id = str(member.profile_id)
                            if m_u_id != str(s_id) and m_u_id not in online_user_ids:
                                p = db_session.query(Profile).filter(Profile.id == member.profile_id).first()
                                if p and p.fcm_token:
                                    send_push_notification(
                                        token=p.fcm_token,
                                        title=sender_name if is_group == "false" else f"{sender_name} ({room.name})",
                                        body=notification_body,
                                        data={
                                            "type": "new_message",
                                            "room_id": str(r_id),
                                            "room_name": room_name,
                                            "is_group": is_group
                                        }
                                    )
                    finally:
                        db_session.close()

                await run_in_threadpool(notify_offline_members, room_id, user_id, message_data.get("content", ""), final_m_type)
                
                # --- NOUVEAU : Diffuser le message aux WS globaux correspondants ---
                def get_members_for_broadcast(r_id):
                    db_session = next(get_db())
                    try:
                        return [str(m.profile_id) for m in db_session.query(RoomMember).filter(RoomMember.room_id == r_id).all()]
                    finally:
                        db_session.close()
                member_ids = await run_in_threadpool(get_members_for_broadcast, room_id)
                global_msg = broadcast_msg.copy()
                global_msg["type"] = "global_new_message" # Marqueur spécial pour distinguer
                for m_id in member_ids:
                    # Ne pas envoyer au sender, ni à l'utilisateur déjà actif dans le WS local
                    active_users_in_room = manager.get_online_users(str(room_id))
                    if m_id != user_id and m_id not in active_users_in_room:
                        if m_id in manager.global_connections:
                            try:
                                await manager.global_connections[m_id].send_json(global_msg)
                            except:
                                pass
                # -----------------------------------------------------------------

            except Exception as e:
                print(f"Error saving message: {e}")

    except WebSocketDisconnect:
        manager.disconnect(room_id, user_id)
        
        await manager.broadcast_to_room(
            room_id,
            {"type": "user_left", "user_id": user_id, "timestamp": datetime.utcnow().isoformat()},
        )
