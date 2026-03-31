import json
import uuid
import asyncio
from datetime import datetime
from typing import Dict, Set
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import Message, Room, RoomMember, Profile
from security_utils import encrypt_data, decrypt_data
from starlette.concurrency import run_in_threadpool
from firebase_admin_config import send_push_notification

router = APIRouter(tags=["Chat"])


class ConnectionManager:
    """Gestionnaire centralisé des connexions WebSocket."""

    def __init__(self):
        # {room_id: {user_id: WebSocket}}
        self.active_connections: Dict[str, Dict[str, WebSocket]] = {}

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

    async def broadcast_to_room(self, room_id: str, message: dict, exclude_user: str = None):
        """Envoyer un message à tous les membres connectés d'un salon."""
        if room_id in self.active_connections:
            for user_id, ws in self.active_connections[room_id].items():
                if user_id != exclude_user:
                    try:
                        await ws.send_json(message)
                    except Exception:
                        pass

    def get_online_users(self, room_id: str) -> Set[str]:
        """Retourner la liste des utilisateurs connectés dans un salon."""
        if room_id in self.active_connections:
            return set(self.active_connections[room_id].keys())
        return set()


manager = ConnectionManager()


from auth import create_access_token, ALGORITHM, SECRET_KEY
from jose import jwt, JWTError

@router.websocket("/ws/chat/{room_id}/{user_id}")
async def websocket_chat(
    websocket: WebSocket,
    room_id: str,
    user_id: str,
    token: str = None
):
    """Point d'entrée WebSocket pour le chat temps réel sécurisé."""
    # Validation du token (passé en query param car les WS supportent mal les headers)
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_user_id = payload.get("sub")
        if token_user_id != user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    except JWTError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # --- NOUVEAU : Vérification de l'appartenance au salon (IDOR Fix) ---
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

    await manager.connect(websocket, room_id, user_id)

    # Fonction pour mettre à jour le statut en ligne
    def set_online_status(u_id: str, status: bool):
        db_session = next(get_db())
        try:
            user = db_session.query(Profile).filter(Profile.id == u_id).first()
            if user:
                user.is_online = status
                db_session.commit()
        except Exception as e:
            db_session.rollback()
        finally:
            db_session.close()

    # Mettre à jour is_online = True
    await run_in_threadpool(set_online_status, user_id, True)

    # Notifier les autres que l'utilisateur est en ligne
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
            def save_to_db(r_id, s_id, text_content, m_type, reply_id=None):
                db_session = next(get_db())
                try:
                    new_msg = Message(
                        id=uuid.uuid4(),
                        room_id=r_id,
                        sender_id=s_id,
                        content=text_content,
                        message_type=m_type,
                        reply_to_id=reply_id,
                    )
                    db_session.add(new_msg)
                    db_session.commit()
                    return new_msg.id, new_msg.message_type
                except Exception as e:
                    db_session.rollback()
                    raise e
                finally:
                    db_session.close()

            try:
                # Exécution dans un thread séparé ! (OPTIMISATION MAJEURE)
                msg_reply_id = message_data.get("reply_to_id")
                msg_id, final_m_type = await run_in_threadpool(
                    save_to_db, room_id, user_id, stored_content, msg_type, msg_reply_id
                )

                # Préparer le message de diffusion
                broadcast_msg = {
                    "type": "new_message",
                    "message_id": str(msg_id),
                    "room_id": room_id,
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
                # -----------------------------------------------------------------

            except Exception as e:
                print(f"Error saving message: {e}")

    except WebSocketDisconnect:
        manager.disconnect(room_id, user_id)
        # Mettre à jour is_online = False
        await run_in_threadpool(set_online_status, user_id, False)
        
        await manager.broadcast_to_room(
            room_id,
            {"type": "user_left", "user_id": user_id, "timestamp": datetime.utcnow().isoformat()},
        )
