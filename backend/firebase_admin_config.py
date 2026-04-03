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

def send_push_notification(token: str, title: str, body: str, data: dict = None):
    """Envoie une notification push via FCM."""
    if not token:
        return
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data or {},
        token=token,
    )
    
    try:
        response = messaging.send(message)
        print('Successfully sent message:', response)
        return response
    except Exception as e:
        print('Error sending message:', e)
        return None
