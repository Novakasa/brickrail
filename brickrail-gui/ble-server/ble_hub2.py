import asyncio

from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

_IN_ID_START   = 2  #ASCII start of text
_IN_ID_END     = 3  #ASCII end of text
_IN_ID_MSG_ACK = 6  #ASCII ack
_IN_ID_RPC     = 17 #ASCII device control 1
_IN_ID_SYS     = 18 #ASCII device control 2
_IN_ID_SIGNAL  = 19 #ASCII device control 3
_IN_ID_MSG_ERR = 21 #ASCII nak

_OUT_ID_START   = 2  #ASCII start of text
_OUT_ID_END     = 3  #ASCII end of text
_OUT_ID_MSG_ACK = 6  #ASCII ack
_OUT_ID_DATA    = 17 #ASCII device control 1
_OUT_ID_SYS     = 18 #ASCII device control 2
_OUT_ID_SIGNAL  = 19 #ASCII device control 3
_OUT_ID_MSG_ERR = 21 #ASCII nak

_CHUNK_LENGTH = 80

def xor_checksum(bytes):
    checksum = 0xFF
    for byte in bytes:
        checksum ^= byte
    return checksum

class BLEHub:

    def __init__(self):

        self.hub = PybricksHub()
        self.hub.nus_observable.subscribe(self._on_nus)
        self.msg_ack = asyncio.Queue
        self.output_buffer = bytearray()
        self.output_queue = asyncio.Queue
    
    def _on_hub_nus(self, data):
        if self.hub._downloading_via_nus:
            return
        
        self.output_buffer += data

        while _OUT_ID_END in self.output_buffer:
            index = self.output_buffer.find(_OUT_ID_END)
            self.output_queue.put_nowait(self.output_buffer[0:index])
            del self.output_buffer[0 : index + 1]
    
    async def hub_message_handler(self, bytes):
        out_id = bytes[0]

        if out_id == _OUT_ID_MSG_ACK:
            await self.msg_ack.put(True)
            return
        if out_id == _OUT_ID_MSG_ERR:
            await self.msg_ack.put(False)
            return

        checksum = bytes[-1]
        if not checksum == xor_checksum(bytes[:-1]):
            await self.send_ack(False)
            return
        await self.send_ack(True)
        data = bytes[1:-1] #strip out_id and checksum

        if out_id == _OUT_ID_SYS:
            assert len(bytes) == 2
            sys_code = bytes[1]
        
        if out_id == _OUT_ID_DATA:
            struct  = eval(data.decode())
        
    async def send_bytes(self, bytes):
        assert len(bytes) <= _CHUNK_LENGTH
        checksum = xor_checksum(bytes)
        ack_ok = None
        while not ack_ok == checksum:
            await self.hub.write(bytes + bytes([checksum, _IN_ID_END]))
            try:
                ack_ok = await asyncio.wait_for(self.msg_ack.get(), 1)
            except asyncio.TimeoutError:
                print(f"Wait for acknowledgement timed out, resending")
            else:
                if not ack_ok:
                    print(f"Error received from hub, retrying")
    
    async def send_ack(self, success):
        if success:
            self.hub.write(bytes([_IN_ID_MSG_ACK, _IN_ID_END]))
        else:
            self.hub.write(bytes([_IN_ID_MSG_ERR, _IN_ID_END]))

