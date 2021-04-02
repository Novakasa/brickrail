from pybricks.hubs import CityHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch
from pybricks.experimental import getchar

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
        self.braking = False
    
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

        if self.speed < self.target_speed:
            speed_delta = self.acceleration*delta
            self.speed = min(self.speed+speed_delta, self.target_speed)
        if self.speed > self.target_speed:
            speed_delta = self.deceleration*delta
            self.speed = max(self.speed-speed_delta, self.target_speed)
        # print(speed, speed_delta)

        if self.braking:
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
    
    def set_state(self, state):
        self.state = state
        send_data("state_changed", state)
    
    def slow(self):
        print("slowing...")
        self.motor.set_target(40)
        self.set_state("slow")
    
    def stop(self):
        print("stopping...")
        self.set_state("stopped")
        self.motor.brake()
    
    def start(self):
        self.set_state("started")
        self.motor.set_target(100)
    
    def wait(self):
        if self.state != "stopped":
            self.stop()
        print("waiting...")
        self.set_state("waiting")
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

device = train = Train()

def update_timers():
    for timer in Timer.timers:
        timer.update()

def input_handler(message):
    print("interpreting message:", message)
    if message.find("cmd::") == 0:
        lmsg = list(message)
        for _ in range(5):
            del lmsg[0]
        code = "".join(lmsg)
        print("evaluating:", code)
        try:
            eval(code)
        except SyntaxError as e:
            print(e)
    else:
        print(message)

def send_data(key, data):
    obj = {"key": key, "data": data}
    msg = "data::"+repr(obj)
    print(msg)

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

def main_loop():
    while True:
        wait(int(delta*1000))
        update_input()
        update()

main_loop()