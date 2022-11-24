import asyncio

from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

_OUT_ID_SIGNAL = 0
_OUT_ID_DATA = 1
_OUT_ID_SYS = 2
_OUT_ID_EOM = b"\r"[0]

_SYS_CODE_STOP = 0
_SYS_CODE_READY = 1
_SYS_CODE_MSG_ACK = 2
_SYS_CODE_MSG_ERR = 3

class BLEHub:

    def __init__(self):

        self.hub = PybricksHub()
    
    def _on_hub_message(bytes):
        out_id = bytes[0]

        if out_id == _OUT_ID_SYS:
            assert len(bytes) == 2
            sys_code = bytes[1]
            if sys_code == _SYS_CODE_MSG_ACK:
                