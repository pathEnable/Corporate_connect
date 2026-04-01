import httpx
import uuid
import time

BASE_URL = "http://127.0.0.1:8000"

def test_full_journey():
    unique_id = str(uuid.uuid4())[:8]
    email = f"test_{unique_id}@example.com"
    password = "password123"
    full_name = f"User {unique_id}"
    username = f"user_{unique_id}"

    print(f"🚀 Démarrage du test d'intégration API pour {email}...")

    with httpx.Client(base_url=BASE_URL, timeout=10.0) as client:
        # 1. Inscription
        print("📝 Phase 1 : Inscription...")
        reg_resp = client.post("/auth/register", json={
            "email": email,
            "password": password,
            "full_name": full_name,
            "username": username,
            "phone_number": f"+336{unique_id}"
        })
        if reg_resp.status_code != 200:
            print(f"❌ Erreur Inscription: {reg_resp.text}")
            return
        print("✅ Inscription réussie.")

        # 2. Connexion
        print("🔑 Phase 2 : Connexion...")
        login_resp = client.post("/auth/login", json={
            "email": email,
            "password": password
        })
        if login_resp.status_code != 200:
            print(f"❌ Erreur Connexion: {login_resp.text}")
            return
        
        token = login_resp.json()["access_token"]
        print("✅ Connexion réussie. Token récupéré.")

        # 3. Récupération Profil (/auth/me)
        print("👤 Phase 3 : Vérification du profil (/auth/me)...")
        me_resp = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        if me_resp.status_code != 200:
            print(f"❌ Erreur Profil: {me_resp.text}")
            return
        print(f"✅ Profil vérifié : {me_resp.json()['email']}")

        # 4. Vérification des Stats
        print("📊 Phase 4 : Vérification des statistiques globales...")
        stats_resp = client.get("/stats")
        if stats_resp.status_code == 200:
            print(f"✅ Stats : {stats_resp.json()}")
        
        print("\n🏆 TEST D'INTÉGRATION RÉUSSI : Le flux complet Inscription -> Connexion -> Authentification est opérationnel.")

if __name__ == "__main__":
    test_full_journey()
