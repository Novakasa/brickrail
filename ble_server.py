import asyncio
import websockets
import json

from ble_project import BLEProject

CHUNK_SIZE = 1000
PORT = 64569

class Command:

    @classmethod
    def from_json(cls, str):
        data = json.loads(str)
        hub = data["hub"]
        funcname = data["func"]
        args = data["args"]
        return_id = data["return_id"]
        return cls(hub, funcname, args, return_id)
    
    def __init__(self, hub, funcname, args, return_id=None):
        self.hub = hub
        self.funcname = funcname
        self.args = args
        self.return_id = return_id
    
    async def commit(self, project, websocket):
        if self.hub is None:
            func = getattr(project, self.funcname)
        else:
            func = getattr(project.hubs[self.hub], self.funcname)

        if asyncio.iscoroutinefunction(func):
            print(f"awaiting coroutine: {func}")
            result = await func(*self.args)
        else:
            print(f"executing func: {func}")
            result = func(*self.args)
        
        if self.return_id is not None:
            send_data = {"id": self.return_id, "data": result}
            send_data_msg = json.dumps(send_data)
            await websocket.send(send_data_msg)


class BLEServer:

    def __init__(self):
        self.project = BLEProject
        self.server = None
        self.connected = False

    async def evaluate_command(self, str, websocket):

        command = Command.from_json(str)
        await command.commit(project, websocket)

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