@tool
extends AnimatedSprite2D

@export var animation_name : StringName = "default"

func _enter_tree() -> void:
	play(animation_name)

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if what == NOTIFICATION_EDITOR_PRE_SAVE:
			stop()
		elif what == NOTIFICATION_EDITOR_POST_SAVE:
			play(animation_name)
