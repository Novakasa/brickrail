
import asyncio
from bleak import BleakClient, BleakScanner

async def main():

    try:
        print("scanning for dev1...")
        dev1 = await BleakScanner.find_device_by_name(input("enter device1 name: "))
        print(dev1)
        client1 = BleakClient(dev1)
        print("connecting to dev1")
        await client1.connect()
        print("connected!")
        if input("disconnect? (y/n): ").upper() == "Y":
            print("disconnecting...")
            await client1.disconnect()

        print("scanning for dev2...")
        dev2 = await BleakScanner.find_device_by_name(input("enter device2 name: "))
        print(dev2)
        client2 = BleakClient(dev2)
        print("connecting to dev2")
        await client2.connect()
        print("connected!")
        if input("disconnect? (y/n): ").upper() == "Y":
            print("disconnecting...")
            await client1.disconnect()

    finally:
        if client1.is_connected:
            await client1.disconnect()
        if client2.is_connected:
            await client2.disconnect()

asyncio.run(main())
