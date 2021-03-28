from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device

import asyncio

from serial_data import SerialData

def get_script_path(program):
    if program == "train":
        return "E:/repos/brickrail/autonomous_train.py"
    if program == "layout_controller":
        return "E:/repos/brickrail/layout_controller.py"

class BLEHub:
    
    def __init__(self, name, program, out_queue=None, address=None):

        self.hub = BLEPUPConnection()
        self.name = name
        self.program = program
        self.address = address
        self.out_queue = out_queue
        self.run_task = None
    
    def set_name(self, name):
        self.name = name
    
    def set_address(self, address):
        self.address = address
    
    async def connect(self):
        if self.address is None:
            self.address = await find_device("Pybricks Hub")
        await self.hub.connect(self.address)
    
    async def handle_output(self, line):
        if line.find("data::") == 0:
            print("got return data from hub!", line)
            data = SerialData.from_hub_msg(line)
            data.hub = self.name
            await self.out_queue.put(data)
            return
        print(line)
    
    async def output_loop(self):
        print("starting output handler loop")
        while self.hub.state == self.hub.RUNNING:
            while self.hub.output:
                line = self.hub.output.pop(0).decode()
                await self.handle_output(line)
            await asyncio.sleep(0.05)
    
    async def run(self):
        print("initiating run!")
        async def hub_run():
            print(f"hub {self.name} run start!")
            script_path = get_script_path(self.program)
            print("initiating run!")
            await self.hub.run(script_path, wait=False, print_output=False)
            print("waiting for running state!")
            await self.hub.wait_until_state(self.hub.RUNNING)
            print("hub is now running!")

            await self.output_loop()

            print(f"hub {self.name} run complete!")
            self.run_task = None

        self.run_task = asyncio.create_task(hub_run())
        await self.hub.wait_until_state(self.hub.RUNNING)
        print(f"hub {self.name} is running now!")

    @property
    def running(self):
        assert self.connected
        return self.run_task is not None
    
    @property
    def connected(self):
        return self.hub.connected
    
    async def pipe_command(self, cmdstr):
        assert self.running
        await self.hub.write(bytearray(cmdstr, encoding='utf8'))


async def main():

    train = BLEHub("white train", "train", asyncio.Queue())
    await train.connect()
    await train.run()
    await train.hub.write(b"123456789")
    await train.hub.write(b"xd some mess")

    print("done with main!")

    await train.hub.wait_until_state(train.hub.IDLE)

if __name__ == "__main__":
    asyncio.run(main())