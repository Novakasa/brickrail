extends Node

class _Emitter:
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
	var emitter = _Emitter.new()
	for coroutine in coroutines:
		coroutine.connect("completed", emitter, "emit", [coroutine])
	var completed = yield(emitter, 'emitted')
	var pending = []
	for coroutine in  coroutines:
		if coroutine != completed.coroutine:
			pending.append(coroutine)
	return {"completed": completed, "pending": pending}

func all(coroutines):
	var emitter = _Emitter.new()
	for coroutine in coroutines:
		coroutine.connect("completed", emitter, "emit", [coroutine])
	var completed = []
	for _coroutine in coroutines:
		completed.append(yield(emitter, 'emitted'))
	return completed

func wait(time):
	yield(get_tree().create_timer(time), "timeout")
	return "timeout"

func with_timeout(coroutine, timeout):
	return yield(any([coroutine, wait(timeout)]), "completed")
