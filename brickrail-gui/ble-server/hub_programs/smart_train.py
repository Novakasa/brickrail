from uselect import poll
from usys import stdin
from micropython import const

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

_LEG_TYPE_TRAVEL = const(0)
_LEG_TYPE_FLIP   = const(1)
_LEG_TYPE_START  = const(2)

_BEHAVIOR_IGNORE      = const(0)
_BEHAVIOR_SLOW        = const(1)
_BEHAVIOR_CRUISE      = const(2)
_BEHAVIOR_STOP        = const(3)
_BEHAVIOR_FLIP_CRUISE = const(4)
_BEHAVIOR_FLIP_SLOW   = const(5)

_INTENTION_STOP = const(0)
_INTENTION_PASS = const(1)

_MOTOR_ACC          = const(40)
_MOTOR_DEC          = const(90)
_MOTOR_CRUISE_SPEED = const(75)
_MOTOR_SLOW_SPEED   = const(40)

_DATA_STATE_CHANGED  = const(0)
_DATA_ROUTE_COMPLETE = const(1)
_DATA_LEG_ADVANCE  = const(2)
_DATA_SENSOR_ADVANCE    = const(3)

_STATE_STOPPED = const(0)
_STATE_SLOW    = const(1)
_STATE_CRUISE  = const(2)

class TrainSensor:

    def __init__(self, marker_exit_callback):
        self.sensor = ColorDistanceSensor(Port.B)
        self.marker_exit_callback = marker_exit_callback

        self.marker_samples = 0
        self.marker_hue = 0
        
        self.last_color = None
    
    def update(self, delta):
        self.last_color = self.sensor.hsv()
        h, s, v = self.last_color.h, self.last_color.s, self.last_color.v
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
                for last_color, chue in enumerate(COLOR_HUES):
                    err = abs(chue-self.marker_hue)
                    if found_color is None or err<colorerr:
                        found_color = last_color
                        colorerr = err
                self.marker_exit_callback(found_color)
            self.marker_hue = 0
            self.marker_samples = 0

class TrainMotor:

    def __init__(self):
        self.speed = 0
        self.target_speed = 0
        self.motor = DCMotor(Port.A)
        self.direction = 1
    
    def flip_direction(self):
        self.direction*=-1
    
    def set_target(self, speed):
        self.target_speed = speed
    
    def set_speed(self, speed):
        self.target_speed = speed
        self.speed = speed
    
    def update(self, delta):

        if self.speed*self.direction>=0:
            if abs(self.speed)<self.target_speed:
                self.speed = min(abs(self.speed)+delta*_MOTOR_ACC, self.target_speed)*self.direction
            if abs(self.speed)>self.target_speed:
                self.speed = max(abs(self.speed)-delta*_MOTOR_DEC, self.target_speed)*self.direction
        else:
            self.speed += delta*_MOTOR_DEC*self.direction
        
        self.motor.dc(self.speed)

class Route:
    def __init__(self):
        self.legs = [RouteLeg(b"\x02")]
        assert self.legs[0].type == _LEG_TYPE_START, self.legs[0].type
        self.index = 0

    def get_current_leg(self):
        return self.legs[self.index]
    
    def get_next_leg(self):
        try:
            return self.legs[self.index+1]
        except IndexError:
            return None
    
    def set_leg(self, data):
        leg_index = data[0]
        if leg_index == len(self.legs):
            self.legs.append(None)    
        self.legs[leg_index] = RouteLeg(data[1:])
    
    def is_complete(self):
        return self.index >= len(self.legs)

    def advance_leg(self):
        self.index += 1
        if self.is_complete():
            io_hub.emit_data(bytes((_DATA_ROUTE_COMPLETE, self.index)))
        io_hub.emit_data(bytes((_DATA_LEG_ADVANCE, self.index)))
    
    def advance(self):
        self.advance_leg()
        if self.get_current_leg().type == _LEG_TYPE_FLIP:
            if self.get_current_leg().intention == _INTENTION_PASS:
                return _BEHAVIOR_FLIP_CRUISE
            return _BEHAVIOR_FLIP_SLOW
        return _BEHAVIOR_CRUISE
    
    def advance_sensor(self, color):
        next_color = self.get_current_leg().get_next_color()
        if next_color != color:
            print("Marker", color, "!=", next_color)
            return
        
        behavior = self.get_next_sensor_behavior()

        current_leg = self.get_current_leg()
        current_leg.advance_sensor()
        if current_leg.is_complete():
            if current_leg.intention == _INTENTION_PASS:
                behavior = self.advance()
            elif self.index == len(self.legs)-1:
                io_hub.emit_data(bytes((_DATA_ROUTE_COMPLETE, self.index)))
        
        return behavior
        
    def get_next_sensor_behavior(self):

        current_leg = self.get_current_leg()
        next_leg = self.get_next_leg()

        key = current_leg.get_next_key()
        if key == _SENSOR_KEY_NONE:
            return _BEHAVIOR_IGNORE

        please_stop = False
        if next_leg is None:
            please_stop = True
        elif current_leg.intention == _INTENTION_STOP or next_leg.type == _LEG_TYPE_FLIP:
            please_stop = True

        if not please_stop:
            return _BEHAVIOR_IGNORE

        # stop the train
        if key == _SENSOR_KEY_ENTER:
            return _BEHAVIOR_SLOW
        if key == _SENSOR_KEY_IN:
            return _BEHAVIOR_STOP

class RouteLeg:
    def __init__(self, data):
        self.data = data[:-1]
        self.intention = data[-1] >> 4
        self.type = data[-1] & 0x0F
        self.index = 0
    
    def is_complete(self):
        return self.index >= len(self.data)
    
    def advance_sensor(self):
        self.index += 1
        io_hub.emit_data(bytes((_DATA_SENSOR_ADVANCE, self.index)))

    def get_next_color(self):
        return self.data[self.index] & 0x0F
    
    def get_next_key(self):
        return self.data[self.index] >> 4

class Train:

    def __init__(self):
        self.motor = TrainMotor()
        self.sensor = TrainSensor(self.on_marker_passed)

        self.route : Route = None
        self.current_leg : RouteLeg = None
        
        self.state = None
        self.set_state(_STATE_STOPPED)
    
    def on_marker_passed(self, color):
        behavior = self.route.advance_sensor(color)
        self.execute_behavior(behavior)
        if self.route.is_complete():
            self.route = None
    
    def advance_route(self):
        behavior = self.route.advance()
        self.execute_behavior(behavior)
        if self.route.is_complete():
            self.route = None

    def execute_behavior(self, behavior):
        if behavior == _BEHAVIOR_IGNORE:
            return
        if behavior == _BEHAVIOR_CRUISE:
            self.cruise()
        if behavior == _BEHAVIOR_SLOW:
            self.slow()
        if behavior == _BEHAVIOR_STOP:
            self.stop()
        if behavior == _BEHAVIOR_FLIP_CRUISE:
            self.flip_heading()
            self.cruise()
        if behavior == _BEHAVIOR_FLIP_SLOW:
            self.flip_heading()
            self.slow()
    
    def new_route(self):
        self.route = Route()

    def set_route_leg(self, data):
        self.route.set_leg(data)
    
    def set_state(self, state):
        self.state = state
    
    def slow(self):
        self.motor.set_target(_MOTOR_SLOW_SPEED)
        self.set_state(_STATE_SLOW)
    
    def stop(self):
        self.motor.set_speed(0)
        self.set_state(_STATE_STOPPED)
    
    def cruise(self):
        self.motor.set_target(_MOTOR_CRUISE_SPEED)
        self.set_state(_STATE_CRUISE)

    def flip_heading(self):
        self.motor.flip_direction()

    def update(self, delta):
        if self.state in [_STATE_CRUISE, _STATE_SLOW]:
            self.sensor.update(delta)

        self.motor.update(delta)

train = Train()
io_hub = IOHub(train)

io_hub.run_loop()