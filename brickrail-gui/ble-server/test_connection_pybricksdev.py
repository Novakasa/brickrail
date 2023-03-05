
import asyncio
from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

async def main():

    for _ in range(5):
        dev = await find_device()
        print(dev)
        print("connecting...")
        hub = PybricksHub()
        await hub.connect(dev)
        print("connected!")
        await asyncio.sleep(1)
        print("disconnecting...")
        # try:
        #     await asyncio.wait_for(hub.disconnect(), 10.0)
        # except asyncio.TimeoutError:
        #     print("disconnect timeout")
        #     await asyncio.sleep(10.0)
        await hub.disconnect()
        print("disconnected!")

    print("OK!")

asyncio.run(main())