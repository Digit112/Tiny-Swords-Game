extends CharacterBody2D

# In tiles per second.
@export var speed := 5

@onready var nav_agent : TerrainNavAgent = $TerrainNavAgent

func _ready() -> void:
	nav_agent.location = Vector2(32, 32)

func _physics_process(delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		nav_agent.velocity = direction * speed
	else:
		nav_agent.velocity = Vector2.ZERO
	
	nav_agent.move_and_slide(delta)
	position = nav_agent.get_iso_projected_position()
