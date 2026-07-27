extends Node2D

@export var gold_item : PackedScene

var continuously_hitting = false

func _physics_process(delta: float) -> void:
	if %Hurtbox.has_overlapping_areas():
		print("Overlapping")
		if not continuously_hitting:
			continuously_hitting = true
			var instance : Sprite2D = gold_item.instantiate()
			instance.position = Vector2(
				randf()*100-50,
				randf()*100-50
			)
			add_child(instance)
	
	else:
		continuously_hitting = false
