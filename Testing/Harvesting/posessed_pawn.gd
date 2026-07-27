extends CharacterBody2D

@export var speed : float = 180
@export var color : Types.ClassColor = Types.ClassColor.BLACK

@export var pickaxe_damage : float = 20

@onready var tool_hitbox : Area2D = get_node("ToolHitbox")

var animation_locked : bool = false
var interacting_with : Node2D

func _physics_process(delta: float) -> void:
	# Get input.
	var direction : Vector2 = Input.get_vector("left", "right", "up", "down")
	
	# Handle movement and movement animations
	if not animation_locked:
		velocity = direction.normalized() * speed
		
		if velocity.x < -30:
			%AnimatedSprite2D.flip_h = true
		elif velocity.x > 30:
			%AnimatedSprite2D.flip_h = false
		
		if velocity.length() < 20:
			%AnimatedSprite2D.play(Types.get_class_color_name(color) + "_idle")
		else:
			%AnimatedSprite2D.play(Types.get_class_color_name(color) + "_run")
	
	else:
		velocity = Vector2.ZERO
	
	# Handle interaction.
	if Input.is_action_pressed("interact") and not animation_locked:
		if tool_hitbox.has_overlapping_areas():
			interacting_with = tool_hitbox.get_overlapping_areas().front().owner
			
			if not interacting_with.has_method("get_is_harvestable"):
				assert(false)
				interacting_with = null
			
			elif interacting_with.get_is_harvestable():
				var tool : Types.Tool = interacting_with.get_harvesting_tool()
				var tool_name : String = Types.get_tool_name(tool)
				var color_name : String = Types.get_class_color_name(color)
				%AnimatedSprite2D.play(color_name + "_use_" + tool_name)
				
				animation_locked = true
	
	move_and_slide()

# At the end of any animation which does not loop, unfreeze.
func _on_animated_sprite_2d_animation_finished() -> void:
	animation_locked = false
	
	interacting_with.harvest(pickaxe_damage)
