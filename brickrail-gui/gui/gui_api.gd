extends Node

var status_gui

func status_process(message):
	Logger.info("[GuiApi] showing process message: %s" % message)
	status_gui.process(message)

func status_ready(message):
	Logger.info("[GuiApi] showing ready message: %s" % message)
	status_gui.ready(message)

func show_error(message):
	Logger.error("[GuiApi] showing error: %s" % message)
	status_gui.error(message)
