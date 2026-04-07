import urllib.request
import os

url = "https://www.soundjay.com/phone/telephone-ring-01a.mp3"
os.makedirs("d:/Nouveau dossier/assets/audio", exist_ok=True)
output_path = "d:/Nouveau dossier/assets/audio/ringtone.mp3"

req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response, open(output_path, 'wb') as out_file:
        data = response.read()
        out_file.write(data)
    print("Download successful")
except Exception as e:
    print(f"Error downloading: {e}")
