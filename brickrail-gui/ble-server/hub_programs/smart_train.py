from uselect import poll
from usys import stdin
from micropython import const

from pybricks.hubs import CityHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch

from io_hub import IOHub

_COLOR_YELLOW = const(0)
_COLOR_BLUE   = const(1)
_COLOR_GREEN  = const(2)
_COLOR_RED    = const(3)
COLOR_HUES = (31, 199, 113, 339)

_SENSOR_KEY_NONE  = const(0)
_SENSOR_KEY_ENTER = const(1)
_SENSOR_KEY_IN    = const(2)

_BEHAVIOR_IGNORE = const(0)
_BEHAVIOR_SLOW   = const(1)
_BEHAVIOR_CRUISE = const(2)
_BEHAVIOR_STOP   = const(3)
_BEHAVIOR_FLIP   = const(4)

_MOTOR_ACC          = const(40)
_MOTOR_DEC          = const(90)
_MOTOR_CRUISE_SPEED = const(75)
_MOTOR_SLOW_SPEED   = const(40)

_DATA_STATE_CHANGED = const(0)

_STATE_STOPPED = const(0)
_STATE_SLOW    = const(1)
_STATE_CRUISE  = const(2)

class TrainSensor:

    def __init__(self, marker_exit_callback):
        self.sensor = ColorDistanceSensor(Port.B)
        self.marker_exit_callback = marker_exit_callback

        self.marker_samples = 0
        self.marker_hue = 0
    
    def update(self, delta):
        color = self.sensor.hsv()
        h, s, v = color.h, color.s, color.v
        h = (h-20)%360
        if s*v>3500:
            self.marker_samples += 1
            self.marker_hue += h
            return
        if self.marker_samples>0:
            if self.marker_samples>2:
                self.marker_hue//=self.marker_samples
                found_color = None
                colorerr = 361
                for color, chue in enumerate(COLOR_HUES):
                    err = abs(chue-self.marker_hue)
                    if found_color is None or err<colorerr:
                        found_color = color
                        colorerr = err
                self.marker_exit_callback(found_color)
            self.marker_hue = 0
            self.marker_samples = 0

class TrainMotor:

    def __init__(self):
        self.speed = 0
        self.target_speed = 0
        self.motor = DCMotor(Port.A)
        self.braking = False
        self.direction = 1
    
    def flip_direction(self):
        self.direction*=-1
    
    def set_target(self, speed):
        self.target_speed = speed
        self.braking = False
    
    def set_speed(self, speed):
        self.target_speed = speed
        self.speed = speed
        self.braking = False
    
    def brake(self):
        self.target_speed = 0
        self.speed = 0
        self.braking = True
    
    def update(self, delta):

        if self.speed*self.direction>=0:
            if abs(self.speed)<self.target_speed:
                self.speed = min(abs(self.speed)+delta*_MOTOR_ACC, self.target_speed)*self.direction
            if abs(self.speed)>self.target_speed:
                self.speed = max(abs(self.speed)-delta*_MOTOR_DEC, self.target_speed)*self.direction
        else:
            self.speed += delta*_MOTOR_DEC*self.direction
        
        self.motor.dc(self.speed)

        if self.braking:
            self.motor.brake()
            return

def get_key_behavior(key, passing):
    if passing:
        return _BEHAVIOR_IGNORE
    if key == _SENSOR_KEY_NONE:
        return _BEHAVIOR_IGNORE
    if key == _SENSOR_KEY_ENTER:
        return _BEHAVIOR_SLOW
    if key == _SENSOR_KEY_IN:
        return _BEHAVIOR_STOP

    raise Exception("Invalid sensor key: "+str(key))

class RouteLeg:
    def __init__(self, data):
        self.sensor_colors = []
        self.sensor_keys = []
        for byte in data[:-1]:
            self.sensor_keys.append(byte >> 4)
            self.sensor_colors.append(byte & 0x0F)
        self.passing = data[-1] & 0b10000000 == 0b10000000
        self.current_index = data[-1] & 0x01111111
    
    def advance(self):
        self.current_index += 1
    
    def get_next_color(self):
        try:
            return self.sensor_colors[self.current_index+1]
        except IndexError:
            return None
    
    def get_next_behavior(self):
        try:
            key = self.sensor_keys[self.current_index+1]
        except IndexError:
            return None
        return get_key_behavior(key, self.passing)
    
    def get_current_behavior(self):
        return get_key_behavior(self.sensor_keys[self.current_index], self.passing)

class Train:

    def __init__(self):
        self.hub = CityHub()
        self.motor = TrainMotor()
        self.sensor = TrainSensor(self.on_marker_exit)

        self.hbuf = bytearray(1000)
        self.sbuf = bytearray(1000)
        self.vbuf = bytearray(1000)
        self.buf_index = 0

        self.leg = None
        self.next_leg = None
        
        self.state = None
        self.set_state(_STATE_STOPPED)
    
    def on_marker_exit(self, color):
        next_color = self.leg.get_next_color()
        if color != next_color:
            print (str(color)+" != " + str(next_color))
            return
        print("advancing")
        behavior = self.leg.get_next_behavior()
        self.leg.advance()
        if behavior == _BEHAVIOR_IGNORE:
            return
        if behavior == _BEHAVIOR_CRUISE:
            self.start()
        if behavior == _BEHAVIOR_SLOW:
            self.slow()
        if behavior == _BEHAVIOR_STOP:
            self.stop()
        if behavior == _BEHAVIOR_FLIP:
            self.flip_heading()
    
    def set_leg(self, data):
        self.leg = RouteLeg(data)
    
    def set_next_leg(self, data):
        self.next_leg = RouteLeg(data)
    
    def set_state(self, state):
        self.state = state
        print("new state:", state)
    
    def slow(self):
        self.motor.set_target(_MOTOR_SLOW_SPEED)
        self.set_state(_STATE_SLOW)
    
    def stop(self):
        # print("stopping...")
        self.motor.brake()
        self.set_state(_STATE_STOPPED)
    
    def start(self):
        self.motor.set_target(_MOTOR_CRUISE_SPEED)
        self.set_state(_STATE_CRUISE)

    def flip_heading(self):
        self.motor.flip_direction()

    def update(self, delta):
        if self.state in [_STATE_CRUISE, _STATE_SLOW]:
            self.sensor.update(delta)

        self.buf_index+=1
        if self.buf_index>=len(self.hbuf):
            self.buf_index=0
        color = self.sensor.sensor.hsv()
        self.hbuf[self.buf_index] = int(0.5*color.h)
        self.sbuf[self.buf_index] = color.s
        self.vbuf[self.buf_index] = color.v
        self.motor.update(delta)

train = Train()
io_hub = IOHub(train)

io_hub.run_loop()