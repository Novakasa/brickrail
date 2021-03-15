import asyncio
import websockets
import json

from ble_project import BLEProject

CHUNK_SIZE = 1000
PORT = 64569

class ReturnData:

    def __init__(self, id, data):
        self.id = id
        self.data = data
    
    def serialize(self):
        send_data = {"id": self.id, "data": self.data}
        return json.dumps(send_data)


class BLEServer:

    def __init__(self):
        self.project = BLEProject
        self.server = None
        self.connected = False

    async def evaluate_command(self, str, websocket):

        result = eval(str)
        if isinstance(result, ReturnData):
            await websocket.send(result.serialize())

    async def command_receiver(self, websocket, path):
        self.connected = True
        print("sending test message")
        await websocket.send("test message from server to client!!")
        print("listening for commands now")
        while True:
            try:
                print("[BLEServer] waiting for message...")
                msg = await websocket.recv()
                print(f"[BLEServer] got message: {msg}")
                await self.evaluate_command(msg, websocket)
            except websockets.exceptions.ConnectionClosed:
                break
        self.connected = False

    def serve(self):
        print("serving now")
        self.server = websockets.serve(self.command_receiver, "localhost", PORT)
        asyncio.get_event_loop().run_until_complete(self.server)
        async def wait_for_connected():
            while not self.connected:
                await asyncio.sleep(1)
        async def wait_for_disconnected():
            while self.connected:
                await asyncio.sleep(1)
        asyncio.get_event_loop().run_until_complete(wait_for_connected())
        asyncio.get_event_loop().run_until_complete(wait_for_disconnected())

if __name__ == "__main__":
    print("running ble server")
    project = BLEProject()
    server = BLEServer()
    server.serve()