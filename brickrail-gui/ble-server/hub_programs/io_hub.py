import micropython
from micropython import const
import usys
import uselect

from pybricks.tools import wait, StopWatch

# disable keyboard interrupt character
micropython.kbd_intr(-1)

_IN_ID_SIGNAL = const(0)
_IN_ID_RPC = const(1)
_IN_ID_SYS = const(2)
_IN_ID_EOM = const(b"\r"[0])

_OUT_ID_SIGNAL = const(0)
_OUT_ID_DATA = const(1)
_OUT_ID_SYS = const(2)
_OUT_ID_EOM = const(b"\r"[0])

_SYS_CODE_STOP = const(0)
_SYS_CODE_READY = const(1)
_SYS_CODE_MSG_ACK = const(2)
_SYS_CODE_MSG_ERR = const(3)

_CHUNK_LENGTH = const(80)

class IOHub:

    def __init__(self, device=None):
        self.running = False
        self.input_buffer = bytearray()
        self.input_checksum = None
        self.poll = uselect.poll()
        self.poll.register(usys.stdin)
        self.device = device
    
    def emit_data(self, key, data):
        usys.stdout.buffer.write(bytes([_OUT_ID_DATA]) + bytes(repr((key, data))) + bytes([_OUT_ID_EOM]))

    def emit_signal_code(self, code):
        usys.stdout.buffer.write(bytes([_OUT_ID_SIGNAL, code, _OUT_ID_EOM]))
    
    def emit_sys_code(self, code):
        usys.stdout.buffer.write(bytes([_OUT_ID_SYS, code, _OUT_ID_EOM]))

    def handle_input(self):
        msg_id = self.input_buffer[0]
        msg = self.input_buffer
        del msg[0]
        if msg_id == _IN_ID_SYS:
            code = msg[0]
            if code == _SYS_CODE_STOP:
                self.running = False
                return
        if msg_id == _IN_ID_RPC:
            try:
                struct = eval(msg)
            except SyntaxError:
                print("[ble_hub] Syntaxerror when running eval()")
                print(msg)
            func = getattr(self.device, struct["func"])
            args = struct["args"]
            _result = func(*args)
            return
        if msg_id == _IN_ID_SIGNAL:
            self.device.on_signal_received(msg)
            return
        
        print(self.input_buffer.decode())

    def update_input(self, byte):

        if byte == _IN_ID_EOM:
            self.handle_input()
            self.input_buffer = bytearray()
            return
        if len(self.input_buffer)%_CHUNK_LENGTH == 0 and self.input_checksum is not None:
            if self.input_checksum == byte:
                self.emit_sys_code(_SYS_CODE_MSG_ACK)
            else:
                self.emit_sys_code(_SYS_CODE_MSG_ERR)
            self.input_checksum = 0xFF
            return
        if self.input_checksum is None:
            self.input_checksum = 0xFF
        self.input_checksum ^= byte
        self.input_buffer.append(byte)

    def update(self, delta):
        self.device.update(delta)
        self.send_data_queue()

    def run_loop(self, max_delta):
        loop_watch = StopWatch()
        loop_watch.resume()
        last_time = loop_watch.time()
        self.running = True
        self.emit_sys_code(_SYS_CODE_READY)
        while self.running:
            if self.poll.poll(int(1000*max_delta)):
                byte = usys.stdin.buffer.read(1)[0]
                self.update_input(byte)
            t = loop_watch.time()
            delta = (t-last_time)/1000
            last_time = t
            self.update(delta)