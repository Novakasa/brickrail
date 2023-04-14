
import asyncio
from ble_hub import BLEHub

async def main():

    train = BLEHub("test_train", "train", asyncio.Queue())
    await train.connect()
    await train.run()

    await train.pipe_command("train.start()")
    
    while True:
        await asyncio.sleep(1)
        try:
            await train.pipe_command("train.report_speed()")
        except AssertionError:
            print(train.hub.output)
        # await train.hub.write(b"dsdsdsdadsdadsa$")
        # await train.pipe_command("print(len(train.sensor.sleeper_counter.transition_times))")

        # await train.pipe_command("train.slow()")


    #await train.hub.wait_until_state(train.hub.IDLE)

asyncio.run(main())