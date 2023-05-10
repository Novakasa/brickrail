
import asyncio
from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

async def main():
    print("scanning for dev1...")
    dev1 = await find_device()
    print("dev1:", repr(dev1))
    print("connecting to hub1...")
    hub1 = PybricksHub()
    await hub1.connect(dev1)
    print("connected to hub1!")
    print()

    print("scanning for dev2...")
    dev2 = await find_device()
    print("dev2:", dev2)
    print("connecting to hub2!")
    hub2 = PybricksHub()
    await hub2.connect(dev2)
    print("connected to hub2!")
    print()
    
    print("disconnecting...")
    await hub1.disconnect()
    await hub2.disconnect()

    print("OK!")

asyncio.run(main())
