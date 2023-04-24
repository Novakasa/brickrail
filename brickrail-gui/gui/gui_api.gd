extends Node

var status_gui

func status_process(message):
	status_gui.process(message)

func status_ready(message):
	status_gui.ready(message)

func show_error(message):
	status_gui.error(message)
