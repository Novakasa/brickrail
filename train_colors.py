from pybricks.pupdevices import ColorDistanceSensor, DCMotor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch

sensor = ColorDistanceSensor(Port.B)
red_marker = Color(h=357, s=96, v=80) #measured in dark room
blue_marker = Color(h=219, s=94, v=75) #measured in dark room
orange_floor = Color(h=40, s=66, v=49) #measured in dark room
orange_floor2 = Color(h=20, s=65, v=49) #measured in dark room
orange_floor3 = Color(h=21, s=82, v=45) # measured with lights on
dark_gray_sleeper = Color(h=0, s=5, v=20) #measured in dark room
dark_gray_sleeper2 = Color(h=340, s=17, v=20) #measured in dark room
bluish_gray_sleeper = Color(h=168, s=24, v=26) #measured in dark room
bluish_gray_sleeper2 = Color(h=204, s=46, v=37) #measured with lights on
colors = {
    "red_marker": red_marker,
    "blue_marker": blue_marker,
    "orange_floor": orange_floor,
    "orange_floor2": orange_floor2,
    "orange_floor3": orange_floor3,
    "dark_gray_sleeper": dark_gray_sleeper,
    "dark_gray_sleeper2": dark_gray_sleeper2,
    "bluish_gray_sleeper": bluish_gray_sleeper,
    "bluish_gray_sleeper2": bluish_gray_sleeper2
}

sensor.detectable_colors(list(colors.values()))
motor = DCMotor(Port.A)

target_speed = 100
speed = 0
acceleration = 40
deceleration = 90
delta = 0.03
blind = False
waiting = False
wait_timer = StopWatch()
blind_timer = StopWatch()
print("test")

def debug_hsv():
    color = sensor.color()
    hsv = sensor.hsv()
    for colorname in colors:
        if color == colors[colorname]:
            if colorname == "red_marker":
                print(colorname)
                print(hsv)
            else:
                print("not red")

def sensor_update():
    global blind, waiting, target_speed, speed
    if blind:
        return
    color = sensor.color()
    if color == red_marker:
        print("stopped! waiting...")
        wait_timer.reset()
        waiting=True
        target_speed = 0
        speed = 0
        blind=2000
        return
    if color == blue_marker:
        print("slowing!")
        target_speed = 30
        blind=400
        blind_timer.reset()
        return
        

def timer_update():
    global waiting, blind, target_speed
    if waiting:
        if wait_timer.time() > 4000:
            waiting=False
            blind_timer.reset()
            blind=2000
            target_speed = 100
            print("starting!")
    elif blind:
        if blind_timer.time() > blind:
            blind = False

def speed_update():
    global speed
    if speed < target_speed:
        speed_delta = acceleration*delta
        speed = min(speed+speed_delta, target_speed)
    if speed > target_speed:
        speed_delta = deceleration*delta
        speed = max(speed-speed_delta, target_speed)
    # print(speed, speed_delta)

def motor_update():
    global speed
    if speed:
        motor.dc(int(speed))
    else:
        # print("breaking!!")
        motor.brake()

while True:

    wait(int(delta*1000))
    
    #debug_hsv()
    #continue
    
    sensor_update()
    timer_update()
    speed_update()
    motor_update()