extends CharacterBody2D

var speed : float = 40
var direction : Vector2 = Vector2(1, 0)
@export var walking_animation : StringName = "walk"
@export var idle_animation : StringName = "idle"
var is_currently_walking : bool = true
var decision_timer : float = 0.0

@onready var animator : AnimatedSprite2D = %Turtle

func _ready() -> void:
	animator.play(animator.animation)

func _physics_process(delta: float) -> void:
	decision_timer = decision_timer - delta
	
	if decision_timer <= 0:
		is_currently_walking = randi() % 2 == 0
		decision_timer = 5.0
		
		if is_currently_walking:
			var available_directions = [Vector2(1, 1).normalized(), Vector2(1, 0), Vector2(1, -1).normalized(), Vector2(0, -1), Vector2(-1, -1).normalized(), Vector2(-1, 0), Vector2(-1, 1).normalized(), Vector2(0, 1)]
			direction = available_directions.pick_random()
			
			if direction.x < 0:
				animator.flip_h = true
			else:
				animator.flip_h = false
			
			if animator.animation != walking_animation:
				animator.play(walking_animation)
		
		else:
			if animator.animation != idle_animation:
				animator.play(idle_animation)
	
	if is_currently_walking:
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
