import subprocess

from godot import Node, exposed, export

@exposed
class BLEProcess(Node):

	def _ready(self):
		print("python ble_process is working!")

	def start_process(self):
		print("executing python based ble control server")
		subprocess.run("start cmd /K C:/Users/Lolli/miniconda3/envs/brickrail/python.exe E:/repos/brickrail/ble_server.py", shell=True)
