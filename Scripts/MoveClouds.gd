@tool
extends Sprite2D

@export var speed : int = 10

func _process(delta: float) -> void:
	position.x = position.x - speed * delta
