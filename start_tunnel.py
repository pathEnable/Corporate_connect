from pyngrok import ngrok
import sys
import time

# Token fourni par l'utilisateur
token = "3BUVsQMBTqURnYJJaGYA4n8Vbmm_7VfCUqfSHGpGCdwbD5rL9"

try:
    print("Configuration de Ngrok...")
    ngrok.set_auth_token(token)
    
    print("Ouverture du tunnel sur le port 8000...")
    tunnel = ngrok.connect(8000)
    public_url = tunnel.public_url
    
    print(f"NGROK_URL_FOUND: {public_url}")
    print("Le tunnel est ACTIF. Ne fermez pas ce script.")
    
    while True:
        time.sleep(1)
except Exception as e:
    print(f"Erreur Ngrok : {str(e)}")
