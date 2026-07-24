extends Node

# Scenes to generate as clouds.
@export var clouds : Array[PackedScene]

# Cloud velocity in pixels per second.
@export var cloud_vel : Vector2 = Vector2(-10, 0)



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
