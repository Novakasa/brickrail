extends Node

class _Emitter:
	signal emitted(object)
	func emit(object):
		emit_signal("emitted", object)


func await_any_signal(args):
	assert(len(args) % 2 == 0)
	var emitter = _Emitter.new()
	for i in range(0, len(args), 2):
		var object = args[i]
		var signal_name = args[i + 1]
		object.connect(signal_name, emitter, "emit", [object])
	return yield(emitter, 'emitted')

func await_all_signals(args):
	assert(len(args) % 2 == 0)
	var emitter = _Emitter.new()
	for i in range(0, len(args), 2):
		var object = args[i]
		var signal_name = args[i + 1]
		object.connect(signal_name, emitter, "emit", [object])
	var objs = []
	for _i in range(0, len(args), 2):
		objs.append(yield(emitter, 'emitted'))
	return objs

func any(coroutines: Array):
	var args = []
	for coroutine in coroutines:
		args.append(coroutine)
		args.append("completed")
	return yield(call("await_any_signal", args), "completed")

func all(coroutines: Array):
	var args = []
	for coroutine in coroutines:
		args.append(coroutine)
		args.append("completed")
	return yield(call("await_all_signals", args), "completed")

func wait(time):
	yield(get_tree().create_timer(time), "timeout")
	return "timeout"

func yield_with_timeout(coroutine, timeout):
	return yield(any([coroutine, wait(timeout)]), "completed")

