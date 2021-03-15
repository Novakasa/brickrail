from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device

import asyncio

class BLEHub:
    
    def __init__(self, name, script_path, address=None):

        self.hub = BLEPUPConnection()
        self.name = name
        self.script_path = script_path
        self.address = address
        self.run_task = None
    
    async def connect(self):
        if self.address is None:
            self.address = await find_device("Pybricks Hub")
        await self.hub.connect(self.address)
    
    async def run(self):

        async def hub_run():
            await self.hub.run(self.script_path)
            print(f"hub {self.name} run complete!")
            self.run_task = None

        self.run_task = asyncio.create_task(hub_run())
        await self.hub.wait_until_state(self.hub.RUNNING)

    
    @property
    def running(self):
        assert self.connected
        return self.run_task is not None
    
    @property
    def connected(self):
        return self.hub.connected
    
    async def pipe_command(self, cmdstr):
        assert self.running
        await self.hub.write(bytearray(cmdstr))