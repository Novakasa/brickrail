
import asyncio
from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

async def main():

    dev1 = await find_device()
    hub1 = PybricksHub()
    await hub1.connect(dev1)
    print("hub1 connected!")

    print("hub1 downloading...")
    await hub1.run("brickrail-gui/ble-server/hub_programs/test_noop_large.py")
    await asyncio.sleep(1)

    dev2 = await find_device()
    hub2 = PybricksHub()
    await hub2.connect(dev2)
    print("hub2 connected!")

    print("hub1 downloading...")
    await hub1.run("brickrail-gui/ble-server/hub_programs/test_noop_large.py")

    print("hub2 downloading...")
    await hub2.run("brickrail-gui/ble-server/hub_programs/test_noop_large.py")

    await hub2.disconnect()
    print("hub2 disconnected!")

    print("hub1 downloading...")
    await hub1.run("brickrail-gui/ble-server/hub_programs/test_noop_large.py")

    await hub1.disconnect()
    print("hub1 disconnected!")

asyncio.run(main())