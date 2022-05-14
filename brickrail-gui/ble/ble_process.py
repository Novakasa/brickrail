import subprocess
import os

from godot import Node, exposed, export

@exposed
class BLEProcess(Node):

	def _ready(self):
		print("python ble_process is working!")

	def start_process(self):
		print("executing python based ble control server")
		# os.chdir("../")
		subprocess.run("start cmd /K ble-server\.env\python.exe ble-server/ble_server.py", shell=True)
