"""
scheduler.py — Envoi automatique des messages programmés.
Lancé en tâche asyncio d'arrière-plan au démarrage de l'application FastAPI.
"""

import json
import asyncio
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Message, RoomMember, Profile, Room
from firebase_admin_config import send_push_notification


async def scheduled_message_worker(manager):
    """
    Vérifie toutes les 60s s'il existe des messages programmés à envoyer.
    Un message est dû quand :  scheduled_for <= now()  ET  is_sent == False
    """
    print("[Scheduler] Scheduler de messages programmes demarre.")
    while True:
        try:
            await _flush_pending_messages(manager)
        except Exception as e:
            print(f"[Scheduler] Erreur inattendue : {e}")
        await asyncio.sleep(60)  # cadence : 1 minute


async def _flush_pending_messages(manager):
    """Vérifie et envoie les messages programmés."""
    db: Session = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        pending = (
            db.query(Message)
            .filter(
                Message.is_sent == False,
                Message.scheduled_for != None,
                Message.scheduled_for <= now,
            )
            .all()
        )

        if not pending:
            return

        print(f"[Scheduler] {len(pending)} message(s) programmé(s) à envoyer.")

        from database import redis_client

        for msg in pending:
            msg.is_sent = True
            db.commit()

            room_id = str(msg.room_id)
            sender_id = str(msg.sender_id)

            # Prépare le payload WebSocket identique à un message ordinaire
            broadcast_payload = {
                "type": "new_message",
                "message_id": str(msg.id),
                "room_id": room_id,
                "sender_id": sender_id,
                "content": msg.content,
                "message_type": msg.message_type,
                "metadata_": msg.metadata_,
                "reply_to_id": str(msg.reply_to_id) if msg.reply_to_id else None,
                "timestamp": msg.scheduled_for.isoformat(),
            }

            # Publier via Redis (le listener distribue aux WebSockets actifs)
            try:
                data = {"room_id": room_id, "payload": broadcast_payload}
                await redis_client.publish("chat_broadcast", json.dumps(data))
            except Exception as e:
                print(f"[Scheduler] Erreur Redis publish: {e}")

            # Envoyer les notifications push aux membres hors-ligne
            members = db.query(RoomMember).filter(RoomMember.room_id == msg.room_id).all()
            online_users = manager.get_online_users(room_id)
            sender = db.query(Profile).filter(Profile.id == msg.sender_id).first()
            sender_name = sender.full_name if sender else "Un collègue"
            room = db.query(Room).filter(Room.id == msg.room_id).first()

            for member in members:
                uid = str(member.profile_id)
                if uid != sender_id and uid not in online_users:
                    p = db.query(Profile).filter(Profile.id == member.profile_id).first()
                    if p and p.fcm_token:
                        notif_body = msg.content or "📅 Message programmé reçu"
                        if msg.message_type == "image":
                            notif_body = "📸 Image reçue"
                        elif msg.message_type == "poll":
                            notif_body = "📊 Nouveau sondage"
                        elif msg.message_type == "task":
                            notif_body = "✅ Nouvelle tâche assignée"
                        elif msg.message_type == "meeting":
                            notif_body = "📅 Nouvelle réunion planifiée"
                        
                        send_push_notification(
                            token=p.fcm_token,
                            title=sender_name if not room or not room.is_group else f"{sender_name} ({room.name})",
                            body=notif_body,
                            data={
                                "type": "new_message",
                                "room_id": room_id,
                                "room_name": room.name if room else sender_name,
                                "is_group": str(room.is_group).lower() if room else "false",
                            },
                        )
    finally:
        db.close()
