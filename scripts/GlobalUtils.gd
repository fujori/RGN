# GlobalUtils.gd
extends Node

# Глобальный метод таймера
func run_after(ms: int, callback: Callable) -> void:
	var timer = Timer.new()
	timer.wait_time = ms / 1000.0
	timer.one_shot = true
	add_child(timer)
	timer.start()
	
	timer.timeout.connect(func():
		callback.call()
		timer.queue_free()
	)
