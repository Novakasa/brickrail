extends Node

# inspired by https://github.com/godotengine/godot/issues/21371

class _SignalEmitter:
	signal emitted(signal_name)
	func emit(signal_name):
		emit_signal("emitted", signal_name)

func first_signal(obj, signals):
	var emitter = _SignalEmitter.new()
	for signal_name in signals:
		obj.connect(signal_name, emitter, "emit", [signal_name])
	return yield(emitter, "emitted")

func first_signal_objs(objs, signals):
	var emitter = _SignalEmitter.new()
	for i in range(len(signals)):
		var obj = objs[i]
		var signal_name = signals[i]
		obj.connect(signal_name, emitter, "emit", [obj])
	return yield(emitter, "emitted")

class _CoroutineEmitter:
	signal emitted(done_coroutine)
	func emit(result, coroutine=null):
		var done_coroutine
		if coroutine == null:
			coroutine = result
			done_coroutine = {"coroutine": coroutine}
		else:
			done_coroutine = {"coroutine": coroutine, "result": result}
		emit_signal("emitted", done_coroutine)

func any(coroutines):
	var emitter = _CoroutineEmitter.new()
	for coroutine in coroutines:
		coroutine.connect("completed", emitter, "emit", [coroutine])
	var completed = yield(emitter, 'emitted')
	var pending = []
	for coroutine in  coroutines:
		if coroutine != completed.coroutine:
			pending.append(coroutine)
	return {"completed": completed, "pending": pending}

func all(coroutines):
	var emitter = _CoroutineEmitter.new()
	for coroutine in coroutines:
		coroutine.connect("completed", emitter, "emit", [coroutine])
	var completed = []
	for _coroutine in coroutines:
		completed.append(yield(emitter, "emitted"))
	return completed

func wait(time):
	yield(get_tree().create_timer(time), "timeout")
	return "timeout"

func with_timeout(coroutine, timeout):
	return yield(any([coroutine, wait(timeout)]), "completed")
