@tool
extends AnimatedSprite2D

# Play the default animation.
# If not in the editor and the animation doesn't loop, delete the node when it ends.

@export var animation_name : StringName = "default"

func _enter_tree() -> void:
	animation_finished.connect(_on_animation_end)
	play(animation_name)

func _on_animation_end() -> void:
	if not Engine.is_editor_hint():
		queue_free()

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if what == NOTIFICATION_EDITOR_PRE_SAVE:
			stop()
		elif what == NOTIFICATION_EDITOR_POST_SAVE:
			play(animation_name)
