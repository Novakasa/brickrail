
import asyncio

from pybricksdev.ble import find_device

from ble_hub2 import BLEHub

async def main():
    train = BLEHub()
    dev = await find_device()
    await train.connect(dev)
    try:
        await train.run("brickrail-gui/ble-server/hub_programs/smart_train.py")
        await asyncio.sleep(4)
        await train.stop_program()
    finally:
        await train.disconnect()

asyncio.run(main())