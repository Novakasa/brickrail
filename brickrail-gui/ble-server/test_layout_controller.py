
import asyncio

from pybricksdev.ble import find_device

from ble_hub2 import BLEHub

def const(x):
    return x

_SWITCH_POS_LEFT  = const(0)
_SWITCH_POS_RIGHT = const(1)
_SWITCH_POS_NONE  = const(2)

_SWITCH_COMMAND_SWITCH = const(0)

_DATA_SWITCH_CONFIRM  = const(0)

async def main():
    controller = BLEHub()
    dev = await find_device()
    print(dev)
    await controller.connect(dev)
    try:
        await controller.run("brickrail-gui/ble-server/hub_programs/layout_controller64.py")

        # await controller.rpc("assign_switch", bytearray([0]))
        await controller.rpc("device_execute", bytearray([0, _SWITCH_COMMAND_SWITCH, _SWITCH_POS_LEFT]))
        await controller.wait_for_data_id(_DATA_SWITCH_CONFIRM)
        await controller.rpc("device_execute", bytearray([0, _SWITCH_COMMAND_SWITCH, _SWITCH_POS_RIGHT]))
        await controller.wait_for_data_id(_DATA_SWITCH_CONFIRM)
        
        # await controller.rpc("assign_switch", bytearray([1]))
        await controller.rpc("device_execute", bytearray([1, _SWITCH_COMMAND_SWITCH, _SWITCH_POS_LEFT]))
        await controller.rpc("device_execute", bytearray([0, _SWITCH_COMMAND_SWITCH, _SWITCH_POS_LEFT]))
        await controller.wait_for_data_id(_DATA_SWITCH_CONFIRM)
        await controller.wait_for_data_id(_DATA_SWITCH_CONFIRM)
        await controller.rpc("device_execute", bytearray([1, _SWITCH_COMMAND_SWITCH, _SWITCH_POS_RIGHT]))
        await controller.rpc("device_execute", bytearray([0, _SWITCH_COMMAND_SWITCH, _SWITCH_POS_RIGHT]))
        await controller.wait_for_data_id(_DATA_SWITCH_CONFIRM)
        await controller.wait_for_data_id(_DATA_SWITCH_CONFIRM)

        await controller.stop_program()
    finally:
        await controller.disconnect()

asyncio.run(main())