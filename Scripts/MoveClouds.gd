@tool
extends Sprite2D

@export var speed : Vector2 = Vector2(-12, 0)

func _process(delta: float) -> void:
	position += speed * delta
