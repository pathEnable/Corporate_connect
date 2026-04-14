import os
from dotenv import load_dotenv
from mistralai.client import Mistral

load_dotenv()

api_key = os.getenv("MISTRAL_API_KEY")

if not api_key:
    print("Error: MISTRAL_API_KEY not found in .env")
    exit(1)

print(f"Tentative de connexion a Mistral avec la cle : {api_key[:5]}...")

client = Mistral(api_key=api_key)

try:
    response = client.chat.complete(
        model="mistral-small-latest",
        messages=[{"role": "user", "content": "Dit 'Bonjour, je suis pret' si tu m'entends."}]
    )
    print(f"Succes ! Mistral repond : {response.choices[0].message.content}")
except Exception as e:
    print(f"Erreur lors de la connexion : {str(e)}")
