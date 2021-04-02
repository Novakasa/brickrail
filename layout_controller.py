from pybricks.hubs import TechnicHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor, Motor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch
from pybricks.experimental import getchar

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

    
    def send_data(self, key, data):
        obj = {"device": self.name, "key": key, "data": data}
        send_data("device_data", obj)
    
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
        self.send_data("position_changed", self.position)
    
    def update(self, delta):
        pass

class Controller:

    def __init__(self):
        self.hub = TechnicHub()
        self.devices = {}

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

device = controller = Controller()

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
    # print("interpreting message:", message)
    if message.find("cmd::") == 0:
        lmsg = list(message)
        for _ in range(5):
            del lmsg[0]
        code = "".join(lmsg)
        # print("evaluating:", code)
        try:
            eval(code)
        except SyntaxError as e:
            print(e)
        # send_data("ran_command", code)
    else:
        print(message)


input_buffer = ""

def update_input():
    global input_buffer
    char = getchar()
    while char is not None:
        char = chr(char)
        if char == "$":
            input_handler(input_buffer)
            input_buffer = ""
        else:
            input_buffer += char
        char = getchar()

def update():
    update_timers()
    update_input()
    device.update(delta)
    send_data_queue(device.data_queue)
    device.data_queue = []

def main_loop():
    while True:
        wait(int(delta*1000))
        update()
        update_input()

main_loop()