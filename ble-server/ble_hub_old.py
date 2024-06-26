import asyncio

from pybricksdev.connections.pybricks import PybricksHub
from pybricksdev.ble import find_device
from pathlib import Path

from serial_data import SerialData

def get_script_path(program):
    if program == "train":
        return "ble-server/hub_programs/auto_train.py"
    if program == "layout_controller":
        return "ble-server/hub_programs/layout_controller.py"
    

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
        self.running = False
        self.initiated_run = False
    
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
        if " = " in raw.decode():
            key = raw.decode().split("=")[0][:-1]
            data = eval("=".join(raw.decode().split("=")[1:])[1:])
            # self.dataset[key] = data
            print(f"added data {key} to dataset")
            print(data)
            return
        print(raw.decode())
        for line in raw.decode().split("$"):
            if not line:
                continue
            # print("[output handler]: processing line:", msg)
            if line=="msg_ack":
                # print("message acknowledged from hub!")
                self.msg_acknowledged.set()
                continue
            if line=="save_dataset":
                # self.dataset.to_netcdf("buffer_dump.nc")
                print("dumped dataset to buffer_dump.nc")
                continue
            if line.find("info::") == 0:
                msg = line.split("info::")[1]
                if msg == "ready":
                    self.running = True
                    self.initiated_run = False
                    data = SerialData("program_started", self.name, None)
                    await self.out_queue.put(data)
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
        while self.running or self.initiated_run:
            while self.hub.output:
                raw = self.hub.output.pop(0)
                await self.handle_output(raw)
            await asyncio.sleep(0.05)
        print("output loop finished!")
    
    async def run(self):
        print("initiating run!")

        script_path = get_script_path(self.program)
        async def run_task():
            print("initiating run!")
            self.initiated_run = True
            try:
                await self.hub.run(script_path, wait=True, print_output=False)
            finally:
                self.running = False
                self.initiated_run = False
                data = SerialData("program_stopped", self.name, None)
                await self.out_queue.put(data)

            print(f"hub {self.name} run complete!")
        asyncio.create_task(run_task())
        asyncio.create_task(self.output_loop())
        while not self.running:
            await asyncio.sleep(0.05)
    
    async def stop(self):
        await self.send_message("stop_program", ack=False)
    
    @property
    def connected(self):
        return self.hub.connected

    async def send_message(self, message, ack=True):
        if isinstance(message, str):
            message = bytearray(message + "$", encoding="utf8")
        
        for block in chunk(message, 80):
            self.msg_acknowledged.clear()
            print("writing block:",block)
            await self.hub.write(block)
            if not ack:
                return
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
    await train.rpc("start", [])
    input("waiting for input")
    await train.rpc("queue_dump_buffers", [])
    await train.stop()
    await train.hub.user_program_stopped.wait()
    await train.disconnect()
    await asyncio.sleep(1)
    print("done with main!")

if __name__ == "__main__":
    asyncio.run(main())