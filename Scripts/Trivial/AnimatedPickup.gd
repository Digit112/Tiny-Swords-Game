extends AnimatedSprite2D

# Used for gold pickups that have glisten animations

var pop_up_height : float = 0

var animation_timer : float

func _ready() -> void:
	animation_timer = randf_range(5, 10)

func _process(delta: float) -> void:
	animation_timer = animation_timer - delta
	
	if animation_timer <= 0.0:
		animation_timer = randf_range(5, 10)
		play("default")
