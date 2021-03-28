import time

import asyncio

from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device


async def main_coro():
    device = await find_device("Pybricks Hub")
    hub = BLEPUPConnection()
    await hub.connect(device)
    t0 = time.time()
    await hub.run("autonomous_train.py", wait=False)
    t = time.time()-t0
    print(f"starting program took {t} seconds!")

asyncio.run(main_coro())