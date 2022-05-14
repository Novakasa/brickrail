import asyncio
import json

from pybricksdev.ble import find_device

from ble_hub import BLEHub, main as hub_demo

class BLEProject:

    def __init__(self):
        self.hubs = {}
        self.out_queue = asyncio.Queue()
    
    def add_hub(self, name, script_path, address=None):
        self.hubs[name] = BLEHub(name, script_path, self.out_queue, address)
    
    def rename_hub(self, name, new_name):
        hub = self.hubs[name]
        del self.hubs[name]
        self.hubs[new_name] = hub
        hub.set_name(new_name)
    
    def remove_hub(self, name):
        del self.hubs[name]
    
    async def find_device(self):
        device =  await find_device()
        return device.address
    
    def print(self, str):
        print(str)
    
    def get_hubnames(self):
        return list(self.hubs.keys())
    
    async def hub_demo(self):
        await hub_demo()