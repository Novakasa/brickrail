import asyncio

from pybricksdev.ble import find_device
from pybricksdev.connections.pybricks import PybricksHub


class BLEHub:

    def __init__(self):

        self.hub = PybricksHub()