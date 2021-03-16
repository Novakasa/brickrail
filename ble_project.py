import json

from ble_hub import BLEHub, main as hub_demo

class BLEProject:

    def __init__(self):
        self.hubs = {}
    
    def add_hub(self, name, script_path, address=None):
        self.hubs[name] = BLEHub(name, script_path, address)
    
    def print(self, str):
        print(str)
    
    def get_hubnames(self):
        return list(self.hubs.keys())
    
    async def hub_demo(self):
        await hub_demo()