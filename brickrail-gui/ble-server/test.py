import asyncio

from pybricksdev.connections.pybricks import PybricksHub
from pybricksdev.ble import find_device

async def main():
    device = await find_device()
    hub = PybricksHub()
    await hub.connect(device)
    await asyncio.sleep(2.0)
    await hub.disconnect()

asyncio.run(main())