import asyncio

from pybricksdev.ble import find_device

from ble_hub import BLEHub

async def io_test():

    device = await find_device()
    print(device)
    test_hub = BLEHub()
    await test_hub.connect(device)
    try:
        await test_hub.run("test_storage", wait=False)

        print("storing values...")
        val1 = 975645
        val2 = 888888888
        await test_hub.store_value(2, val1)
        await test_hub.store_value(255, val2)

        await test_hub.rpc("print_address", [2])
        await asyncio.sleep(0.5)
        print("should be:", val1)
        assert str(val1) in test_hub.output_lines[-1]

        await test_hub.rpc("print_address", [255])
        await asyncio.sleep(0.5)
        print("should be:", val2)
        assert str(val2) in test_hub.output_lines[-1]

        await test_hub.stop_program()
        await asyncio.sleep(1)
    finally:
        await test_hub.disconnect()
    
asyncio.run(io_test())