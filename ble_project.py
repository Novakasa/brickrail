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
    
    async def find_device(self, devicename="Pybricks Hub"):
        device =  await find_device(devicename)
        return device.address
    
    def print(self, str):
        print(str)
    
    def get_hubnames(self):
        return list(self.hubs.keys())
    
    async def hub_demo(self):
        await hub_demo()