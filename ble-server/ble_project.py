import asyncio
from pathlib import Path
import sys
from datetime import datetime

from pybricksdev.ble import find_device

from ble_hub import BLEHub
from serial_data import SerialData
import config

class BLEProject:

    def __init__(self):
        self.hubs = {}
        self.out_queue = asyncio.Queue()
    
    def start_logfile(self, path):

        config.user_path = Path(path).parent

        # https://stackoverflow.com/questions/14906764/how-to-redirect-stdout-to-both-file-and-console-with-scripting/14906787#14906787

        now = datetime.now().strftime("%Y-%m-%d_%H.%M.%S")
        logpath = config.user_path / f"ble-server_{now}.log"

        class Logger(object):
            def __init__(self):
                self.terminal = sys.stdout
                with open(logpath, "w"):
                    pass

            def write(self, message):
                with open (logpath, "a", encoding = 'utf-8') as self.log:
                    self.log.write(message)
                self.terminal.write(message)

            def flush(self):
                #this flush method is needed for python 3 compatibility.
                #this handles the flush command by doing nothing.
                #you might want to specify some extra behavior here.
                pass
        logger = Logger()
        sys.stdout = logger 
        sys.stderr = logger
    
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
            name = device.name
            if device.name is None:
                name = device.address
            await self.out_queue.put(SerialData("device_name_found", None, name))
    
    def get_hubnames(self):
        return list(self.hubs.keys())
