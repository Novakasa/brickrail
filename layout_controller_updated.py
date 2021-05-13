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
    def __init__(self, name, port, pulse_duration = 300):
        self.name = name
        self.motor = Motor(port)
        self.position = "unknown"
        self.port = port
        self.pulse_duration = pulse_duration
        self.switch_timer = Timer() 
        self.data_queue = []

    def queue_data(self, key, data):
        self.data_queue.append((key, data))
    
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

    def attached_ports(self):
        ports = []
        for dev in self.devices.values():
            ports.append(dev.port)
        return ports
    
    def attach_device(self, device):
        print(self.attached_ports(), device.port)
        assert device.port not in self.attached_ports()
        # assert int(device.port)<=3

        self.devices[device.name] = device
    
    def update(self, delta):
        for device in self.devices.values():
            device.update(delta)
            self.data_queue += device.data_queue
            device.data_queue = []
    
    def queue_data(self, key, data):
        self.data_queue.append((key, data))

device = controller = Controller()
running = True

def send_data_queue(queue):
    if not queue:
        return
    msg = ""
    for key, data in queue:
        obj = {"key": key, "data": data}
        msg += "data::"+repr(obj)+"$"
    print(msg)

def update_timers():
    for timer in Timer.timers:
        timer.update()

def input_handler(message):
    global running
    if message == "stop_program":
        running=False
    if message.find("cmd::") == 0:
        lmsg = list(message)
        for _ in range(5):
            del lmsg[0]
        code = "".join(lmsg)
        try:
            eval(code)
        except SyntaxError as e:
            print(e)
    else:
        print(message)


input_buffer = ""

p = poll()
p.register(stdin)

def update_input(char):
    global input_buffer
    if char == "$":
        input_handler(input_buffer)
        input_buffer = ""
    else:
        input_buffer += char

def update():
    update_timers()
    device.update(delta)
    send_data_queue(device.data_queue)
    device.data_queue = []

def main_loop():
    while running:
        if p.poll(int(1000*delta)):
            char = stdin.read(1)
            if char is not None:
                update_input(char)
        update()

main_loop()