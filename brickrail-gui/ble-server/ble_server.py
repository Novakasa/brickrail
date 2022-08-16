import asyncio
import websockets
import json
import os

from ble_project import BLEProject
from serial_data import SerialData

CHUNK_SIZE = 1000
PORT = 64569


class ClientCommand:

    @classmethod
    def from_json(cls, str):
        obj = json.loads(str)
        hub = obj["hub"]
        funcname = obj["func"]
        args = obj["args"]
        return_id = obj["return_id"]
        return cls(hub, funcname, args, return_id)
    
    def __init__(self, hub, funcname, args, return_key=None):
        self.hub = hub
        self.funcname = funcname
        self.args = args
        self.return_key = return_key
    
    async def commit(self, project):
        if self.hub is None:
            func = getattr(project, self.funcname)
        else:
            func = getattr(project.hubs[self.hub], self.funcname)

        if asyncio.iscoroutinefunction(func):
            print(f"awaiting coroutine: {func} with args {self.args}")
            result = await func(*self.args)
        else:
            print(f"executing func: {func}")
            result = func(*self.args)
        
        if self.return_key is not None:
            send_data = SerialData(self.return_key, self.hub, result)
            await project.out_queue.put(send_data)


class BLEServer:

    def __init__(self):
        self.project = BLEProject
        self.server = None
        self.connected = False

    
    async def out_handler(self, websocket, path):
        while True:
            print("[BLEServer] waiting for messages to send...")
            serial_data = await project.out_queue.get()
            await websocket.send(serial_data.to_json())
    
    async def in_handler(self, websocket, path):
        print("[BLEServer] waiting for messages to receive...")
        async for message in websocket:
            print(f"[BLEServer] got message: {message}")
            command = ClientCommand.from_json(message)
            await command.commit(project)

    async def server_loop(self, websocket, path):
        self.connected = True
        print("listening for commands now")
        
        in_task = asyncio.ensure_future(self.in_handler(websocket, path))
        out_task = asyncio.ensure_future(self.out_handler(websocket, path))
        done, pending = await asyncio.wait([in_task, out_task], return_when=asyncio.FIRST_COMPLETED)
        print("in or out handler are done!")
        for task in pending:
            task.cancel()
        # except websockets.exceptions.ConnectionClosed:
        #     break
        self.connected = False

    async def serve(self):
        print("serving now")
        async def wait_for_connected():
            while not self.connected:
                await asyncio.sleep(1)
        async def wait_for_disconnected():
            while self.connected:
                await asyncio.sleep(1)
        async with websockets.serve(self.server_loop, "localhost", PORT) as server:
            await wait_for_connected()
            await wait_for_disconnected()

if __name__ == "__main__":
    print("running ble server")
    print(f"cwd: {os.getcwd()}")
    project = BLEProject()
    server = BLEServer()
    asyncio.run(server.serve())
