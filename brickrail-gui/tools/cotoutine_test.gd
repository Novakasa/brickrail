extends Node2D


func slow_hello():
	yield(get_tree().create_timer(4.0), "timeout")
	print("hello world slow!")


func fast_hello():
	yield(get_tree().create_timer(2.0), "timeout")
	print("hello world fast!")
	return "fast"

func _ready():
	print("testing await with timeout:")
	var val = yield(Await.with_timeout(slow_hello(), 3.0), "completed")
	print(val.completed)
	yield(val.pending[0], "completed")
	print("all are done")
	print("testing await any:")
	val = yield(Await.any([slow_hello(), fast_hello()]), "completed")
	print(val)
	yield(val.pending[0], "completed")
	print("testing await all:")
	var results = yield(Await.all([slow_hello(), fast_hello()]), "completed")
	print(results)
