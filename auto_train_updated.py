from uselect import poll
from usys import stdin

from pybricks.hubs import CityHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch

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

class SleeperCounter:
    def __init__(self):
        self.last_ctype = None
        self.transition_times = []
        self.watch = StopWatch()
        self.period = 500
    
    def reset(self):
        self.transition_times = []
        self.last_ctype = None
        self.watch.reset()
    
    def update(self):
        current_time = self.watch.time()
        while self.transition_times and current_time-self.transition_times[0]>self.period:
            del self.transition_times[0]

    def on_ctype(self, ctype):
        if self.last_ctype == ctype:
            return
        self.last_ctype = ctype
        current_time = self.watch.time()
        self.transition_times.append(current_time)
        
        return
    
    def get_speed(self):
        return len(self.transition_times)


class TrainSensor:

    def __init__(self, marker_callback):
        self.sensor = ColorDistanceSensor(Port.B)
        self.blind_timer = Timer()
        self.blind = False
        self.colors = {}
        self.marker_colors = []
        self.speedA = None
        self.speedB = None
        self.marker_callback = marker_callback
        self.sleeper_counter = SleeperCounter()
        self.measure_speed = False
    
    def add_color(self, name, color, type):
        self.colors[name] = color
        if type=="marker":
            if name not in self.marker_colors:
                self.marker_colors.append(name)
        if type=="speedA":
            self.speed_a = name
        if type=="speedB":
            self.speed_b = name
        self.sensor.detectable_colors(list(self.colors.values()))
    
    def remove_color(self, name):
        del self.colors[name]
        if name in self.marker_colors:
            self.marker_colors.remove(name)
        if self.speed_a == name:
            self.speed_a = None
        if self.speed_b == name:
            self.speed_b = None
    
    def update(self, delta):
        if self.measure_speed:
            self.sleeper_counter.update()
        if self.blind:
            return
        measured_color = self.sensor.color()
        for colorname, color in CALIBRATED_COLORS.items():
            if color != measured_color:
                continue
            if colorname in self.marker_colors:
                self.marker_callback(colorname)
                return
            if self.measure_speed:
                if colorname == self.speed_a:
                    self.sleeper_counter.on_ctype(0)
                if colorname == self.speed_b:
                    self.sleeper_counter.on_ctype(1)

    def estimate_speed(self):
        return self.sleeper_counter.get_speed()
    
    def get_hsv(self):
        return self.sensor.hsv()
    
    def make_blind(self, duration=None):
        if duration:
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
        self.direction = 1
    
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
            self.motor.dc(self.direction*self.speed)
            return
        if self.speed > self.target_speed:
            speed_delta = self.deceleration*delta
            self.speed = max(self.speed-speed_delta, self.target_speed)
            self.motor.dc(self.direction*self.speed)
            return

        if self.braking:
            self.motor.brake()
            return
        

class Train:

    def __init__(self):
        self.wait_timer = Timer()
        self.hub = CityHub()
        self.hub.system.set_stop_button(None)
        self.motor = TrainMotor()
        self.sensor = TrainSensor(self.on_marker)

        self.heading = 1

        self.data_queue = []
        self.state = None
        self.mode = None
        self.slow_marker = None
        self.stop_marker = None

        self.expect_marker = None
        self.expect_behaviour = None
        
        self.set_state("stopped")
        self.set_mode("manual")
    
    def set_mode(self, mode):
        self.mode = mode
        self.queue_data("mode_changed", mode)
    
    def set_slow_marker(self, marker):
        self.slow_marker = marker
        self.queue_data("slow_marker_changed", marker)

    def set_stop_marker(self, marker):
        self.stop_marker = marker
        self.queue_data("stop_marker_changed", marker)

    def queue_data(self, key, data):
        self.data_queue.append((key, data))
    
    def set_state(self, state):
        self.state = state
        self.queue_data("state_changed", state)
    
    def report_speed(self):
        speed = self.sensor.estimate_speed()
        self.queue_data("speed", speed)
    
    def report_hsv(self):
        color = self.sensor.get_hsv()
        self.queue_data("hsv", [color.h, color.s, color.v])
    
    def add_color(self, name, color, type):
        self.sensor.add_color(name, color, type)
    
    def set_expect_marker(self, name, behaviour):
        self.expect_marker = name
        self.expect_behaviour = behaviour
    
    def slow(self):
        # print("slowing...")
        self.sensor.measure_speed=True
        self.sensor.sleeper_counter.reset()
        self.motor.set_target(40)
        self.set_state("slow")
    
    def stop(self):
        # print("stopping...")
        self.sensor.measure_speed=False
        self.motor.brake()
        self.set_state("stopped")
    
    def start(self):
        self.sensor.measure_speed=False
        self.motor.set_target(100)
        self.sensor.make_blind(1500)
        self.set_state("started")
    
    def wait(self, duration):
        if self.state != "stopped":
            self.stop()
        # print("waiting...")
        self.set_state("waiting")
        self.wait_timer.arm(duration, self.on_wait_timer)
    
    def flip_heading(self):
        self.heading *= -1
        self.motor.direction = self.heading
    
    def on_marker(self, colorname):
        self.queue_data("detected_marker", colorname)
        if colorname == self.expect_marker:
            if self.expect_behaviour=="slow":
                self.slow()
            if self.expect_behaviour=="start":
                self.start()
            if self.expect_behaviour=="stop":
                self.stop()
            if self.expect_behaviour=="flip_heading":
                self.flip_heading()
        if self.mode == "manual":
            return
        if colorname == self.stop_marker:
            self.stop()
            if self.mode == "auto":
                self.wait(4000)
                return
            else:
                self.sensor.make_blind(400)
        if colorname == self.slow_marker:
            self.slow()
            self.sensor.make_blind(400)
            return
    
    def on_wait_timer(self):
        self.sensor.make_blind(1500)
        self.start()
    
    def update(self, delta):
        if self.state in ["started", "slow"]:
            self.sensor.update(delta)
        self.motor.update(delta)
        if self.hub.button.pressed():
            self.report_hsv()


device = train = Train()
running = True

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
    global running
    if message == "stop_program":
        running=False
    if message.find("cmd::") == 0:
        lmsg = list(message)
        for _ in range(5):
            del lmsg[0]
        code = "".join(lmsg)
        try:
            eval(code)
        except SyntaxError:
            print("[ble_hub] Syntaxerror when running eval()")
            print(code)
    else:
        print(message)


input_buffer = ""

p = poll()
p.register(stdin)

def update_input(char):
    global input_buffer
    if char == "$":
        input_handler(input_buffer)
        input_buffer = ""
    else:
        input_buffer += char

def update():
    update_timers()
    device.update(delta)
    send_data_queue(device.data_queue)
    device.data_queue = []

def main_loop():
    while running:
        if p.poll(int(1000*delta)):
            char = stdin.read(1)
            if char is not None:
                update_input(char)
        update()

main_loop()