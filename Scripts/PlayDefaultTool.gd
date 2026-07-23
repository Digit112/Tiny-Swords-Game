@tool
extends AnimatedSprite2D

@export var animation_name : StringName = "default"

func _enter_tree() -> void:
	play(animation_name)
