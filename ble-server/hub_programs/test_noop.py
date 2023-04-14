
import usys
from pybricks.tools import wait

print(usys.version)
print("[hub] program start")
for i in range(25):
    wait(100)
    print(i)
print("[hub] program end")