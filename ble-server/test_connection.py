import asyncio

from pybricksdev.ble import find_device

from ble_hub import BLEHub

async def connection_test():
    device = await find_device()
    print(device)
    test_hub = BLEHub()

    for _ in range(2):
        await test_hub.connect()

        try:
            await test_hub.run("brickrail-gui/ble-server/hub_programs/smart_train.py")
            await test_hub.stop_program()
        finally:
            await test_hub.disconnect()
        await asyncio.sleep(2)
    
asyncio.run(connection_test())