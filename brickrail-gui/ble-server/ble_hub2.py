
import asyncio
from random import randint
import time

from rx.subject import Subject

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

def mod_checksum(data):
    checksum = 0x00
    for byte in data:
        checksum += byte
    return checksum%256

class BLEHub:

    def __init__(self):

        self.hub = PybricksHub()
        self.hub.nus_observable.subscribe(self._on_hub_nus)
        self.msg_ack = asyncio.Queue()
        self.output_buffer = bytearray()
        self.output_queue = asyncio.Queue()
        self.data_queue = asyncio.Queue()
        self.data_subject = Subject()
        self.input_queue = asyncio.Queue()
        self.input_lock = asyncio.Lock()
        self.line_buffer = bytearray()
        self.hub_ready = asyncio.Event()
        self.program_stopped = asyncio.Event()
        self.msg_len = None
        self.output_byte_arrived = asyncio.Event()
        self.output_byte_time = time.time()
    
    def add_to_output_buffer(self, byte):
        self.output_byte_arrived.set()
        self.output_byte_time = time.time()

        if self.msg_len is None:
            self.msg_len = byte
            return
        
        if byte == _OUT_ID_END:
            if len(self.output_buffer) >=2 and self.output_buffer[-1] == b"\r"[0]:
                if self.output_buffer[0] >= 32:
                    try:
                        line = (bytes([self.msg_len]) + self.output_buffer[:-1]).decode()
                    except UnicodeDecodeError:
                        pass
                    else:
                        print("[IOHub]", line)
                        self.output_buffer = bytearray()
                        self.msg_len = None
                        return

        if len(self.output_buffer) == self.msg_len and byte == _OUT_ID_END:
            if len(self.output_buffer) == self.msg_len:
                self.output_queue.put_nowait(self.output_buffer)
            else:
                asyncio.create_task(self.send_ack(False))
            self.output_buffer = bytearray()
            self.msg_len = None
            return
        
        self.output_buffer += bytes([byte])
    
    def _on_hub_nus(self, data):
        # print("nus:", data)
        if self.hub._downloading_via_nus:
            return
        
        for byte in data:
            self.add_to_output_buffer(byte)
    
    async def hub_message_handler(self, bytes):
        out_id = bytes[0]

        # print("handling msg:", bytes)

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
            # print("got data:", [byte for byte in data])
            await self.data_queue.put(data)
            self.data_subject.on_next(data)
    
    async def rpc(self, funcname, args=None):
        encoded = bytes(funcname, "ascii")
        attr_hash1 = xor_checksum(encoded)
        attr_hash2 = mod_checksum(encoded)
        funcname_hash = bytes([attr_hash1,attr_hash2])
        if args is None:
            args = b""
        msg = bytes([_IN_ID_RPC]) + funcname_hash + args
        await self.send_safe(msg)
    
    async def send_ack(self, success):
        if success:
            await self.send_unsafe(bytes([_IN_ID_MSG_ACK]))
        else:
            await self.send_unsafe(bytes([_IN_ID_MSG_ERR]))
        
    async def send_safe(self, data, unreliable=False, persistent=True):
        assert len(data) <= _CHUNK_LENGTH
        checksum = xor_checksum(data)
        ack_result = False
        try_counter = 0
        while not ack_result:
            assert self.hub_ready.is_set()
            try_counter += 1
            if try_counter > 20:
                raise Exception("Maximum send tries exceeded!")
            
            full_data = bytes([len(data)+1]) + data + bytes([checksum, _IN_ID_END])

            if unreliable:
                if randint(0, 10) > 6:
                    print("data modified!")
                    full_data = bytearray(full_data)
                    mod_index = randint(0, len(full_data)-1)
                    # full_data.insert(mod_index, 88)
                    full_data.pop(mod_index)
                    # full_data[mod_index] = 88

            # print(f"sending msg: {repr(full_data)}, checksum={checksum}")
            async with self.input_lock:
                await self.hub.write(full_data)
            try:
                ack_result = await asyncio.wait_for(self.msg_ack.get(), timeout=.5)
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
        # print("...successful!")
    
    async def send_unsafe(self, data):
        async with self.input_lock:
            # print(f"sending unsafe: {repr(data)}")
            await self.hub.write(bytes([len(data)]) + data + bytes([_IN_ID_END]))
    
    async def send_sys_code(self, code):
        await self.send_safe(bytes([_IN_ID_SYS, code]))
    
    async def connect(self, device):
        await self.hub.connect(device)
    
    async def disconnect(self):
        await self.hub.disconnect()
    
    async def run(self, program, wait=False):

        async def run_coroutine():
            await self.hub.run(program, print_output=False, wait=True)
            self.program_stopped.set()
            self.hub_ready.clear()
        
        async def output_loop():
            while True:
                msg = await self.output_queue.get()
                await self.hub_message_handler(msg)
        
        async def timeout_loop():
            while True:
                if self.msg_len is not None and (time.time()-self.output_byte_time)>0.2:
                    for sub_data in self.output_buffer.split(b"\n"):
                        if len(sub_data)<1:
                            continue
                        if sub_data[0]>31 and sub_data[-1] == b"\r"[0]:
                            try:
                                print("[IOHub]", sub_data[:-1].decode())
                            except UnicodeDecodeError:
                                pass
                    print("output buffer timeout! Sending NAK", self.output_buffer)
                    self.output_buffer = bytearray()
                    self.msg_len = None
                    await self.send_ack(False)
                await asyncio.sleep(0.05)
        

        run_task = asyncio.create_task(run_coroutine())
        output_task = asyncio.create_task(output_loop())
        timeout_task = asyncio.create_task(timeout_loop())

        await asyncio.wait_for(self.hub_ready.wait(), timeout=5.0)

        if not wait:
            return

        await run_task
        await asyncio.sleep(1)
        output_task.cancel()
        timeout_task.cancel()
    
    async def stop_program(self):
        await self.send_sys_code(_SYS_CODE_STOP)
    
    async def wait_for_data_id(self, id):
        while True:
            get_task = asyncio.ensure_future(self.data_queue.get())
            program_stop_task = asyncio.ensure_future(self.program_stopped.wait())
            done, pending = await asyncio.wait({get_task, program_stop_task}, return_when=asyncio.FIRST_COMPLETED)
            assert not program_stop_task in done , "Program stopped before data arrived!"
            
            data = get_task.result()
            if data[0] == id:
                return data

async def io_test():

    response_queue = asyncio.Queue()

    def on_data(data):
        print(f"got data: {list(data)}")
        response_queue.put_nowait(data)
    
    async def test_response(data):
        await test_hub.rpc("respond", data)
        while not response_queue.empty():
            _ = response_queue.get_nowait()
        received = await asyncio.wait_for(response_queue.get(), 1.0)
        assert received == data

    device = await find_device()
    print(device)
    test_hub = BLEHub()
    test_hub.data_subject.subscribe(on_data)
    await test_hub.connect(device)
    try:
        await test_hub.run("brickrail-gui/ble-server/hub_programs/test_io.py", wait=False)
        await asyncio.sleep(1.0)
        await test_hub.rpc("respond", bytearray([1,4,5,253]))
        await asyncio.sleep(1.0)
        await test_hub.rpc("respond", bytearray([1,2,3,4]))
        await asyncio.sleep(1.0)
        await test_hub.rpc("print_data", bytearray([0, 1, 2, 10]))
        await asyncio.sleep(1.0)
        for i in range(0,256-16):
            await test_response(bytearray([j for j in range(i, i+16)]))
            # await asyncio.sleep(0.2)
        await asyncio.sleep(1)
        await test_hub.stop_program()
    finally:
        await test_hub.disconnect()


if __name__ == "__main__":
    print(xor_checksum(b"print_data"), xor_checksum(b"respond"))
    
    asyncio.run(io_test())