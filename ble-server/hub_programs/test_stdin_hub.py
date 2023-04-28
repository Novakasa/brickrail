# NOTE: Run this program with the latest
# firmware provided via https://beta.pybricks.com/

from pybricks.tools import wait

# Standard MicroPython modules
from usys import stdin, stdout
from uselect import poll

keyboard = poll()
keyboard.register(stdin)
buffer = bytearray()

for _ in range(3):
    while True:

        if keyboard.poll(50):
            byte = stdin.buffer.read(1)[0]
            print(byte, end=" ")
            buffer.append(byte)
            if byte == b"\n"[0]:
                print("\nline received")
                print(str(buffer))
                buffer = bytearray()
                break

wait(100)