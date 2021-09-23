from uselect import poll
from usys import stdin

from pybricks.hubs import CityHub
from pybricks.pupdevices import DCMotor
from pybricks.parameters import Port
from pybricks.tools import wait


input_buffer = ""
loop_poll = poll()
loop_poll.register(stdin)


hub = CityHub()
motor = DCMotor(Port.A)
running = True

def hello():
    print("hello")

def start():
    motor.dc(50)

def stop():
    motor.dc(0)

def exit():
    global running
    wait(1000)
    running = False

def input_handler(msg):
    # print("got message from PC:", msg)
    if msg == "start":
        start()
    if msg == "stop":
        stop()
    if msg == "exit":
        exit()
    if msg == "hello":
        hello()

def update_input(char):
    global input_buffer
    if char == "$":
        input_handler(input_buffer)
        input_buffer = ""
    else:
        input_buffer += char

def main_loop():
    while running:
        if loop_poll.poll(100): #times out after 100ms
            char = stdin.read(1)
            if char is not None:
                update_input(char)

        # update other stuff here

main_loop()