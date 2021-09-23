import time

import asyncio

from pybricksdev.connections import PybricksHub, BLEPUPConnection
from pybricksdev.ble import find_device


async def main_coro():
    device = await find_device()
    hub = PybricksHub()
    # hub = BLEPUPConnection()
    await hub.connect(device)
    t0 = time.time()
    # await hub.run("autonomous_train.py", wait=True)
    await hub.run("hello_hub.py", wait=True)
    t = time.time()-t0
    print(f"starting program took {t} seconds!")

asyncio.run(main_coro())