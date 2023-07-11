extends Node2D

signal signal_a
signal signal_b

func slow_hello():
	await get_tree().create_timer(4.0).timeout
	print("hello world slow!")


func fast_hello():
	await get_tree().create_timer(2.0).timeout
	print("hello world fast!")
	return "fast"

func send_signals():
	await Await.wait(1.0).completed
	emit_signal("signal_a")
	await Await.wait(1.0).completed
	emit_signal("signal_b")

func _ready():
	print("testing await with timeout:")
	var val = await Await.with_timeout(slow_hello(), 3.0).completed
	print(val.completed)
	await val.pending[0].completed
	print("all are done")
	print("testing await any:")
	val = await Await.any([slow_hello(), fast_hello()]).completed
	print(val)
	await val.pending[0].completed
	print("testing await all:")
	var results = await Await.all([slow_hello(), fast_hello()]).completed
	print(results)
	print("testing await first signal:")
	send_signals()
	var signalname = await Await.first_signal(self, ["signal_a", "signal_b"]).completed
	prints("first signal:", signalname)
