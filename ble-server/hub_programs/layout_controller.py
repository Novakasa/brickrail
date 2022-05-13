from uselect import poll
from usys import stdin

from pybricks.hubs import TechnicHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor, Motor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch

delta = 0.03

class Timer:

    timers = []

    def __init__(self):
        self.watch = StopWatch()
        self.watch.pause()
        self.time = None
        self.callback = None

        Timer.timers.append(self)
    
    def arm(self, time, callback):
        self.watch.reset()
        self.watch.resume()
        self.time = time
        self.callback = callback 
    
    def update(self):
        if self.time is None:
            return
        if self.watch.time()>self.time:
            self.watch.pause()
            self.watch.reset()
            self.callback()
            self.time = None
            self.callback = None

class Switch:
    def __init__(self, port, pulse_duration = 600):
        pb_port = [Port.A, Port.B, Port.C, Port.D][port]
        self.motor = Motor(pb_port)
        self.position = "unknown"
        self.port = port
        self.pulse_duration = pulse_duration
        self.switch_timer = Timer() 
        self.data_queue = []

    def queue_data(self, key, data):
        self.data_queue.append({"key": "device_data", "data": {"port": self.port, "key": key, "data": data}})
    
    def switch(self, position):
        assert position in ["left", "right"]
        if position == self.position:
            return
        sdir = -1
        if position == "right":
            sdir = 1
        print("starting motor with speed", 100*sdir)
        self.motor.dc(100*sdir)
        self.switch_timer.arm(self.pulse_duration, self.on_switch_timer)
        self.position = "switching_"+position
    
    def on_switch_timer(self):
        
        if self.position == "switching_left":
            self.position = "left"
        elif self.position == "switching_right":
            self.position = "right"
        else:
            print("Controller device", self.name, "got a problem!! self.position=",self.position)
        self.motor.stop()
        self.queue_data("position_changed", self.position)
    
    def update(self, delta):
        pass

class Controller:

    def __init__(self):
        self.hub = TechnicHub()
        self.devices = {}
        self.data_queue = []
    
    def add_switch(self, port):
        switch = Switch(port)
        self.attach_device(switch)

    def attached_ports(self):
        ports = []
        for dev in self.devices.values():
            ports.append(dev.port)
        return ports
    
    def attach_device(self, device):
        assert device.port not in self.attached_ports()

        self.devices[device.port] = device
        device.queue_data("attached_at_port", repr(device.port))
    
    def update(self, delta):
        for device in self.devices.values():
            device.update(delta)
            self.data_queue += device.data_queue
            device.data_queue = []
    
    def device_call(self, port, funcname, args):
        func = getattr(self.devices[port], funcname)
        func(*args)
    
    def queue_data(self, key, data):
        self.data_queue.append({"key": key, "data": data})

device = controller = Controller()
max_delta = 0.05
running = True

def send_data_queue(queue):
    if not queue:
        return
    msg = ""
    for obj in queue:
        msg += "data::"+repr(obj)+"$"
    print(msg)

def update_timers():
    for timer in Timer.timers:
        timer.update()

def input_handler(message):
    global running
    if message == "stop_program":
        running=False
    if message.find("::") > 0:
        lmsg = list(message)
        for _ in range(5):
            del lmsg[0]
        expr = "".join(lmsg)
        try:
            struct = eval(expr)
        except SyntaxError:
            print("[ble_hub] Syntaxerror when running eval()")
            print(expr)
        if message.find("rpc::")==0:
            func = getattr(device, struct["func"])
            args = struct["args"]
            _result = func(*args)
    else:
        print(message)


running = True
input_buffer = ""
p = poll()
p.register(stdin)

def update_input(char):
    global input_buffer
    if char == "$":
        input_handler(input_buffer)
        input_buffer = ""
    elif char == "#":
        print("msg_ack$")
    else:
        input_buffer += char

def update(delta):
    update_timers()
    device.update(delta)
    send_data_queue(device.data_queue)
    device.data_queue = []

def main_loop():
    loop_watch = StopWatch()
    loop_watch.resume()
    last_time = loop_watch.time()
    while running:
        if p.poll(int(1000*max_delta)):
            char = stdin.read(1)
            if char is not None:
                update_input(char)
        t = loop_watch.time()
        delta = (t-last_time)/1000
        last_time = t
        update(delta)

main_loop()