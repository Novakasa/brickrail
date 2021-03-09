from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device

import asyncio



async def main():
    address = await find_device("Pybricks Hub")
    hub = BLEPUPConnection()
    await hub.connect(address)
    await hub.run("train_colors.py")

asyncio.run(main())