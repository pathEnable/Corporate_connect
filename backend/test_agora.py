import requests
import time
import random
import string

def get_random_string(length):
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

def test_agora_token():
    auth_url = "http://127.0.0.1:8000/auth"
    agora_url = "http://127.0.0.1:8000/agora"
    
    unique_suffix = get_random_string(6)
    reg_data = {
        "full_name": "Test Agora User",
        "username": f"agora_user_{unique_suffix}",
        "email": f"agora_{unique_suffix}@example.com",
        "password": "Password123!",
        "phone_number": f"+336{random.randint(10000000, 99999999)}"
    }

    print(f"🚀 Inscription d'un utilisateur de test ({reg_data['email']})...")
    
    try:
        # 1. Register
        reg_res = requests.post(f"{auth_url}/register", json=reg_data)
        if reg_res.status_code not in [200, 201]:
            print(f"❌ Échec inscription: {reg_res.text}")
            return False
            
        token_jwt = reg_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token_jwt}"}

        # 2. Fetch Agora Token
        print(f"📡 Requête token Agora...")
        start_time = time.time()
        response = requests.get(
            f"{agora_url}/token?channel_name=test_channel&uid=0",
            headers=headers
        )
        duration = time.time() - start_time

        print(f"📡 Status Code: {response.status_code} ({duration:.2f}s)")
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Token Agora généré avec succès !")
            print(f"🔑 Token (tronqué): {data.get('token')[:20]}...")
            print(f"🆔 App ID: {data.get('app_id')}")
            return True
        else:
            print(f"❌ Échec de la génération : {response.text}")
            return False

    except Exception as e:
        print(f"💥 Erreur lors du test : {e}")
        return False

if __name__ == "__main__":
    test_agora_token()
