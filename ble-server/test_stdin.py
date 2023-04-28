
import asyncio
from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

async def main():
    dev = await find_device()
    print(dev)
    hub = PybricksHub()
    await hub.connect(dev)
    print("connected!")
    await hub.run("ble-server/hub_programs/test_stdin_hub.py", print_output=True, wait=False)
    await asyncio.sleep(0.5)
    print("writing line...")
    await hub.write_line("012345")
    print("writing line...")
    await hub.write(b"hello\r\n")
    print("writing line...")
    await hub.write(b"\r\n")
    await asyncio.sleep(5.0)
    await hub.disconnect()

    print("OK!")

asyncio.run(main())
