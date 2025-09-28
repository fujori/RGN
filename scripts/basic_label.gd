extends Label

func _process(_delta: float) -> void:
	text = str(Performance.get_monitor(Performance.TIME_FPS)) # Выводит значение FPS на консоль.
