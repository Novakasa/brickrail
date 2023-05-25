extends Node

var status_gui
var notification_gui

func status_process(message):
	Logger.info("[GuiApi] showing process message: %s" % message)
	status_gui.process(message)
	# notification_gui.show_notification(message, null, "info")

func status_ready(message):
	Logger.info("[GuiApi] showing ready message: %s" % message)
	status_gui.ready(message)

func show_error(message, more_info=null):
	Logger.error("[GuiApi] showing error: %s" % message)
	notification_gui.show_notification(message, more_info, "error")

func show_warning(message, more_info=null):
	Logger.warn("[GuiApi] showing warning: %s" % message)
	notification_gui.show_notification(message, more_info, "warning")

func show_info(message, more_info=null):
	Logger.info("[GuiApi] showing info: %s" % message)
	notification_gui.show_notification(message, more_info, "info")
