#
#Class: PatternLayout
#	A Flexible Layout with a Pattern String.
#

class_name PatternLayout
extends Layout


const LOG_FORMAT_SIMPLE = 20
const LOG_FORMAT_DEFAULT = 30
const LOG_FORMAT_MORE = 90
const LOG_FORMAT_FULL = 99
const LOG_FORMAT_NONE = -1


func build(message: Message, format: int):

	match format:

		LOG_FORMAT_DEFAULT:
			return "%-10s %-8d %s" % [Utils.get_level_name(message.level), message.line, message.text]
		LOG_FORMAT_FULL:
			return "%s %-8s %-8s %-8d %s" % [Utils.get_formatted_date(Time.get_datetime_dict_from_system()), message.category.to_upper(), Utils.get_level_name(message.level), message.line, message.text]
		LOG_FORMAT_MORE:
			var uptime = Time.get_ticks_msec()/1000.0
			return "%-8s %-8s %s" % [Utils.get_level_name(message.level), uptime, message.text]
			# return "%s %-8s %-8d %s" % [Utils.get_formatted_date(OS.get_datetime()), Utils.get_level_name(message.level), message.line, message.text]
		LOG_FORMAT_NONE:
			return message.text
		LOG_FORMAT_SIMPLE:
			return "%-8d %s" % [message.line, message.text]
		_:
			return "%-8s %s" % [Utils.get_formatted_date(Time.get_datetime_dict_from_system()), message.text]
