import sys
for path in sys.path:
	print(path)

"""
testpaths = ['', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\python38.zip', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\DLLs', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\lib', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail', 'C:\\Users\\lolli\\AppData\\Roaming\\Python\\Python38\\site-packages', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\lib\\site-packages', 'E:\\repos\\pybricksdev', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\lib\\site-packages\\win32', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\lib\\site-packages\\win32\\lib', 'C:\\Users\\lolli\\miniconda3\\envs\\brickrail\\lib\\site-packages\\Pythonwin']
for path in testpaths:
	sys.path.append(path)
"""

from pybricksdev.connections import BLEPUPConnection
from pybricksdev.ble import find_device

from godot import Node, exposed, export

import asyncio

@exposed
class TrainController(Node):

	def __init__(self, address = None):
		self.hub = BLEPUPConnection()
		self.address = address
	
	def _ready(self):
		self.hub = BLEPUPConnection()
		self.address = None
		async def main():
			#await self._discover_address()
			#await self._connect()
			#await self._run()
			address = await find_device("Pybricks Hub")
			await self.hub.connect(address)
			await self.hub.run("train_colors.py")
		loop = asyncio.get_event_loop()
		loop.run_until_complete(main())
		# maintask = asyncio.create_task(main)
	
	async def _discover_address(self, device="Pybricks Hub"):
		self.address = await find_device(device)
		return self.address
	
	async def _connect(self):
		await self.hub.connect(self.address)
	
	async def _run(self):
		await self.hub.run("train_colors.py")
