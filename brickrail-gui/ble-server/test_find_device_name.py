import asyncio

from pybricksdev.ble import find_device

async def main():

    device = await find_device()
    print(device)
    print(device.name)
    
asyncio.run(main())