
import asyncio

from pybricksdev.ble import find_device

from ble_hub2 import BLEHub

def const(x):
    return x

async def main():
    train = BLEHub()
    dev = await find_device()
    print(dev)
    await train.connect(dev)
    try:
        await train.run("brickrail-gui/ble-server/hub_programs/layout_controller64.py")
        
        await train.stop_program()
    finally:
        await train.disconnect()

asyncio.run(main())