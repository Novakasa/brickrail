
import asyncio

from pybricksdev.ble import find_device

from ble_hub2 import BLEHub

def const(x):
    return x

_COLOR_YELLOW = const(0)
_COLOR_BLUE   = const(1)
_COLOR_GREEN  = const(2)
_COLOR_RED    = const(3)

_SENSOR_KEY_NONE  = const(0)
_SENSOR_KEY_ENTER = const(1)
_SENSOR_KEY_IN    = const(2)

def create_leg_data(colors, keys, passing, start_index):
    data = bytearray()
    for color, key in zip(colors, keys):
        composite = (key << 4) + color
        data.append(composite)
    composite = start_index + 0b10000000*passing
    data.append(composite)
    return data

async def test_motor(train):
    await asyncio.sleep(1)
    await train.rpc("start")
    await asyncio.sleep(4)
    await train.rpc("slow")
    await asyncio.sleep(2)
    await train.rpc("stop")

async def test_route_leg(train):
    await asyncio.sleep(1)
    await train.rpc("set_leg", create_leg_data(
        (_COLOR_RED,       _COLOR_BLUE,      _COLOR_RED,       _COLOR_BLUE),
        (_SENSOR_KEY_NONE, _SENSOR_KEY_NONE, _SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        False, 0))
    await train.rpc("start")
    await asyncio.sleep(20)

async def main():
    train = BLEHub()
    dev = await find_device()
    await train.connect(dev)
    try:
        await train.run("brickrail-gui/ble-server/hub_programs/smart_train.py")

        await test_route_leg(train)
        
        await train.stop_program()
    finally:
        await train.disconnect()

asyncio.run(main())