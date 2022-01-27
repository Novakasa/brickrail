import asyncio

from pybricksdev.connections import PybricksHub
from pybricksdev.ble import find_device
from pybricksdev.connections import NUS_RX_UUID


from serial_data import SerialData

def get_script_path(program):
    if program == "train":
        return "E:/repos/brickrail/ble-server/hub_programs/auto_train.py"
    if program == "layout_controller":
        return "E:/repos/brickrail/ble-server/hub_programs/layout_controller.py"
    

def chunk(data, size):
    for i in range(0, len(data), size):
        yield data[i : i + size] + b"#"


class BLEHub:
    
    def __init__(self, name, program, out_queue=None, address=None):

        # self.hub = PybricksHub()
        self.hub = PybricksHub()
        self.name = name
        self.program = program
        self.address = address
        self.out_queue = out_queue
        self.run_task = None
        self.msg_acknowledged = asyncio.Event()
    
    def set_name(self, name):
        self.name = name
    
    def set_address(self, address):
        self.address = address
    
    async def connect(self):
        try:
            device = await find_device(self.address)
            await self.hub.connect(device)
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

    async def handle_output(self, raw):
        # print("[output handler]: got msg:", msg)
        if raw.decode().find("bytearray(") == 0:
            bytearr = bytearray(eval(raw.decode()))
            # print("got bytearray line with length", len(bytearr))
            print(list(bytearr))
            return
        for line in raw.decode().split("$"):
            if not line:
                continue
            # print("[output handler]: processing line:", msg)
            if line=="msg_ack":
                # print("message acknowledged from hub!")
                self.msg_acknowledged.set()
                continue
            if line.find("data::") == 0:
                print("got return data from hub!", line)
                data = SerialData.from_hub_msg(line)
                data.hub = self.name
                await self.out_queue.put(data)
                continue
            print(line)
    
    async def output_loop(self):
        print("starting output handler loop")
        while self.hub.program_running:
            while self.hub.output:
                raw = self.hub.output.pop(0)
                await self.handle_output(raw)
            await asyncio.sleep(0.05)
        print("output loop finished!")
    
    async def run(self):
        print("initiating run!")
        async def hub_run():

            print(f"hub {self.name} run start!")
            script_path = get_script_path(self.program)
            print("initiating run!")
            await self.hub.run(script_path, wait=False, print_output=False)
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
        
        for block in chunk(message, 80):
            self.msg_acknowledged.clear()
            print("writing block:",block)
            await self.hub.client.write_gatt_char(NUS_RX_UUID, block, False)
            try:
                await asyncio.wait_for(self.msg_acknowledged.wait(), timeout=10.0)
            except asyncio.TimeoutError:
                print("waiting for acknowledgement timed out!!")
    
    async def pipe_command(self, cmdstr):
        assert self.running
        message = "cmd::" + cmdstr
        await self.send_message(message)

    
    async def rpc(self, funcname, args):
        assert self.running
        struct = {"func": funcname, "args": args}
        message = "rpc::" + repr(struct)
        await self.send_message(message)


async def main():

    train = BLEHub("white train", "train", asyncio.Queue())
    await train.connect()
    await train.run()
    await train.rpc("slow", [])
    input("waiting for input")
    await train.rpc("queue_dump_buffers", [])
    await train.stop()
    await train.hub.user_program_stopped.wait()
    await asyncio.sleep(1)
    print("done with main!")

if __name__ == "__main__":
    asyncio.run(main())