from pybricks.hubs import CityHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch
from pybricks.experimental import getchar

# from uselect import poll
# from usys import stdin

# loop_poll = poll()
# loop_poll.register(stdin)

CALIBRATED_COLORS = {
    "red_marker": Color(h=357, s=96, v=80), #measured in dark room
    "blue_marker": Color(h=219, s=94, v=75), #measured in dark room
    "orange_floor": Color(h=40, s=66, v=49), #measured in dark room
    "orange_floor2": Color(h=20, s=65, v=49), #measured in dark room
    "orange_floor3": Color(h=21, s=82, v=45), # measured with lights on
    "dark_gray_sleeper": Color(h=0, s=5, v=20), #measured in dark room
    "dark_gray_sleeper2": Color(h=340, s=17, v=20), #measured in dark room
    "bluish_gray_sleeper": Color(h=168, s=24, v=26), #measured in dark room
    "bluish_gray_sleeper2": Color(h=204, s=46, v=37) #measured with lights on
}

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

class TrainSensor:

    def __init__(self, marker_colors, marker_callback):
        self.sensor = ColorDistanceSensor(Port.B)
        self.sensor.detectable_colors(list(CALIBRATED_COLORS.values()))
        self.blind_timer = Timer()
        self.blind = False
        self.marker_colors = marker_colors
        self.marker_callback = marker_callback
    
    def update(self, delta):
        if self.blind:
            return
        measured_color = self.sensor.color()
        for colorname, color in CALIBRATED_COLORS.items():
            if color != measured_color:
                continue
            if colorname in self.marker_colors:
                print("detected marker!!", colorname)
                self.marker_callback(colorname)
                return
    
    def make_blind(self, duration):
        self.blind_timer.arm(duration, self.on_blind_timer)
        self.blind = True
    
    def on_blind_timer(self):
        self.blind = False

class TrainMotor:

    def __init__(self):
        self.speed = 0
        self.target_speed = 0
        self.acceleration = 40
        self.deceleration = 90
        self.motor = DCMotor(Port.A)
        self.motor_brake = False
    
    def set_target(self, speed):
        self.target_speed = speed
        self.motor_brake = False
    
    def set_speed(self, speed):
        self.target_speed = speed
        self.speed = speed
        self.motor_brake = False
    
    def brake(self):
        self.target_speed = 0
        self.speed = 0
        self.motor_brake = True
    
    def update(self, delta):

        if self.speed < self.target_speed:
            speed_delta = self.acceleration*delta
            self.speed = min(self.speed+speed_delta, self.target_speed)
        if self.speed > self.target_speed:
            speed_delta = self.deceleration*delta
            self.speed = max(self.speed-speed_delta, self.target_speed)
        # print(speed, speed_delta)

        if self.motor_brake:
            self.motor.brake()
            return
        self.motor.dc(self.speed)

class Train:

    def __init__(self):
        self.wait_timer = Timer()

        self.state = "stopped"

        self.hub = CityHub()
        self.motor = TrainMotor()
        self.sensor = TrainSensor(["red_marker", "blue_marker"], self.on_marker)
    
    def slow(self):
        print("slowing...")
        self.motor.set_target(40)
        self.state = "slow"
    
    def stop(self):
        print("stopping...")
        self.state == "stopped"
        self.motor.brake()
    
    def start(self):
        self.state == "started"
        self.motor.set_target(100)
    
    def wait(self):
        if self.state != "stopped":
            self.stop()
        print("waiting...")
        self.wait_timer.arm(4000, self.on_wait_timer)
    
    def on_marker(self, colorname):
        if colorname == "red_marker":
            self.stop()
            self.wait()
            self.sensor.make_blind(4000)
            return
        if colorname == "blue_marker":
            self.slow()
            self.sensor.make_blind(400)
            return
    
    def on_wait_timer(self):
        self.sensor.make_blind(1500)
        self.start()
    
    def update(self, delta):
        self.sensor.update(delta)
        self.motor.update(delta)

train = Train()

def timer_update():
    for timer in Timer.timers:
        timer.update()

def input_handler(char):
    print(repr(char))
    if char == "s":
        train.stop()
    if char == "l":
        train.slow()
    if char == "h":
        train.start()
    if char == "w":
        train.wait()
    

def control_loop():
    timer_update()
    train.update(delta)


while True:
    timeout = int(delta*1000)
    wait(timeout)
    char = getchar()
    #if loop_poll.poll(timeout):
    if char is not None:
        char = chr(char)
        input_handler(char)
    control_loop()