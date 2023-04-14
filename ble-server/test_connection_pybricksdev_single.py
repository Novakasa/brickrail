
import asyncio
from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub

async def main():

    for i in range(5):
        print("loop",i)
        dev = await find_device()
        print(dev)
        print("connecting...")
        hub = PybricksHub()
        await hub.connect(dev)
        print("connected!")
        # await hub.run("brickrail-gui/ble-server/hub_programs/test_noop.py")
        # await asyncio.sleep(35)
        for i in range(25):
            await asyncio.sleep(0.1)
            # await hub.write(bytearray([i]))
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