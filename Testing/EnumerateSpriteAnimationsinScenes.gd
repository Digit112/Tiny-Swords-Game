@tool
extends Node

# Given the supplied list of scenes, locate the AnimatedSprite2D within it and list its animations.
# For each animation, instantiate that sprite and play that animation.

@export var scenes : Array[PackedScene]

# Specify prefixes. For each scene, all animations with the given prefix go on their own row.
@export var prefixes : Array[String]

# Path to search within the scene for the AnimatedSprite2D node.
@export var animated_sprite_name : NodePath

# Instantiated scenes are spaced based on the size of the AnimatedSprite2D nodes.
# The below parameters may increase or - with negative numbers - decrease that spacing.

# Adjust spacing between animations from the same sprite.
@export var horizontal_spacing_adjustment : int = 0
@export var vertical_spacing_adjustment : int = 0

# Adjust spacing between rows for different sprites.
@export var block_spacing_adjustment : int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		child.queue_free()
	
	# Indexed as all_animations[scene][prefix][animation]
	var all_animations : Array[Array] = []
	
	for scene in scenes:
		# Instance the provided scene in order to pull the animations from the node.
		var instance : Node = scene.instantiate()
		var animation_node : AnimatedSprite2D = instance.get_node(animated_sprite_name)
		if animation_node == null:
			# Add blank array to ensure alignment of the all_animations and scenes arrays.
			all_animations.append([])
			continue
		
		# Sort all animation names into a dictionary according to their prefix.
		var animation_names_by_prefix : Dictionary[String, Array] = {}
		for animation_name : String in animation_node.sprite_frames.get_animation_names():
			var found_matching_prefix : bool = false
			for prefix in prefixes:
				if animation_name.begins_with(prefix):
					if animation_names_by_prefix.has(prefix):
						animation_names_by_prefix[prefix].append(animation_name)
					else:
						animation_names_by_prefix[prefix] = [animation_name]
					
					found_matching_prefix = true
					break
			
			if not found_matching_prefix:
				if animation_names_by_prefix.has(""):
					animation_names_by_prefix[""].append(animation_name)
				else:
					animation_names_by_prefix[""] = [animation_name]
		
		# The values (each a list of its own) are combined into a single list of all animations in the scene.
		# This is appended to the all_animations list.
		all_animations.append(animation_names_by_prefix.values())
	
	# The all_animations list now a list of all animations from all scenes organized by scene and prefix.
	var cursor = Vector2i(0, 0)
	for block_i in len(all_animations):
		var block : Array[Array] = all_animations[block_i]
		for row in block:
			var dimensions : Vector2i = Vector2i.ZERO
			for animation_name in row:
				var instance : Node = scenes[block_i].instantiate()
				var animation_node : AnimatedSprite2D = instance.get_node(animated_sprite_name)
				instance.global_position = cursor
				animation_node.play(animation_name)
				
				add_child(instance)
				
				dimensions = animation_node.sprite_frames.get_frame_texture(animation_name, 0).get_size()
				cursor += Vector2i(dimensions.x + horizontal_spacing_adjustment, 0)
			
			cursor = Vector2i(0, cursor.y + dimensions.y + vertical_spacing_adjustment)
		
		cursor += Vector2i(0, block_spacing_adjustment)
