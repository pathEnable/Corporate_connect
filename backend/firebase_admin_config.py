import firebase_admin
from firebase_admin import credentials, messaging
import os

import json

# Chemin vers le fichier JSON fourni par l'utilisateur
# Note: Le nom du fichier est spécifique à ce que l'utilisateur a déposé.
SERVICE_ACCOUNT_FILE = "labconnect-b02c4-firebase-adminsdk-fbsvc-bb90773577.json"

# Tentative de chargement via variable d'environnement d'abord (pour Render)
service_account_env = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")

if service_account_env:
    try:
        service_account_info = json.loads(service_account_env)
        cred = credentials.Certificate(service_account_info)
        firebase_admin.initialize_app(cred)
        print("Firebase initialized via environment variable.")
    except Exception as e:
        print(f"ERROR: Failed to initialize Firebase via ENV: {e}")
elif os.path.exists(SERVICE_ACCOUNT_FILE):
    cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
    firebase_admin.initialize_app(cred)
    print("Firebase initialized via local file.")
else:
    print(f"CRITICAL: Firebase service account file {SERVICE_ACCOUNT_FILE} not found and FIREBASE_SERVICE_ACCOUNT_JSON env not set!")

def send_push_notification(token: str, title: str, body: str, data: dict = None, is_call: bool = False):
    """Envoie une notification push via FCM.
    
    Pour les appels (is_call=True), envoie avec priorité maximale afin de
    réveiller l'app en arrière-plan et déclencher flutter_callkit_incoming.
    """
    if not token:
        return
    
    # Convertir toutes les valeurs data en string (exigence FCM)
    str_data = {k: str(v) for k, v in (data or {}).items()}

    android_config = messaging.AndroidConfig(
        priority='high',  # Priorité haute pour les appels — réveille l'app
        notification=messaging.AndroidNotification(
            channel_id='call_channel',  # Canal déclaré dans AndroidManifest
            priority=messaging.AndroidNotificationPriority.MAX,
            default_vibrate_timings=True,
        ) if not is_call else None,  # Pour les appels, pas de notif visible (CallKit gère)
    )

    apns_config = messaging.APNSConfig(
        headers={'apns-priority': '10'},  # Priorité max APNS
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                sound='default',
                badge=1,
                content_available=True,  # Réveille l'app en background (iOS)
            )
        ),
    ) if is_call else None

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body) if not is_call else None,
        data=str_data,
        token=token,
        android=android_config,
        apns=apns_config,
    )
    
    try:
        response = messaging.send(message)
        print('Successfully sent message:', response)
        return response
    except Exception as e:
        print('Error sending message:', e)
        return None

