extends Node

var status_gui
var error_dialog: AcceptDialog

func status_process(message):
	status_gui.process(message)

func status_ready():
	status_gui.ready()

func show_error(message):
	error_dialog.dialog_text = message
	error_dialog.popup()
