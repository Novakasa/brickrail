
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

_DATA_STATE_CHANGED = const(0)
_DATA_ROUTE_COMPLETE = const(1)
_DATA_ROUTE_ADVANCE = const(2)

_PLAN_STOP         = const(0)
_PLAN_PASSING      = const(1)
_PLAN_FLIP_HEADING = const(2)

def create_leg_data(colors, keys, plan, start_index):
    data = bytearray()
    for color, key in zip(colors, keys):
        composite = (key << 4) + color
        data.append(composite)
    composite = start_index + (plan << 4)
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
        (_COLOR_RED,       _COLOR_RED,       _COLOR_RED,        _COLOR_RED),
        (_SENSOR_KEY_NONE, _SENSOR_KEY_NONE, _SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        _PLAN_PASSING, 0))
    await train.rpc("set_next_leg", create_leg_data(
        (_COLOR_BLUE,      _COLOR_BLUE,      _COLOR_BLUE,       _COLOR_BLUE),
        (_SENSOR_KEY_NONE, _SENSOR_KEY_NONE, _SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        _PLAN_FLIP_HEADING, 1))
    await train.rpc("start")
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)
    await asyncio.sleep(5)
    await train.rpc("set_leg", create_leg_data(
        (_COLOR_RED,       _COLOR_RED,       _COLOR_RED,        _COLOR_RED),
        (_SENSOR_KEY_NONE, _SENSOR_KEY_NONE, _SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        _PLAN_STOP, 0))
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)

async def main():
    train = BLEHub()
    dev = await find_device()
    print(dev)
    await train.connect(dev)
    try:
        await train.run("brickrail-gui/ble-server/hub_programs/smart_train.py")

        await test_route_leg(train)
        
        await train.stop_program()
    finally:
        await train.disconnect()

asyncio.run(main())