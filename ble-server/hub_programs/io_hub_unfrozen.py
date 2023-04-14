import micropython
from micropython import const
from usys import stdout, stdin
import uselect
import urandom

from pybricks.tools import wait, StopWatch

# disable keyboard interrupt character
micropython.kbd_intr(-1)

# _IN_ID_START   = const(2)  #ASCII start of text
_IN_ID_END     = const(10) #ASCII line feed
_IN_ID_MSG_ACK = const(6)  #ASCII ack
_IN_ID_RPC     = const(17) #ASCII device control 1
_IN_ID_SYS     = const(18) #ASCII device control 2
# _IN_ID_SIGNAL  = const(19) #ASCII device control 3
_IN_ID_MSG_ERR = const(21) #ASCII nak

# _IN_IDS = [_IN_ID_START, _IN_ID_END, _IN_ID_MSG_ACK, _IN_ID_RPC, _IN_ID_SYS, _IN_ID_SIGNAL, _IN_ID_MSG_ERR]

_OUT_ID_START   = const(2)  #ASCII start of text
_OUT_ID_END     = const(10) #ASCII line feed
_OUT_ID_MSG_ACK = const(6)  #ASCII ack
_OUT_ID_DATA    = const(17) #ASCII device control 1
_OUT_ID_SYS     = const(18) #ASCII device control 2
# _OUT_ID_ALIVE   = const(19) #ASCII device control 3
_OUT_ID_MSG_ERR = const(21) #ASCII nak

_SYS_CODE_STOP = const(0)
_SYS_CODE_READY = const(1)
_SYS_CODE_ALIVE = const(2)

# _CHUNK_LENGTH = const(80)

def xor_checksum(data):
    checksum = 0xFF
    for byte in data:
        checksum ^= byte
    return checksum

def mod_checksum(data):
    checksum = 0x00
    for byte in data:
        checksum += byte
    return checksum%256

class IOHub:

    def __init__(self, device=None):
        self.running = False
        self.input_buffer = bytearray()
        self.msg_len = None
        self.poll = uselect.poll()
        self.poll.register(stdin)
        self.device = device
        self.device_attrs = {}
        self.last_output = None
        self.output_queue = []

        for attr in dir(device):
            if attr[0] == "_":
                continue
            encoded = bytes(attr, "ascii")
            attr_hash1 = xor_checksum(encoded)
            attr_hash2 = mod_checksum(encoded)
            attr_hash = bytes([attr_hash1,attr_hash2])
            assert not attr_hash in self.device_attrs, "hash not unique"
            self.device_attrs[attr_hash] = attr
    
    def emit_msg(self, data):
        data = bytes([len(data)+1]) + data + bytes([xor_checksum(data), _OUT_ID_END])

        if self.last_output is not None:
            self.output_queue.append(data)
            return
        self.last_output = data
        self.output_watch.reset()

        # if urandom.randint(0, 10)>17: # randomly corrupt data
            # data = bytearray(data)
            # mod_idx = urandom.randint(2, len(data)-2)
            # data[mod_idx] = b"X"[0]
            # data = data[:mod_idx-1] + data[mod_idx:]
            # data = data[:mod_idx] + b"X" + data[mod_idx:]

        stdout.buffer.write(data)
    
    def emit_data(self, data):
        self.emit_msg(bytes([_OUT_ID_DATA]) + data)
    
    def emit_sys_code(self, code):
        self.emit_msg(bytes([_OUT_ID_SYS, code]))
    
    def emit_ack(self, success):
        if success:
            stdout.buffer.write(bytes([1, _OUT_ID_MSG_ACK, _OUT_ID_END]))
        else:
            stdout.buffer.write(bytes([1, _OUT_ID_MSG_ERR, _OUT_ID_END]))
    
    def retry_last_output(self):
        data = self.last_output
        stdout.buffer.write(data)
        self.output_watch.reset()

    def handle_input(self):
        in_id = self.input_buffer[0]

        if in_id == _IN_ID_MSG_ACK:
            # release memory of last send, allow next data to be sent
            self.last_output = None
            if self.output_queue:
                data = self.output_queue.pop(0)
                stdout.buffer.write(data)
                self.last_output = data
            return
        
        if in_id == _IN_ID_MSG_ERR and self.last_output is not None:
            # retry last send
            self.retry_last_output()
            return
        
        checksum = self.input_buffer[-1]
        input_checksum = xor_checksum(self.input_buffer[:-1])
        if checksum != input_checksum:
            print(checksum, "!=", input_checksum)
            self.emit_ack(False)
            return
        self.emit_ack(True)

        msg = self.input_buffer[1:-1]

        if in_id == _IN_ID_SYS:
            code = msg[0]
            if code == _SYS_CODE_STOP:
                self.running = False
            return
        
        if in_id == _IN_ID_RPC:
            func_hash = bytes(msg[0:2])
            arg_bytes = msg[2:]
            func = getattr(self.device, self.device_attrs[func_hash])
            if len(arg_bytes)>1:
                _result = func(arg_bytes)
            elif len(arg_bytes)==1:
                _result = func(arg_bytes[0])
            else:
                _result = func()
            return

        assert(False)

    def update_input(self, byte):
        if self.msg_len is None:
            self.msg_len = byte
            return
        if len(self.input_buffer) >= self.msg_len and byte == _IN_ID_END:
            if len(self.input_buffer) > self.msg_len:
                self.emit_ack(False)
            else:
                self.handle_input()
            self.input_buffer = bytearray()
            self.msg_len = None
            return
        self.input_buffer.append(byte)

    def run_loop(self, max_delta = 0.01):
        loop_watch = StopWatch()
        loop_watch.resume()
        self.input_watch = StopWatch()
        self.input_watch.resume()
        self.output_watch = StopWatch()
        self.output_watch.resume()
        self.alive_watch = StopWatch()
        self.alive_watch.resume()
        last_time = loop_watch.time()
        self.running = True
        self.emit_sys_code(_SYS_CODE_READY)
        alive_data = bytes([_OUT_ID_SYS, _SYS_CODE_ALIVE])

        while self.running:
            if self.poll.poll(int(1000*max_delta)):
                byte = stdin.buffer.read(1)[0]
                self.update_input(byte)
                self.input_watch.reset()
            if self.msg_len is not None and self.input_watch.time() > 200:
                self.emit_ack(False)
                self.input_buffer = bytearray()
                self.msg_len = None
            if self.last_output is not None and self.output_watch.time() > 500:
                self.retry_last_output()
                if self.last_output[1:3] == alive_data:
                    self.running = False
            if self.alive_watch.time() > 5000:
                self.emit_sys_code(_SYS_CODE_ALIVE)
                self.alive_watch.reset()
            t = loop_watch.time()
            delta = (t-last_time)/1000
            last_time = t
            self.device.update(delta)