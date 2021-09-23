import asyncio

from pybricksdev.connections import PybricksHub
from pybricksdev.ble import find_device


async def main():
    hub = PybricksHub()
    device = await find_device()

    await hub.connect(device)
    await hub.run("client.py", wait=False)
    
    await asyncio.sleep(1)
    for _ in range(4):
        await hub.write(b"start$")
        await asyncio.sleep(1)
        await hub.write(b"stop$")
        await asyncio.sleep(1)

    await hub.write(b"exit$")

    await hub.user_program_stopped.wait()
    await asyncio.sleep(0.3)

loop = asyncio.get_event_loop()
loop.run_until_complete(main())