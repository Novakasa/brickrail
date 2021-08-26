extends VBoxContainer


var block

func set_block(p_block):
	block = p_block
	block.connect("unselected", self, "_on_block_unselected")

func _on_block_unselected():
	queue_free()
