extends AnimatedSprite2D

var animation_timer : float = 0.0
@export var vein_health : float = 40

@export var is_harvestable : bool = true
@export var harvesting_tool : Types.Tool

@export var dropped_item : PackedScene
@export var min_drops : int = 0
@export var max_drops : int = 0

@export var replaced_with : Array[PackedScene]

func _ready() -> void:
	animation_timer = randf_range(5, 10)

func _process(delta: float) -> void:
	animation_timer = animation_timer - delta
	
	if animation_timer <= 0.0:
		animation_timer = randf_range(5, 10)
		play("default")

func get_is_harvestable() -> bool:
	return is_harvestable
	
func get_harvesting_tool() -> Types.Tool:
	return harvesting_tool
	
func harvest(damage : float) -> void:
	vein_health = vein_health - damage
	if vein_health <= 0:
		queue_free()
		
		if dropped_item != null:
			var num_drops : int = randi_range(min_drops, max_drops)
			for i in num_drops:
				var drop : Node2D = dropped_item.instantiate()
				get_tree().current_scene.add_child(drop)
				
				drop.global_position = global_position
				
				var random_angle = randf() * PI * 2
				var random_dist = randf_range(40, 100)
				
				var start_pos = global_position
				var target_pos = start_pos + Vector2(cos(random_angle), sin(random_angle)) * random_dist
				
				var peak_pos = start_pos + (target_pos - start_pos) / 2 + Vector2(0, -30)
				
				var pop_up_height_tween : Tween = get_tree().create_tween()
				var position_tween : Tween = get_tree().create_tween()
				drop.pop_up_height = 0
				pop_up_height_tween.tween_property(drop, "pop_up_height", -30, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				pop_up_height_tween.tween_property(drop, "pop_up_height", 0,   0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				
				position_tween.tween_method(
					func(t : float):
						drop.global_position = lerp(start_pos, target_pos, t) + Vector2(0, drop.pop_up_height),
					0.0, 1.0, 0.4
				)
