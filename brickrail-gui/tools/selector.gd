@tool
class_name Selector
extends OptionButton

@export var has_none: bool = true
@export var none_label: String = "None"
@export var none_meta: String = "None"

signal meta_selected(meta)

func _ready():
	var _err = connect("item_selected", Callable(self, "_on_item_selected"))

func _on_item_selected(idx):
	emit_signal("meta_selected", get_item_metadata(idx))

func select_meta(meta):
	select(get_meta_index(meta))

func add_meta_item(label, meta):
	add_item(label)
	var index = get_item_count()-1
	set_item_metadata(index, meta)

func get_meta_index(meta):
	for i in range(get_item_count()):
		if get_item_metadata(i) == meta:
			return i

func set_items(labels, meta):
	var selected_meta = get_selected_metadata()
	clear()
	if has_none:
		add_meta_item(none_label, none_meta)
	for i in range(len(labels)):
		add_meta_item(labels[i], meta[i])
	if selected_meta != null:
		if get_meta_index(selected_meta) != null:
			select_meta(selected_meta)
