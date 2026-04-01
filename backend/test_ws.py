import asyncio
import websockets
import json

async def test_global_ws():
    # Use a dummy user_id and a valid token if possible, or just see if the endpoint is reachable
    user_id = "00000000-0000-0000-0000-000000000000"
    url = f"ws://localhost:8000/ws/global/{user_id}"
    
    try:
        async with websockets.connect(url) as websocket:
            print("Successfully connected to Global WS")
            # The server will probably close wait if no token, 
            # but getting here means the route is active.
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_global_ws())
