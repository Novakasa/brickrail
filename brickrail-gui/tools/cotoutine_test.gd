extends Node2D


func slow_hello():
	print("hello")
	yield(get_tree().create_timer(4.0), "timeout")
	print("world")
	return "slow"

func fast_hello():
	print("fast")
	yield(get_tree().create_timer(2.0), "timeout")
	print("hellofast")
	return "fast"

func _ready():
	print("testing coroutine")
	
	# var val = yield(Coroutines.yield_with_timeout(slow_hello(), 3.0), "completed")
	# print(val)

	var val = yield(Coroutines.await_any_signal([slow_hello(), "completed", fast_hello(), "completed"]), "completed")
	print(val)
