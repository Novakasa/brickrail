import json

from ble_hub import BLEHub

class BLEProject:

    def __init__(self):
        self.hubs = {}
    
    def add_hub(self, name, script_path, address=None):
        self.hubs[name] = BLEHub(name, script_path, address)