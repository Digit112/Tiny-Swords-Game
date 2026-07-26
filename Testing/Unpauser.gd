extends Node

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().paused = false
