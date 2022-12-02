from micropython import const

from uselect import poll
from usys import stdin

from pybricks.hubs import TechnicHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor, Motor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch

from io_hub import IOHub

_SWITCH_POS_RIGHT = const(0)
_SWITCH_POS_LEFT  = const(1)

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

controller = Controller()
io_hub = IOHub(controller)
io_hub.run_loop(0.03)