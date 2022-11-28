import asyncio

from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

_IN_ID_START   = 2  #ASCII start of text
_IN_ID_END     = 10 #ASCII line feed
_IN_ID_MSG_ACK = 6  #ASCII ack
_IN_ID_RPC     = 17 #ASCII device control 1
_IN_ID_SYS     = 18 #ASCII device control 2
_IN_ID_SIGNAL  = 19 #ASCII device control 3
_IN_ID_MSG_ERR = 21 #ASCII nak

_OUT_ID_START   = 2  #ASCII start of text
_OUT_ID_END     = 10 #ASCII line feed
_OUT_ID_MSG_ACK = 6  #ASCII ack
_OUT_ID_DATA    = 17 #ASCII device control 1
_OUT_ID_SYS     = 18 #ASCII device control 2
_OUT_ID_SIGNAL  = 19 #ASCII device control 3
_OUT_ID_MSG_ERR = 21 #ASCII nak

_SYS_CODE_STOP  = 0
_SYS_CODE_READY = 1

_CHUNK_LENGTH = 80

def xor_checksum(bytes):
    checksum = 0xFF
    for byte in bytes:
        checksum ^= byte
    return checksum

class BLEHub:

    def __init__(self):

        self.hub = PybricksHub()
        self.hub.nus_observable.subscribe(self._on_hub_nus)
        self.msg_ack = asyncio.Queue()
        self.output_buffer = bytearray()
        self.output_queue = asyncio.Queue()
        self.line_buffer = bytearray()
        self.hub_ready = asyncio.Event()
        self.persistent = False
    
    def _on_hub_nus(self, data):
        if self.hub._downloading_via_nus:
            return
        
        self.output_buffer += data
        self.line_buffer += data

        while _OUT_ID_END in self.output_buffer:
            index = self.output_buffer.find(_OUT_ID_END)
            line = self.output_buffer[0:index]
            self.output_queue.put_nowait(line)
            print(f"got msg: {repr(line)}")
            del self.output_buffer[0 : index + 1]
        
        while b"\r\n" in self.line_buffer:
            index = self.line_buffer.find(b"\r\n")
            line = self.line_buffer[0:index]
            try:
                decoded_line = line.decode()
            except UnicodeDecodeError:
                print(repr(line))
            else:
                print("decoded:", decoded_line)
            del self.line_buffer[0 : index + 2]
    
    async def hub_message_handler(self, bytes):
        out_id = bytes[0]

        if out_id == _OUT_ID_MSG_ACK:
            await self.msg_ack.put(True)
            return
        if out_id == _OUT_ID_MSG_ERR:
            await self.msg_ack.put(False)
            return

        checksum = bytes[-1]
        output_checksum = xor_checksum(bytes[:-1])
        if not checksum == output_checksum:
            await self.send_ack(False)
            print(f"received {bytes[:-1]}, checksum mismatch! {checksum} != {output_checksum}")
            return
        await self.send_ack(True)
        data = bytes[1:-1] #strip out_id and checksum

        if out_id == _OUT_ID_SYS:
            assert len(data) == 1
            sys_code = data[0]
            if sys_code == _SYS_CODE_READY:
                self.hub_ready.set()
            if sys_code == _SYS_CODE_STOP:
                self.hub_ready.clear()
        
        if out_id == _OUT_ID_DATA:
            struct  = eval(data.decode())
            print("got data:", struct)
    
    async def rpc(self, funcname, args):
        funcname_hash = xor_checksum(bytes(funcname, "ascii"))
        await self.send_bytes(bytes([_IN_ID_RPC, funcname_hash]) + args)
        
    async def send_bytes(self, data):
        assert len(data) <= _CHUNK_LENGTH
        checksum = xor_checksum(data)
        ack_result = False
        while not ack_result:
            full_data = bytes([len(data)+1]) + data + bytes([checksum, _IN_ID_END])
            print(f"sending msg: {repr(full_data)}, checksum={checksum}")
            await self.hub.write(full_data)
            try:
                ack_result = await asyncio.wait_for(self.msg_ack.get(), timeout=1.0)
            except asyncio.TimeoutError:
                if self.persistent:
                    print(f"Wait for acknowledgement timed out, resending {data}")
                else:
                    print(f"Wait for acknowledgement timed out!")
                    return
            else:
                if not ack_result:
                    if self.persistent:
                        print(f"Error received from hub, resending {data}")
                    else:
                        print(f"Error received from hub!")
                        return
        print("...successful!")
    
    async def send_ack(self, success):
        if success:
            await self.hub.write(bytes([1, _IN_ID_MSG_ACK, _IN_ID_END]))
        else:
            await self.hub.write(bytes([1, _IN_ID_MSG_ERR, _IN_ID_END]))
    
    async def send_sys_code(self, code):
        await self.send_bytes(bytes([_IN_ID_SYS, code]))
    
    async def connect(self, device):
        await self.hub.connect(device)
    
    async def disconnect(self):
        await self.hub.disconnect()
    
    async def run(self, program, wait=False):

        async def run_coroutine():
            await self.hub.run(program, print_output=False, wait=True)
            self.hub_ready.clear()
        
        async def output_loop():
            while True:
                msg = await self.output_queue.get()
                await self.hub_message_handler(msg)
        
        run_task = asyncio.create_task(run_coroutine())
        output_task = asyncio.create_task(output_loop())

        await self.hub_ready.wait()

        if not wait:
            return

        await run_task
        output_task.cancel()
    
    async def stop_program(self):
        await self.send_sys_code(_SYS_CODE_STOP)

async def io_test():
    device = await find_device()
    print(device)
    test_hub = BLEHub()
    await test_hub.connect(device)
    try:
        await test_hub.run("E:/repos/brickrail/brickrail-gui/ble-server/hub_programs/test_io.py", wait=False)
        await asyncio.sleep(1.0)
        await test_hub.rpc("respond", bytearray([1,4,5,253]))
        await asyncio.sleep(1.0)
        await test_hub.rpc("respond", bytearray([1,2,3,4]))
        await asyncio.sleep(1.0)
        for i in range(256):
            await test_hub.rpc("respond", bytearray([i]))
            # await asyncio.sleep(0.2)
        await asyncio.sleep(1)
        await test_hub.stop_program()
    finally:
        await test_hub.disconnect()


if __name__ == "__main__":
    asyncio.run(io_test())