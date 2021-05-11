import asyncio
from pybricksdev.connections import PybricksHub
from pybricksdev.ble import find_device
from pybricksdev.connections import NUS_RX_UUID


async def main():
    hub = PybricksHub()
    device = await find_device("Pybricks Hub")
    await hub.connect(device)
    await hub.run("auto_train_updated.py", wait=False)
    while not hub.program_running:
        await asyncio.sleep(0.5)
    # await hub.send_block(b"message")
    await hub.client.write_gatt_char(NUS_RX_UUID, b"message", False)
    await hub.user_program_stopped.wait()

asyncio.run(main())