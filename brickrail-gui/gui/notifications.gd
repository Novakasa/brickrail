extends VBoxContainer

onready var container = $ScrollContainer/NotificationContainer

func show_more_info(text):
	$AcceptDialog.dialog_text = text
	$AcceptDialog.popup_centered()

func _ready():
	GuiApi.notification_gui = self
	var _err = $ClearButton.connect("pressed", self, "clear_notifications")
	$ClearButton.disabled = true

func clear_notifications():
	for child in container.get_children():
		child.queue_free()
	$ClearButton.disabled=true

func show_notification(text, more_info, type, show_more_immediately=false):
	$ClearButton.disabled=false
	var notification = HBoxContainer.new()
	notification.size_flags_horizontal = SIZE_EXPAND_FILL
	var label = Label.new()
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.autowrap = true
	label.text = text
	if type == "error":
		label.add_color_override("font_color", Color.red)
	if type == "warning":
		label.add_color_override("font_color", Color.yellow)
	notification.add_child(label)
	if more_info != null:
		var button = Button.new()
		button.text = "..."
		button.size_flags_vertical = SIZE_SHRINK_END
		notification.add_child(button)
		var _err = button.connect("pressed", self, "show_more_info", [more_info])
	container.add_child(notification)
	if show_more_immediately:
		show_more_info(more_info)
	
	yield(get_tree(), "idle_frame")
	$ScrollContainer.scroll_vertical = $ScrollContainer.get_v_scrollbar().max_value
