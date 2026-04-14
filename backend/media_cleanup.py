"""
media_cleanup.py — Worker asynchrone de nettoyage des fichiers médias.
Lancé en tâche asyncio d'arrière-plan au démarrage de l'application FastAPI.

Deux stratégies complémentaires :
  1. Fichiers orphelins : fichiers uploadés mais jamais référencés dans un message.
  2. Fichiers périmés : fichiers au-delà du seuil de rétention (ex. 90 jours).

Cadence : exécution toutes les 6 heures.
"""

import os
import asyncio
from datetime import datetime, timezone, timedelta
from sqlalchemy import text
from database import SessionLocal

# ── Configuration ─────────────────────────────────────────────
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
IMAGES_DIR = os.path.join(UPLOAD_DIR, "images")
DOCS_DIR = os.path.join(UPLOAD_DIR, "docs")

# Seuil de rétention par défaut (en jours)
RETENTION_DAYS = int(os.getenv("MEDIA_RETENTION_DAYS", "90"))

# Grâce période : ne pas supprimer les fichiers uploadés il y a moins de X heures
# (protège les fichiers fraîchement uploadés mais pas encore envoyés dans un message)
GRACE_PERIOD_HOURS = 24

# Cadence du worker (en secondes)
CLEANUP_INTERVAL = 6 * 60 * 60  # 6 heures


async def media_cleanup_worker():
    """
    Worker d'arrière-plan pour le nettoyage des médias.
    S'exécute toutes les 6 heures.
    """
    print("🧹 Worker de nettoyage des médias démarré.")
    
    # Attendre un peu au démarrage pour ne pas surcharger l'init
    await asyncio.sleep(60)
    
    while True:
        try:
            stats = await asyncio.to_thread(_run_cleanup)
            print(
                f"[MediaCleanup] Terminé — "
                f"Orphelins supprimés: {stats['orphans_deleted']}, "
                f"Périmés supprimés: {stats['expired_deleted']}, "
                f"Espace libéré: {_format_bytes(stats['bytes_freed'])}"
            )
        except Exception as e:
            print(f"[MediaCleanup] Erreur inattendue : {e}")
        
        await asyncio.sleep(CLEANUP_INTERVAL)


def _run_cleanup() -> dict:
    """
    Logique synchrone de nettoyage, exécutée dans un thread séparé.
    Retourne un dict de statistiques.
    """
    stats = {
        "orphans_deleted": 0,
        "expired_deleted": 0,
        "bytes_freed": 0,
    }
    
    db = SessionLocal()
    try:
        # ═══ Phase 1 : Récupérer tous les noms de fichiers référencés en DB ═══
        # Les contenus médias dans la table messages contiennent des URLs comme :
        #   /media/download/<filename>
        # On extrait les noms de fichiers uniques référencés.
        
        result = db.execute(text(
            "SELECT content FROM messages "
            "WHERE message_type IN ('image', 'file', 'audio') "
            "AND content LIKE '/media/download/%'"
        ))
        
        referenced_filenames = set()
        for row in result:
            content = row[0]
            if content and "/media/download/" in content:
                filename = content.split("/media/download/")[-1]
                referenced_filenames.add(filename)
        
        # Récupérer aussi les avatars référencés dans les profils
        result_avatars = db.execute(text(
            "SELECT avatar_url FROM profiles WHERE avatar_url IS NOT NULL"
        ))
        for row in result_avatars:
            avatar = row[0]
            if avatar and "/media/download/" in avatar:
                filename = avatar.split("/media/download/")[-1]
                referenced_filenames.add(filename)
        
        now = datetime.now(timezone.utc)
        grace_cutoff = now - timedelta(hours=GRACE_PERIOD_HOURS)
        expiry_cutoff = now - timedelta(days=RETENTION_DAYS)
        
        # ═══ Phase 2 : Scanner les répertoires de fichiers ═══
        for directory in [IMAGES_DIR, DOCS_DIR]:
            if not os.path.exists(directory):
                continue
                
            for filename in os.listdir(directory):
                filepath = os.path.join(directory, filename)
                
                # Ignorer les sous-dossiers
                if not os.path.isfile(filepath):
                    continue
                
                try:
                    file_mtime = datetime.fromtimestamp(
                        os.path.getmtime(filepath), tz=timezone.utc
                    )
                except OSError:
                    continue
                
                # Protection : ne jamais toucher aux fichiers dans la grâce période
                if file_mtime > grace_cutoff:
                    continue
                
                file_size = os.path.getsize(filepath)
                
                # Stratégie 1 : Fichier orphelin (pas référencé en DB)
                if filename not in referenced_filenames:
                    try:
                        os.remove(filepath)
                        stats["orphans_deleted"] += 1
                        stats["bytes_freed"] += file_size
                        continue
                    except OSError:
                        continue
                
                # Stratégie 2 : Fichier périmé (au-delà du seuil de rétention)
                if file_mtime < expiry_cutoff:
                    try:
                        os.remove(filepath)
                        stats["expired_deleted"] += 1
                        stats["bytes_freed"] += file_size
                    except OSError:
                        continue
    
    finally:
        db.close()
    
    return stats


def _format_bytes(num_bytes: int) -> str:
    """Formate un nombre d'octets en unité lisible."""
    for unit in ["B", "KB", "MB", "GB"]:
        if num_bytes < 1024:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} TB"
