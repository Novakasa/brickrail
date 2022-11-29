import asyncio

from random import randint

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
    
    def handle_output(self, byte):
        if byte == _OUT_ID_END:
            if self.output_buffer[0] == len(self.output_buffer)-1:
                self.output_queue.put_nowait(self.output_buffer[1:])
                self.output_buffer = bytearray()
                return
            try:
                decoded_line = self.output_buffer.decode()
            except UnicodeDecodeError:
                # hub messages contain non-decodable characters,
                # so this is a hub message which happens to
                # have a '\n' in the middle
                pass
            else:
                print("[IOHub]", decoded_line)
                self.output_buffer = bytearray()
                return

        self.output_buffer += bytes([byte])
    
    def _on_hub_nus(self, data):
        if self.hub._downloading_via_nus:
            return
        
        for byte in data:
            self.handle_output(byte)
    
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
        
    async def send_bytes(self, data, unreliable=True, persistent=True):
        assert len(data) <= _CHUNK_LENGTH
        assert self.hub_ready.is_set()
        checksum = xor_checksum(data)
        ack_result = False
        try_counter = 0
        while not ack_result:
            try_counter += 1
            if try_counter > 20:
                raise Exception("Maximum send tries exceeded!")
            
            full_data = bytes([len(data)+1]) + data + bytes([checksum, _IN_ID_END])

            if unreliable:
                if randint(0, 10) > 4:
                    print("data modified!")
                    full_data = bytearray(full_data)
                    mod_index = randint(0, len(full_data)-1)
                    # full_data.insert(mod_index, 88)
                    full_data.pop(mod_index)

            print(f"sending msg: {repr(full_data)}, checksum={checksum}")
            await self.hub.write(full_data)
            try:
                ack_result = await asyncio.wait_for(self.msg_ack.get(), timeout=5.0)
            except asyncio.TimeoutError:
                if persistent:
                    print(f"Wait for acknowledgement timed out, resending {data}")
                else:
                    raise Exception(f"Wait for acknowledgement timed out!")
            else:
                if not ack_result:
                    if persistent:
                        print(f"Error received from hub, resending {data}")
                    else:
                        raise Exception(f"Error received from hub!")
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

        await asyncio.wait_for(self.hub_ready.wait(), timeout=5.0)

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
        await test_hub.rpc("print_data", bytearray([0, 1, 2, 10]))
        for i in range(0,256,16):
            await test_hub.rpc("respond", bytearray([j for j in range(i, i+16)]))
            # await asyncio.sleep(0.2)
        await asyncio.sleep(1)
        await test_hub.stop_program()
    finally:
        await test_hub.disconnect()


if __name__ == "__main__":
    print(xor_checksum(b"print_data"), xor_checksum(b"respond"))
    
    asyncio.run(io_test())