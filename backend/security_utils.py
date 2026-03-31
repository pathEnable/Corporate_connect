from cryptography.fernet import Fernet
import os
from config import SECRET_KEY

# Pour une version réelle, on utiliserait une clé distincte stockée de façon sécurisée (ex: AWS KMS, HashiCorp Vault)
# Ici on dérive une clé de SECRET_KEY pour la démonstration
import base64
import hashlib

key = base64.urlsafe_b64encode(hashlib.sha256(SECRET_KEY.encode()).digest())
cipher_suite = Fernet(key)

def encrypt_data(data: str) -> str:
    if not data: return data
    return cipher_suite.encrypt(data.encode()).decode()

def decrypt_data(encrypted_data: str) -> str:
    if not encrypted_data: return encrypted_data
    try:
        return cipher_suite.decrypt(encrypted_data.encode()).decode()
    except Exception:
        return encrypted_data # Retourner tel quel si non crypté (compatibilité)
