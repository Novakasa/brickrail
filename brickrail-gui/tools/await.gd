extends Node

# inspired by https://github.com/godotengine/godot/issues/21371

class _SignalEmitter:
	signal emitted(signal_name)
	func emit(signal_name):
		emit_signal("emitted", signal_name)

func first_signal(obj, signals):
	var emitter = _SignalEmitter.new()
	for signal_name in signals:
		obj.connect(signal_name, Callable(emitter, "emit").bind(signal_name))
	return await emitter.emitted

func first_signal_objs(objs, signals):
	var emitter = _SignalEmitter.new()
	for i in range(len(signals)):
		var obj = objs[i]
		var signal_name = signals[i]
		obj.connect(signal_name, Callable(emitter, "emit").bind(obj))
	return await emitter.emitted

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
		coroutine.connect("completed", Callable(emitter, "emit").bind(coroutine))
	var completed = await emitter.emitted
	var pending = []
	for coroutine in  coroutines:
		if coroutine != completed.coroutine:
			pending.append(coroutine)
	return {"completed": completed, "pending": pending}

func all(coroutines):
	var emitter = _CoroutineEmitter.new()
	for coroutine in coroutines:
		coroutine.connect("completed", Callable(emitter, "emit").bind(coroutine))
	var completed = []
	for _coroutine in coroutines:
		completed.append(await emitter.emitted)
	return completed

func wait(time):
	await get_tree().create_timer(time).timeout
	return "timeout"

func with_timeout(coroutine, timeout):
	return await any([coroutine, await wait(timeout)])
