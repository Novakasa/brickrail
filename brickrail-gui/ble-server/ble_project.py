import asyncio

from pybricksdev.ble import find_device

from ble_hub import BLEHub
from serial_data import SerialData

class BLEProject:

    def __init__(self):
        self.hubs = {}
        self.out_queue = asyncio.Queue()
    
    def add_hub(self, name, program_name):
        self.hubs[name] = BLEHub(name, program_name, self.out_queue)
    
    def rename_hub(self, name, new_name):
        hub = self.hubs[name]
        del self.hubs[name]
        self.hubs[new_name] = hub
        hub.set_name(new_name)
    
    def remove_hub(self, name):
        del self.hubs[name]
    
    async def find_device(self):
        try:
            device =  await find_device()
        except asyncio.TimeoutError:
            await self.out_queue.put(SerialData("no_device_found", None, None))
        else:
            await self.out_queue.put(SerialData("device_name_found", None, device.name))
    
    def get_hubnames(self):
        return list(self.hubs.keys())
