import asyncio

from pybricksdev.ble import find_device

from ble_hub import BLEHub

async def io_test():

    response_queue = asyncio.Queue()

    def on_data(data):
        print(f"got data: {list(data)}")
        response_queue.put_nowait(data)
    
    async def test_response(data):
        await test_hub.rpc("respond", data)
        while not response_queue.empty():
            _ = response_queue.get_nowait()
        received = await asyncio.wait_for(response_queue.get(), 1.0)
        assert received == data

    device = await find_device()
    print(device)
    test_hub = BLEHub()
    test_hub.data_subject.subscribe(on_data)
    await test_hub.connect(device)
    try:
        await test_hub.run("test_io", wait=False)
        await asyncio.sleep(1.0)
        await test_hub.rpc("respond", bytearray([1,4,5,253]))
        await asyncio.sleep(1.0)
        await test_hub.rpc("respond", bytearray([1,2,3,4]))
        await asyncio.sleep(1.0)
        await test_hub.rpc("print_data", bytearray([0, 1, 2, 10]))
        await asyncio.sleep(1.0)
        for i in range(0,256-16, 8):
            await test_response(bytearray([j for j in range(i, i+16)]))
            # await asyncio.sleep(0.2)
        await asyncio.sleep(1)
        await test_hub.stop_program()
        await asyncio.sleep(1)
    finally:
        await test_hub.disconnect()
    
asyncio.run(io_test())