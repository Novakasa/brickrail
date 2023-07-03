from micropython import const

from uselect import poll
from usys import stdin

from pybricks.pupdevices import DCMotor
from pybricks.parameters import Port
from pybricks.tools import wait, StopWatch

from io_hub_unfrozen import IOHub

# version 0

_SWITCH_POS_LEFT  = const(0)
_SWITCH_POS_RIGHT = const(1)
_SWITCH_POS_NONE  = const(2)

_CROSSING_POS_DOWN  = const(2)
_CROSSING_POS_UP = const(1)

_SWITCH_COMMAND_SWITCH = const(0)
_CROSSING_COMMAND_SET_POS = const(8)

_DATA_SWITCH_CONFIRM  = const(0)

_STORAGE_PULSE_DC = const(0)
_STORAGE_PULSE_DURATION = const(1)
_STORAGE_PULSE_POLARITY = const(2)

def get_port(index):
    try: # Primehub
        return [Port.A, Port.B, Port.C, Port.D, Port.E, Port.F][index]
    except AttributeError:
        pass

    try: # Technichub
        return [Port.A, Port.B, Port.C, Port.D][index]
    except AttributeError:
        pass

    # Cityhub
    return [Port.A, Port.B][index]

class Crossing:
    def __init__(self, port):
        self. motor = DCMotor(get_port(port))
        self.position = _CROSSING_POS_UP
        self.port = port
        self.stopwatch = StopWatch()
    
    def get_storage_val(self, i):
        return io_hub.storage[8+self.port*16 + i]
    
    def set_pos(self, position):
        sdir = -1
        if position == _CROSSING_POS_UP:
            sdir = 1
        if self.get_storage_val(_STORAGE_PULSE_POLARITY) == 1:
            sdir *= -1
        self.motor.dc(self.get_storage_val(_STORAGE_PULSE_DC)*sdir)
        self.stopwatch.reset()
        self.stopwatch.resume()
        self.position = position
    
    def update(self, delta):
        if self.stopwatch.time() > self.get_storage_val(_STORAGE_PULSE_DURATION):
            self.motor.stop()
            self.stopwatch.pause()
    
    def execute(self, data):
        if data[0] == _CROSSING_COMMAND_SET_POS:
            self.set_pos(data[1])

class Switch:
    def __init__(self, port, pulse_duration = 600):
        self.motor = DCMotor(get_port(port))
        self.position = _SWITCH_POS_NONE
        self.port = port
        self.pulse_duration = pulse_duration
        self.switch_stopwatch = StopWatch()
        self.switching = False
    
    def get_storage_val(self, i):
        return io_hub.storage[8+self.port*16 + i]
    
    def switch(self, position):
        assert not self.switching
        sdir = -1
        if position == _SWITCH_POS_RIGHT:
            sdir = 1
        self.motor.dc(self.get_storage_val(_STORAGE_PULSE_DC)*sdir)
        self.switch_stopwatch.reset()
        self.switch_stopwatch.resume()
        self.switching = True
        self.position = position
    
    def update(self, delta):
        if self.switching and self.switch_stopwatch.time() > self.get_storage_val(_STORAGE_PULSE_DURATION):
            self.motor.stop()
            self.switch_stopwatch.pause()
            self.switching = False
            io_hub.emit_data(bytes((_DATA_SWITCH_CONFIRM, self.port, self.position)))
    
    def execute(self, data):
        if data[0] == _SWITCH_COMMAND_SWITCH:
            self.switch(data[1])

class Controller:

    def __init__(self):
        self.devices = {}
    
    def assign_switch(self, data):
        port = data[0]
        switch = Switch(port)
        self.devices[port] = switch
    
    def assign_crossing(self, data):
        port = data[0]
        crossing = Crossing(port)
        self.devices[port] = crossing
        
    def update(self, delta):
        for device in self.devices.values():
            device.update(delta)
    
    def device_execute(self, data):
        if not data[0] in self.devices:
            if data[1] < 8:
                self.assign_switch([data[0]])
            else:
                self.assign_crossing([data[0]])
        self.devices[data[0]].execute(data[1:])

controller = Controller()
io_hub = IOHub(controller)
io_hub.run_loop(0.03)