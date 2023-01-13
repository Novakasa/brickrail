import asyncio

from pybricksdev.ble import find_device

from ble_hub import BLEHub

async def connection_test():
    device = await find_device()
    print(device)
    test_hub = BLEHub()
    await test_hub.connect()

    await asyncio.sleep(3)

    await test_hub.disconnect()
    
asyncio.run(connection_test())