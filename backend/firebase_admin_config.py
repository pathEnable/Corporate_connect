import firebase_admin
from firebase_admin import credentials, messaging
import os

# Chemin vers le fichier JSON fourni par l'utilisateur
# Note: Le nom du fichier est spécifique à ce que l'utilisateur a déposé.
# Je vais chercher le fichier .json dans le dossier backend.
SERVICE_ACCOUNT_FILE = "labconnect-b02c4-firebase-adminsdk-fbsvc-bb90773577.json"

if os.path.exists(SERVICE_ACCOUNT_FILE):
    cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
    firebase_admin.initialize_app(cred)
else:
    print(f"CRITICAL: Firebase service account file {SERVICE_ACCOUNT_FILE} not found!")

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
