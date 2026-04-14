import os
import json
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from database import get_db
from models import Message, Profile, RoomMember
from routes_auth import get_current_user
from security_utils import decrypt_data
from config import MISTRAL_API_KEY
from mistralai.client import Mistral

router = APIRouter(tags=["AI Assistant"])

# Configuration Mistral
if MISTRAL_API_KEY:
    ai_client = Mistral(api_key=MISTRAL_API_KEY)
else:
    ai_client = None

@router.post("/rooms/{room_id}/summarize")
def summarize_discussion(
    room_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user)
):
    """Générer un résumé intelligent des 50 derniers messages avec Mistral AI."""
    
    # Vérifier l'accès
    membership = db.query(RoomMember).filter_by(room_id=room_id, profile_id=current_user.id).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Accès refusé.")

    # Récupérer les 50 derniers messages texte
    messages = db.query(Message).filter(
        Message.room_id == room_id,
        Message.message_type == "text"
    ).order_by(desc(Message.created_at)).limit(50).all()

    if not messages:
        return {"summary": "Pas assez de messages pour générer un résumé.", "is_mock": False}

    # Préparer le texte (déchiffrement nécessaire)
    chat_history = []
    for msg in reversed(messages):
        try:
            content = decrypt_data(msg.content)
            chat_history.append(f"{msg.sender.full_name}: {content}")
        except Exception:
            continue
    
    context = "\n".join(chat_history)

    if not ai_client:
        # Mode Simulation si pas de clé API
        return {
            "summary": "[MODE SIMULATION - MISTRAL] La discussion porte sur la migration vers un LLM souverain. L'équipe apprécie la rapidité de Mistral AI.",
            "is_mock": True
        }

    try:
        prompt = (
            "Tu es un assistant de productivité d'entreprise. Voici une discussion d'équipe. "
            "Fais un résumé très concis (3-4 phrases max) des points clés. "
            "Réponds uniquement avec le texte du résumé.\n\n"
            f"Discussion:\n{context}"
        )
        
        response = ai_client.chat.complete(
            model="mistral-small-latest",
            messages=[{"role": "user", "content": prompt}]
        )
        
        summary = response.choices[0].message.content
        return {"summary": summary, "is_mock": False}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur Mistral AI: {str(e)}")

@router.post("/rooms/{room_id}/extract-tasks")
def extract_action_items(
    room_id: str,
    db: Session = Depends(get_db),
    current_user: Profile = Depends(get_current_user)
):
    """Détecter les tâches potentielles dans la discussion via Mistral AI."""
    
    membership = db.query(RoomMember).filter_by(room_id=room_id, profile_id=current_user.id).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Accès refusé.")

    messages = db.query(Message).filter(
        Message.room_id == room_id,
        Message.message_type == "text"
    ).order_by(desc(Message.created_at)).limit(30).all()

    if not messages:
        return {"tasks": [], "is_mock": False}

    chat_history = []
    for m in reversed(messages):
        try:
            chat_history.append(f"{m.sender.full_name}: {decrypt_data(m.content)}")
        except Exception:
            continue
            
    context = "\n".join(chat_history)

    if not ai_client:
        return {
            "tasks": [
                {"title": "Migration vers Mistral AI", "suggested_assignee": "Patrice"},
                {"title": "Test de la confidentialité", "suggested_assignee": current_user.full_name}
            ],
            "is_mock": True
        }

    try:
        prompt = (
            "Analyse cette discussion et sors une liste de tâches concrètes. "
            "Tu dois répondre avec un objet JSON contenant une clé 'tasks' qui est une liste d'objets. "
            "Chaque objet doit avoir 'title' et 'suggested_assignee'. "
            "Si aucun assigné n'est clair, mets 'Tout le monde'.\n\n"
            f"Discussion:\n{context}"
        )
        
        response = ai_client.chat.complete(
            model="mistral-small-latest",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )
        
        raw_json = response.choices[0].message.content
        data = json.loads(raw_json)
        
        # S'assurer que le format est correct
        tasks = data.get("tasks", []) if isinstance(data, dict) else []
        
        return {"tasks": tasks, "is_mock": False}
    except Exception:
        return {"tasks": [], "error": "Impossible d'extraire les tâches avec Mistral pour le moment."}
