from micropython import const

from uselect import poll
from usys import stdin

from pybricks.pupdevices import DCMotor, Motor
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

_DEVICE_SWITCH = const(0)
_DEVICE_CROSSING = const(1)

def get_device_from_command(command):
    if command < _CROSSING_COMMAND_SET_POS:
        return _DEVICE_SWITCH
    return _DEVICE_CROSSING

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
        try:
            self.motor = DCMotor(get_port(port))
        except OSError:
            self.motor = Motor(get_port(port))
        self.position = _CROSSING_POS_UP
        self.port = port
        self.stopwatch = StopWatch()
        self.device_type = _DEVICE_CROSSING
    
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
        try:
            self.motor = DCMotor(get_port(port))
        except OSError:
            self.motor = Motor(get_port(port))
        self.position = _SWITCH_POS_NONE
        self.port = port
        self.pulse_duration = pulse_duration
        self.switch_stopwatch = StopWatch()
        self.switching = False
        self.device_type = _DEVICE_SWITCH
    
    def get_storage_val(self, i):
        return io_hub.storage[8+self.port*16 + i]
    
    def switch(self, position):
        sdir = -1
        if position == _SWITCH_POS_RIGHT:
            sdir = 1
        if self.get_storage_val(_STORAGE_PULSE_POLARITY) == 1:
            sdir *= -1
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
    
    def ensure_device(self, port, device_type):
        if port in self.devices and self.devices[port].device_type == device_type:
            return self.devices[port]
        if device_type == _DEVICE_SWITCH:
            new_device = Switch(port)
        else:
            new_device = Crossing(port)
        self.devices[port] = new_device
        return new_device
        
    def update(self, delta):
        for device in self.devices.values():
            device.update(delta)
    
    def device_execute(self, data):
        port = data[0]
        device_type = get_device_from_command(data[1])
        self.ensure_device(port, device_type).execute(data[1:])

controller = Controller()
io_hub = IOHub(controller)
io_hub.run_loop(0.03)