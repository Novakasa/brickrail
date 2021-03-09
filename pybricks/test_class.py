from godot import Node, exposed, export

@exposed
class TestClass(Node):

	def _ready(self):
		print("hello world")
