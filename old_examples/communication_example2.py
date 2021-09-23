import asyncio

from pybricksdev.connections import PybricksHub
from pybricksdev.ble import find_device


async def main():
    hub = PybricksHub()
    device = await find_device()

    await hub.connect(device)

    async def hub_run():
        await hub.run("client2.py", wait=False)
        while not hub.program_running:
            await asyncio.sleep(0.05)
        
        while hub.program_running:
            while hub.output: #message printed in hub code
                line = hub.output.pop(0).decode()
                print("got message from hub:", line)
            await asyncio.sleep(0.05)

    run_task = asyncio.create_task(hub_run())

    while not hub.program_running:
        await asyncio.sleep(0.05)
    
    await asyncio.sleep(1)
    for _ in range(4):
        await hub.write(b"hello$")
        await asyncio.sleep(1)

    await hub.write(b"exit$")

    await hub.user_program_stopped.wait()
    await asyncio.sleep(0.3)

loop = asyncio.get_event_loop()
loop.run_until_complete(main())