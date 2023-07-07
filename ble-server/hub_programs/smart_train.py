from micropython import const
from ustruct import pack, pack_into

from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port

from io_hub_unfrozen import IOHub, VERSION

# version 0

_COLOR_YELLOW = const(0)
_COLOR_BLUE   = const(1)
_COLOR_GREEN  = const(2)
_COLOR_RED    = const(3)
_COLOR_NONE   = const(15)
COLOR_HUES = (51, 219, 133, 359)

_SENSOR_KEY_NONE  = const(0)
_SENSOR_KEY_ENTER = const(1)
_SENSOR_KEY_IN    = const(2)

_SENSOR_SPEED_FAST = const(1)
_SENSOR_SPEED_SLOW = const(2)
_SENSOR_SPEED_CRUISE = const(3)

_LEG_TYPE_TRAVEL = const(0)
_LEG_TYPE_FLIP   = const(1)
_LEG_TYPE_START  = const(2)

_BEHAVIOR_FLAG_STOP  = const(32)
_BEHAVIOR_FLAG_SPEED = const(64)
_BEHAVIOR_FLAG_FLIP  = const(128)

_INTENTION_STOP = const(0)
_INTENTION_PASS = const(1)

_DATA_ROUTE_COMPLETE    = const(1)
_DATA_LEG_ADVANCE       = const(2)
_DATA_SENSOR_ADVANCE    = const(3)
_DATA_UNEXPECTED_MARKER = const(4)

_CONFIG_CHROMA_THRESHOLD   = const(0)
_CONFIG_MOTOR_ACC          = const(1)
_CONFIG_MOTOR_DEC          = const(2)
_CONFIG_MOTOR_FAST_SPEED   = const(3)
_CONFIG_MOTOR_SLOW_SPEED   = const(4)
_CONFIG_MOTOR_CRUISE_SPEED = const(5)
_CONFIG_MOTOR_INVERTED     = const(6)

_DUMP_TYPE_COLORS = const(1)


class TrainSensor:

    def __init__(self, marker_exit_callback):
        self.sensor = ColorDistanceSensor(Port.B)
        self.marker_exit_callback = marker_exit_callback

        self.last_marker_color = None
        self.marker_samples = 0
        
        self.last_hsv = None
        self.valid_colors = []
        self.initial_hue = 0
        self.initial_chroma = 0

        self.color_buf = bytearray(1002)
        self.buf_index = 0
    
    def get_marker_color(self):
        h, s, v = self.last_hsv.h, self.last_hsv.s, self.last_hsv.v
        if s*v<io_hub.storage[_CONFIG_CHROMA_THRESHOLD]:
            return None
        colorerr = 181
        found_color = None
        for last_color, chue in enumerate(COLOR_HUES):
            err = abs(((chue - h + 180) % 360) - 180)
            if found_color is None or err<colorerr:
                found_color = last_color
                colorerr = err
        if found_color in self.valid_colors:
            if self.last_marker_color is None:
                self.initial_hue = h
                self.initial_chroma = s*v
            return found_color
        return None
    
    def update(self, delta):

        self.last_hsv = self.sensor.hsv()

        pack_into(">HBB", self.color_buf, self.buf_index, self.last_hsv.h, self.last_hsv.s, self.last_hsv.v)
        self.buf_index = (self.buf_index + 4) % 1000

        marker_color = self.get_marker_color()
        if self.last_marker_color is not None:
            if marker_color is None:
                self.marker_exit_callback(self.last_marker_color)
                self.marker_samples = 0
            else:
                self.marker_samples += 1
                if marker_color != self.last_marker_color:
                    print("marker color inconsistent:", marker_color, self.last_marker_color)
                

        self.last_marker_color = marker_color

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
                self.speed = min(abs(self.speed)+delta*io_hub.storage[_CONFIG_MOTOR_ACC], self.target_speed)*self.direction
            if abs(self.speed)>self.target_speed:
                self.speed = max(abs(self.speed)-delta*io_hub.storage[_CONFIG_MOTOR_DEC], self.target_speed)*self.direction
        else:
            self.speed += delta*io_hub.storage[_CONFIG_MOTOR_DEC]*self.direction
        
        polarity = (io_hub.storage[_CONFIG_MOTOR_INVERTED]*-2)+1
        self.motor.dc(self.speed*polarity)

class Route:
    def __init__(self):
        self.legs = [RouteLeg(b"\x02")]
        # assert self.legs[0].type == _LEG_TYPE_START, self.legs[0].type
        self.index = 0
        self.last_key = _SENSOR_KEY_NONE
        self.last_speed = _SENSOR_SPEED_CRUISE

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
        leg = RouteLeg(data[1:])
        self.legs[leg_index] = leg

        if leg_index == 0:
            assert leg.type == _LEG_TYPE_START
            self.last_key = leg.get_next_key()
            self.last_speed = leg.get_next_speed()
            leg.index += 1

    def advance_leg(self):
        self.index += 1
        assert self.index < len(self.legs)
        io_hub.emit_data(bytes((_DATA_LEG_ADVANCE, self.index)))
    
    def advance(self):
        self.advance_leg()
        self.last_key = _SENSOR_KEY_NONE
        if self.get_current_leg().type == _LEG_TYPE_FLIP:
            self.last_speed = _SENSOR_SPEED_CRUISE
            if self.get_current_leg().intention == _INTENTION_PASS:
                return _BEHAVIOR_FLAG_FLIP ^ _BEHAVIOR_FLAG_SPEED ^ self.last_speed
            return _BEHAVIOR_FLAG_FLIP ^ _BEHAVIOR_FLAG_SPEED ^ _SENSOR_SPEED_SLOW
        return _BEHAVIOR_FLAG_SPEED ^ self.last_speed
    
    def advance_sensor(self, color):
        next_color = self.get_current_leg().get_next_color()
        if next_color != color and next_color != _COLOR_NONE:
            # print(next_color, color, train.sensor.initial_chroma, train.sensor.initial_hue, train.sensor.marker_samples)
            data = pack(">BBBHHH", _DATA_UNEXPECTED_MARKER, next_color, color, train.sensor.initial_chroma, train.sensor.initial_hue, train.sensor.marker_samples)
            io_hub.emit_data(bytes(data))
            return 0
        self.last_key = self.get_current_leg().get_next_key()
        self.last_speed = self.get_current_leg().get_next_speed()

        behavior = self.get_last_behavior()

        current_leg = self.get_current_leg()
        current_leg.advance_sensor()
        if current_leg.is_complete():
            if current_leg.intention == _INTENTION_PASS:
                behavior = self.advance()
            elif self.get_next_leg() is None:
                io_hub.emit_data(bytes((_DATA_ROUTE_COMPLETE, self.index)))
        
        return behavior

    def get_next_type(self):
        next_leg = self.get_next_leg()
        if next_leg is not None:
            return next_leg.type
        return None

    def get_last_behavior(self):
        intention = self.get_current_leg().intention
        return self.get_behavior(self.last_key, self.last_speed, intention, self.get_next_type())

    def get_behavior(self, key, speed, intention, next_type):
        if key == _SENSOR_KEY_NONE:
            return _BEHAVIOR_FLAG_SPEED ^ speed
        if not (intention == _INTENTION_STOP or next_type == _LEG_TYPE_FLIP):
            return _BEHAVIOR_FLAG_SPEED ^ speed

        # stop the train
        if key == _SENSOR_KEY_ENTER:
            return _BEHAVIOR_FLAG_SPEED ^ _SENSOR_SPEED_SLOW
        if key == _SENSOR_KEY_IN:
            return _BEHAVIOR_FLAG_STOP

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
        return (self.data[self.index] >> 4) & 0b11
    
    def get_next_speed(self):
        return (self.data[self.index] >> 6) & 0b11

class Train:

    def __init__(self):
        self.motor = TrainMotor()
        self.sensor = TrainSensor(self.on_marker_passed)

        self.route : Route = Route()
    
    def on_marker_passed(self, color):
        behavior = self.route.advance_sensor(color)
        self.execute_behavior(behavior)
        if self.route.get_next_leg() == None and self.route.get_current_leg().is_complete():
            self.route = None
    
    def advance_route(self):
        behavior = self.route.advance()
        self.execute_behavior(behavior)

    def execute_behavior(self, behavior):
        if behavior & _BEHAVIOR_FLAG_STOP:
            self.motor.set_speed(0)
            return
        if behavior & _BEHAVIOR_FLAG_FLIP:
            self.motor.flip_direction()
        if behavior & _BEHAVIOR_FLAG_SPEED:
            self.motor.set_target(io_hub.storage[2+(behavior & 0x0F)])
    
    def new_route(self):
        self.route = Route()

    def set_route_leg(self, data):
        self.route.set_leg(data)
    
    def set_leg_intention(self, data):
        self.route.legs[data[0]].intention = data[1]
        if self.route.index == data[0]:
            behavior = self.route.get_last_behavior()
            self.execute_behavior(behavior)

    def update(self, delta):
        if self.motor.target_speed != 0 and len(self.route.legs) > 1:
            self.sensor.update(delta)

        self.motor.update(delta)
    
    def set_valid_colors(self, data):
        self.sensor.valid_colors = list(data)
    
    def dump_color_buffer(self):
        pack_into(">H", self.sensor.color_buf, 1000, self.sensor.buf_index)
        io_hub.dump_data(_DUMP_TYPE_COLORS, self.sensor.color_buf)

assert VERSION != b"1.0.0"
train = Train()
io_hub = IOHub(train)

io_hub.storage[_CONFIG_CHROMA_THRESHOLD] = 3500
io_hub.storage[_CONFIG_MOTOR_ACC] = 40
io_hub.storage[_CONFIG_MOTOR_DEC] = 90
io_hub.storage[_CONFIG_MOTOR_SLOW_SPEED] = 40
io_hub.storage[_CONFIG_MOTOR_CRUISE_SPEED] = 75
io_hub.storage[_CONFIG_MOTOR_FAST_SPEED] = 100
io_hub.storage[_CONFIG_MOTOR_INVERTED] = 0

io_hub.run_loop()