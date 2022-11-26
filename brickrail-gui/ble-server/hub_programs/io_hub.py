import micropython
from micropython import const
import usys
import uselect

from pybricks.tools import wait, StopWatch

# disable keyboard interrupt character
micropython.kbd_intr(-1)

_IN_ID_START   = const(2)  #ASCII start of text
_IN_ID_END     = const(3)  #ASCII end of text
_IN_ID_MSG_ACK = const(6)  #ASCII ack
_IN_ID_RPC     = const(17) #ASCII device control 1
_IN_ID_SYS     = const(18) #ASCII device control 2
_IN_ID_SIGNAL  = const(19) #ASCII device control 3
_IN_ID_MSG_ERR = const(21) #ASCII nak

# _IN_IDS = [_IN_ID_START, _IN_ID_END, _IN_ID_MSG_ACK, _IN_ID_RPC, _IN_ID_SYS, _IN_ID_SIGNAL, _IN_ID_MSG_ERR]

_OUT_ID_START   = const(2)  #ASCII start of text
_OUT_ID_END     = const(3)  #ASCII end of text
_OUT_ID_MSG_ACK = const(6)  #ASCII ack
_OUT_ID_DATA    = const(17) #ASCII device control 1
_OUT_ID_SYS     = const(18) #ASCII device control 2
_OUT_ID_SIGNAL  = const(19) #ASCII device control 3
_OUT_ID_MSG_ERR = const(21) #ASCII nak

_SYS_CODE_STOP = const(0)
_SYS_CODE_READY = const(1)

# _CHUNK_LENGTH = const(80)

class IOHub:

    def __init__(self, device=None):
        self.running = False
        self.input_buffer = bytearray()
        self.input_checksum = None
        self.poll = uselect.poll()
        self.poll.register(usys.stdin)
        self.device = device
    
    def emit_msg(self, data):
        checksum = 0xFF
        for byte in data:
            checksum ^= byte
        data += bytes([checksum, _OUT_ID_END])
        usys.stdout.buffer.write(data)
    
    def emit_data(self, key, data):
        self.emit_msg(bytes([_OUT_ID_DATA]) + bytes(repr((key, data))))

    def emit_signal_code(self, code):
        self.emit_msg(bytes([_OUT_ID_SIGNAL, code]))
    
    def emit_sys_code(self, code):
        self.emit_msg(bytes([_OUT_ID_SYS, code]))
    
    def emit_ack(self, success):
        if success:
            usys.stdout.buffer.write(bytes([_OUT_ID_MSG_ACK, _OUT_ID_END]))
        else:
            usys.stdout.buffer.write(bytes([_OUT_ID_MSG_ERR, _OUT_ID_END]))
        

    def handle_input(self):
        in_id = self.input_buffer[0]

        if in_id == _IN_ID_MSG_ACK:
            return
        
        if in_id == _IN_ID_MSG_ERR:
            return
        
        checksum = self.input_buffer[-1]
        if checksum != self.input_checksum:
            self.emit_ack(False)
        self.emit_ack(True)

        msg = self.input_buffer
        del msg[0]
        del msg[-1]

        if in_id == _IN_ID_SYS:
            code = msg[0]
            if code == _SYS_CODE_STOP:
                self.running = False
                return
        
        if in_id == _IN_ID_RPC:
            try:
                struct = eval(msg)
            except SyntaxError:
                print("eval syntaxerror")
                print(msg)
            func = getattr(self.device, struct["func"])
            args = struct["args"]
            _result = func(*args)
            return
        if in_id == _IN_ID_SIGNAL:
            self.device.on_signal_received(msg)
            return
        
        print(self.input_buffer.decode())

    def update_input(self, byte):

        if byte == _IN_ID_END:
            self.handle_input()
            self.input_buffer = bytearray()
            self.input_checksum = 0xFF
            return
        self.input_checksum ^= byte
        self.input_buffer.append(byte)

    def run_loop(self, max_delta = 0.01):
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
            self.device.update(delta)