from micropython import const

from uselect import poll
from usys import stdin

from pybricks.hubs import TechnicHub
from pybricks.pupdevices import DCMotor, Motor
from pybricks.parameters import Port
from pybricks.tools import wait, StopWatch

from io_hub import IOHub

_SWITCH_POS_LEFT  = const(0)
_SWITCH_POS_RIGHT = const(1)
_SWITCH_POS_NONE  = const(2)

_SWITCH_COMMAND_SWITCH = const(0)

_DATA_SWITCH_CONFIRM  = const(0)

class Switch:
    def __init__(self, port, pulse_duration = 600):
        pb_port = [Port.A, Port.B, Port.C, Port.D][port]
        self.motor = DCMotor(pb_port)
        self.position = _SWITCH_POS_NONE
        self.port = port
        self.pulse_duration = pulse_duration
        self.switch_stopwatch = StopWatch()
        self.switching = False
    
    def switch(self, position):
        assert not self.switching
        sdir = -1
        if position == _SWITCH_POS_RIGHT:
            sdir = 1
        print("starting motor with speed", 100*sdir)
        self.motor.dc(100*sdir)
        self.switch_stopwatch.reset()
        self.switch_stopwatch.resume()
        self.switching = True
        self.position = position
    
    def update(self, delta):
        if self.switching and self.switch_stopwatch.time() > self.pulse_duration:
            self.motor.stop()
            self.switch_stopwatch.pause()
            self.switching = False
            io_hub.emit_data(bytes((_DATA_SWITCH_CONFIRM, self.port, self.position)))
    
    def execute(self, data):
        if data[0] == _SWITCH_COMMAND_SWITCH:
            self.switch(data[1])

class Controller:

    def __init__(self):
        self.hub = TechnicHub()
        self.devices = {}
    
    def assign_switch(self, data):
        port = data[0]
        switch = Switch(port)
        self.devices[port] = switch
        
    def update(self, delta):
        for device in self.devices.values():
            device.update(delta)
    
    def device_execute(self, data):
        if not data[0] in self.devices:
            self.assign_switch([data[0]])
        self.devices[data[0]].execute(data[1:])

controller = Controller()
io_hub = IOHub(controller)
io_hub.run_loop(0.03)