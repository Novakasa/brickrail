class_name Utils
extends RefCounted

const LOG_LEVEL_ALL = 999
const LOG_LEVEL_FINE = 700
const LOG_LEVEL_TRACE = 600
const LOG_LEVEL_DEBUG = 500
const LOG_LEVEL_INFO = 400
const LOG_LEVEL_WARN = 200
const LOG_LEVEL_ERROR = 100
const LOG_LEVEL_FATAL = 001
const LOG_LEVEL_NONE = 000

#	Function: get_formatted_date
#	Function: get_formatted_date
#		Returns a Date in a Formatted form for an Event.
static func get_formatted_date(date : Dictionary):
	return "%02d/%02d/%02d %02d:%02d:%02d" % [date.month, date.day, date.year, date.hour, date.minute, date.second]


static func get_level_name(level : int ):
	match level:
		LOG_LEVEL_ALL:
			return "ALL"
		LOG_LEVEL_FINE:
			return "FINE"
		LOG_LEVEL_TRACE:
			return "TRACE"
		LOG_LEVEL_DEBUG:
			return "DEBUG"
		LOG_LEVEL_INFO:
			return "INFO"
		LOG_LEVEL_WARN:
			return "WARN"
		LOG_LEVEL_ERROR:
			return "ERROR"
		LOG_LEVEL_FATAL:
			return "FATAL"
		_:
			return "NONE"

