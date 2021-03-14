from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device

import asyncio

class BLETrain:
    
    def __init__(self, name, address=None):

        self.hub = BLEPUPConnection()
        self.address = address
        self.run_task = None
    
    async def connect(self):
        if self.address is None:
            self.address = await find_device("Pybricks Hub")
        await self.hub.connect(self.address)
    
    async def run(self):

        async def train_run():
            await self.hub.run("autonomous_train.py")
            print("train run complete!")
            self.run_task = None

        self.run_task = asyncio.create_task(train_run())
        await self.hub.wait_until_state(self.hub.RUNNING)

    
    @property
    def running(self):
        assert self.connected
        return self.run_task is not None
    
    @property
    def connected(self):
        return self.hub.connected
    
    async def start(self):
        assert self.running
        await self.hub.write(b"train.start()")
    
    async def stop(self):
        assert self.running
        await self.hub.write(b"train.stop()")
    
    async def slow(self):
        assert self.running
        await self.hub.write(b"train.slow()")
    
    async def wait(self):
        assert self.running
        await self.hub.write(b"train.wait()")

async def main():

    train = BLETrain("white train")
    await train.connect()
    await train.run()

    """
    await asyncio.sleep(1)
    await train.slow()
    await asyncio.sleep(5)
    await train.start()
    await asyncio.sleep(5)
    await train.slow()
    await asyncio.sleep(5)
    await train.stop()
    await asyncio.sleep(5)
    """

    await train.hub.write(b"xd some message lol")

    print("done with main!")

    await train.hub.wait_until_state(train.hub.IDLE)


asyncio.run(main())