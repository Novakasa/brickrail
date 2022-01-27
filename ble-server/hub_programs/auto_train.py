from uselect import poll
from usys import stdin
from ustruct import pack

from pybricks.hubs import CityHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch

COLOR_HUES = {}
COLOR_HUES["yellow"]  = 31
COLOR_HUES["blue"] = 199
# COLOR_HUES["orange"] = 338
COLOR_HUES["green"] = 113
COLOR_HUES["red"] = 339

class TrainSensor:

    def __init__(self, marker_exit_callback):
        self.sensor = ColorDistanceSensor(Port.B)
        self.colors = {}
        self.marker_colors = []
        self.speed_a = None
        self.speed_b = None
        self.marker_exit_callback = marker_exit_callback

        self.marker_samples = 0
        self.marker_hue = 0
    
    def update(self, delta):
        color = self.get_hsv()
        h, s, v = color.h, color.s, color.v
        h = (h-20)%360
        if s*v>3500:
            self.marker_samples += 1
            self.marker_hue += h
            return
        if self.marker_samples>0:
            self.marker_hue//=self.marker_samples
            colorname = None
            colorerr = 361
            for color, chue in COLOR_HUES.items():
                err = abs(chue-self.marker_hue)
                if colorname is None or err<colorerr:
                    colorname = color
                    colorerr = err
            self.marker_hue = 0
            self.marker_samples = 0
            self.marker_exit_callback(colorname)
    
    def get_hsv(self):
        return self.sensor.hsv()

class TrainMotor:

    def __init__(self):
        self.speed = 0
        self.target_speed = 0
        self.acceleration = 40
        self.deceleration = 90
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
                self.speed = min(abs(self.speed)+delta*self.acceleration, self.target_speed)*self.direction
            if abs(self.speed)>self.target_speed:
                self.speed = max(abs(self.speed)-delta*self.deceleration, self.target_speed)*self.direction
        else:
            self.speed += delta*self.deceleration*self.direction
        
        self.motor.dc(self.speed)

        if self.braking:
            self.motor.brake()
            return
        

class Train:

    def __init__(self):
        self.hub = CityHub()
        self.hub.system.set_stop_button(None)
        self.motor = TrainMotor()
        self.sensor = TrainSensor(self.on_marker_exit)
        self.button_pressed = False

        self.data_queue = []
        self.state = None

        self.expect_marker = None
        self.expect_behaviour = None
        
        self.set_state("stopped")

        self.hbuf = bytearray(1000)
        self.sbuf = bytearray(1000)
        self.vbuf = bytearray(1000)
        self.rbuf = bytearray(1000)
        self.buf_index = 0
        self.dump=False

    def queue_data(self, key, data):
        self.data_queue.append((key, data))
    
    def set_state(self, state):
        self.state = state
        self.queue_data("state_changed", state)
    
    def report_hsv(self):
        color = self.sensor.get_hsv()
        self.queue_data("hsv", [color.h, color.s, color.v])
        colorname = self.sensor.match_colorname(self.sensor.sensor.hsv())
        self.queue_data("colorname", colorname)
    
    def set_expect_marker(self, name, behaviour):
        self.expect_marker = name
        self.expect_behaviour = behaviour
    
    def slow(self):
        # print("slowing...")
        self.motor.set_target(40)
        self.set_state("slow")
    
    def stop(self):
        # print("stopping...")
        self.motor.brake()
        self.set_state("stopped")
    
    def start(self):
        self.motor.set_target(90)
        self.set_state("started")

    def flip_heading(self):
        self.motor.flip_direction()
    
    def set_expect_marker_handled(self):
        self.queue_data("handled_marker", self.expect_marker)
        self.expect_marker = None
        self.expect_behaviour = None

    def on_marker_exit(self, colorname):
        if colorname == self.expect_marker:
            if self.expect_behaviour=="slow":
                self.slow()
                self.set_expect_marker_handled()
            if self.expect_behaviour=="start":
                self.start()
                self.set_expect_marker_handled()
            if self.expect_behaviour=="ignore":
                self.set_expect_marker_handled()
            if self.expect_behaviour=="stop":
                self.stop()
                self.set_expect_marker_handled()
            if self.expect_behaviour=="flip_heading":
                self.flip_heading()
                self.set_expect_marker_handled()
        else:
            self.queue_data("detected_unexpected_marker", colorname)
    
    def on_button_down(self, delta):
        self.report_hsv()
        print("delta", delta)
        raise SystemExit
    
    def queue_dump_buffers(self):
        self.dump=True
    
    def dump_buffers(self):
        print(self.hbuf)
        print(self.sbuf)
        print(self.vbuf)
        print(self.rbuf)
        print(self.buf_index)
    
    def update(self, delta):
        if self.state in ["started", "slow", "stopped"]:
            self.sensor.update(delta)
        if self.dump:
            self.dump=False
            self.dump_buffers()
        self.buf_index+=1
        if self.buf_index>=len(self.hbuf):
            self.buf_index=0
        color = self.sensor.get_hsv()
        self.hbuf[self.buf_index] = int(0.5*color.h)
        self.sbuf[self.buf_index] = color.s
        self.vbuf[self.buf_index] = color.v
        self.rbuf[self.buf_index] = self.sensor.sensor.reflection()
        #print(color.h)
        #print(color.s)
        #print(color.v)
        self.motor.update(delta)
        if self.hub.button.pressed():
            if not self.button_pressed:
                self.on_button_down(delta)
                self.button_pressed = True
        else:
            self.button_pressed=False


device = train = Train()
max_delta = 0.0001

def send_data_queue(queue):
    if not queue:
        return
    msg = ""
    for key, data in queue:
        obj = {"key": key, "data": data}
        msg += "data::"+repr(obj)+"$"
    print(msg)

def input_handler(message):
    global running
    if message == "stop_program":
        running=False
    if message.find("::") > 0:
        lmsg = list(message)
        for _ in range(5):
            del lmsg[0]
        expr = "".join(lmsg)
        try:
            struct = eval(expr)
        except SyntaxError:
            print("[ble_hub] Syntaxerror when running eval()")
            print(expr)
        if message.find("rpc::")==0:
            func = getattr(device, struct["func"])
            args = struct["args"]
            _result = func(*args)
    else:
        print(message)


running = True
input_buffer = ""
p = poll()
p.register(stdin)

def update_input(char):
    global input_buffer
    if char == "$":
        input_handler(input_buffer)
        input_buffer = ""
    elif char == "#":
        print("msg_ack$")
    else:
        input_buffer += char

def update(delta):
    device.update(delta)
    send_data_queue(device.data_queue)
    device.data_queue = []

def main_loop():
    loop_watch = StopWatch()
    loop_watch.resume()
    last_time = loop_watch.time()
    while running:
        if p.poll(int(1000*max_delta)):
            char = stdin.read(1)
            if char is not None:
                update_input(char)
        t = loop_watch.time()
        delta = (t-last_time)/1000
        last_time = t
        update(delta)

main_loop()