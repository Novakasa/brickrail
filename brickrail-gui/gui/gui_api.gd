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

func show_error(message, more_info=null, show_more_immediately=false):
	Logger.error("[GuiApi] showing error: %s" % message)
	notification_gui.show_notification(message, more_info, "error", show_more_immediately)

func show_warning(message, more_info=null, show_more_immediately=false):
	Logger.warn("[GuiApi] showing warning: %s" % message)
	notification_gui.show_notification(message, more_info, "warning", show_more_immediately)

func show_info(message, more_info=null, show_more_immediately=false):
	Logger.info("[GuiApi] showing info: %s" % message)
	notification_gui.show_notification(message, more_info, "info", show_more_immediately)
