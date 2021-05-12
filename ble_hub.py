from pybricksdev.connections import PybricksHub, BLEPUPConnection
from pybricksdev.ble import find_device
from pybricksdev.connections import NUS_RX_UUID

import asyncio

from serial_data import SerialData

def get_script_path(program):
    if program == "train":
        return "E:/repos/brickrail/auto_train_updated.py"
    if program == "layout_controller":
        return "E:/repos/brickrail/layout_controller.py"

class BLEHub:
    
    def __init__(self, name, program, out_queue=None, address=None):

        # self.hub = PybricksHub()
        self.hub = PybricksHub()
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
            try:
                self.address = await find_device("Pybricks Hub")
            except Exception as exception:
                data = SerialData("connect_error", self.name, repr(exception))
                await self.out_queue.put(data)
                return
        try:
            await self.hub.connect(self.address)
        except Exception as exception:
            data = SerialData("connect_error", self.name, repr(exception))
            await self.out_queue.put(data)
            return
        data = SerialData("connected", self.name, None)
        await self.out_queue.put(data)
    
    async def disconnect(self):
        await self.hub.disconnect()
        data = SerialData("disconnected", self.name, None)
        await self.out_queue.put(data)
    
    async def wait_for_program_stop(self):
        await self.hub.user_program_stopped.wait()

    async def handle_output(self, msg):
        for line in msg.split("$")[:-1]:
            if line.find("data::") == 0:
                print("got return data from hub!", line)
                data = SerialData.from_hub_msg(line)
                data.hub = self.name
                await self.out_queue.put(data)
            else:
                print(line)
    
    async def output_loop(self):
        print("starting output handler loop")
        while self.hub.program_running:
            while self.hub.output:
                line = self.hub.output.pop(0).decode()
                await self.handle_output(line)
            await asyncio.sleep(0.05)
        print("output loop finished!")
    
    async def run(self):
        print("initiating run!")
        async def hub_run():
            print(f"hub {self.name} run start!")
            script_path = get_script_path(self.program)
            print("initiating run!")
            await self.hub.run(script_path, wait=False, print_output=True)
            while not self.hub.program_running:
                await asyncio.sleep(0.05)
            print("hub is now running!")
            data = SerialData("program_started", self.name, None)
            await self.out_queue.put(data)

            await self.output_loop()

            print(f"hub {self.name} run complete!")
            data = SerialData("program_stopped", self.name, None)
            await self.out_queue.put(data)
            self.run_task = None

        self.run_task = asyncio.create_task(hub_run())
        while not self.hub.program_running:
            await asyncio.sleep(0.05)
        # await asyncio.sleep(1)
        print(f"hub {self.name} is running now!") 
    
    async def stop(self):
        await self.send_message("stop_program")

    @property
    def running(self):
        return self.hub.program_running
    
    @property
    def connected(self):
        return self.hub.connected

    async def send_message(self, message):
        if isinstance(message, str):
            message = bytearray(message + "$", encoding="utf8")
        await self.hub.client.write_gatt_char(NUS_RX_UUID, message, False)
    
    async def pipe_command(self, cmdstr):
        assert self.running
        message = "cmd::" + cmdstr
        await self.send_message(message)


async def main():

    train = BLEHub("white train", "train", asyncio.Queue())
    await train.connect()
    await train.run()
    await train.pipe_command("train.start()")
    await asyncio.sleep(5)
    await train.send_message("stop_program")
    await train.hub.user_program_stopped.wait()
    await train.run()
    await train.pipe_command("train.start()")
    await asyncio.sleep(5)
    await train.send_message("stop_program")
    await train.hub.user_program_stopped.wait()
    print(train.hub.output)
    """

    controller = BLEHub("layout_controller", "layout_controller", asyncio.Queue())
    await controller.connect()
    await controller.run()
    await controller.pipe_command("controller.attach_device(Switch('switch0', Port.A))")
    await asyncio.sleep(1)
    await controller.pipe_command("controller.devices['switch0'].switch('left')")
    await asyncio.sleep(2)
    await controller.pipe_command("controller.devices['switch0'].switch('right')")

    await controller.hub.wait_until_state(controller.hub.IDLE)
    print(controller.hub.output)
    """
    print("done with main!")

if __name__ == "__main__":
    asyncio.run(main())