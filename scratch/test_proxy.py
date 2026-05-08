import urllib.request
import urllib.error

url = 'https://corporate-connect.onrender.com/media/proxy?url=https://res.cloudinary.com/demo/image/upload/sample.jpg'
try:
    with urllib.request.urlopen(url) as f:
        print(f"Status: {f.status}")
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(f"Headers: {e.headers}")
except Exception as e:
    print(f"Error: {e}")
