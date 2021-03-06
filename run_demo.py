from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device

import asyncio

async def main():
    address = await find_device("Pybricks Hub")
    hub = BLEPUPConnection()
    await hub.connect(address)
    await hub.run("train_colors.py", wait=False)

    await hub.wait_until_state(hub.RUNNING)

    await asyncio.sleep(1)
    await hub.write(b"l")
    await asyncio.sleep(5)
    await hub.write(b"h")
    await asyncio.sleep(5)
    await hub.write(b"l")
    await asyncio.sleep(5)
    await hub.write(b"s")
    await asyncio.sleep(5)
    print("done with main!")

    await hub.wait_until_state(hub.IDLE)


asyncio.run(main())