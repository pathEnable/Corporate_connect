import sys
import os
import uuid
from fastapi.testclient import TestClient

# On ajoute le dossier 'backend' au chemin de recherche de Python
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app

client = TestClient(app)

# On génère des données uniques pour éviter les erreurs "Déjà pris" à chaque test
unique_id = str(uuid.uuid4())[:8]
test_user = {
    "email": f"test_{unique_id}@example.com",
    "password": "testpassword123",
    "full_name": "Test User",
    "username": f"user_{unique_id}"
}
test_033940bf@example.com

def test_read_root():
    """Vérifie que l'API est en ligne."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "active"

def test_register_user():
    """Vérifie que l'inscription fonctionne."""
    response = client.post("/auth/register", json=test_user)
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_login_user():
    """Vérifie que la connexion fonctionne avec les identifiants créés."""
    login_data = {
        "email": test_user["email"],
        "password": test_user["password"]
    }
    response = client.post("/auth/login", json=login_data)
    assert response.status_code == 200
    assert "access_token" in response.json()
    return response.json()["access_token"]

def test_get_me_protected():
    """Vérifie qu'on peut récupérer son profil avec un Token."""
    # 1. On se connecte pour avoir le token
    login_data = {"email": test_user["email"], "password": test_user["password"]}
    login_res = client.post("/auth/login", json=login_data)
    token = login_res.json()["access_token"]

    # 2. On appelle la route protégée /auth/me
    headers = {"Authorization": f"Bearer {token}"}
    response = client.get("/auth/me", headers=headers)
    
    assert response.status_code == 200
    assert response.json()["email"] == test_user["email"]

def test_stats_increment():
    """Vérifie que la route /stats renvoie un nombre positif."""
    response = client.get("/stats")
    assert response.status_code == 200
    assert response.json()["total_users"] >= 1
