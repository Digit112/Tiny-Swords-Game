@tool
extends Node2D

## Regenerate the map.
@export_tool_button("Regenerate") var Regenerate = regenerate

## Width of the grid to generate in tiles.
@export var width : int = 32

## Height of the grid to generate in tiles.
@export var height : int = 32

## List of cutoffs between -1 and 1.
## The number of layers is equal to the number of cutoffs specified,
## with all values below the lowest cutoff being water.
@export var cutoffs : Array[float] = [0.5]

## If true, set tiles even if they are obscured by higher terrain.
@export var write_hidden_tiles : bool = true

## The TileSet containing all the usable tiles for map generation.
@export var atlas : TileSet

@export_group("Noise")

## Noise used to generate the terrain color.
## An identical noise object with a diffferent seed is combined with this to
## choose between two color variants.
@export var terrain_color_noise : Noise

## Noise used to generate the terrain.
## Threshholds determine the cutoffs between layers.
@export var terrain_noise : Noise

# Indexed as terrain[row][col] and contains ints.
# The value gives the height of terrain at that index, with 0 being no terrain at all.
var terrain : Array[Array] = []

# The TileMapLayer nodes that make up each successive layer of terrain.
var levels : Array[TileMapLayer]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	regenerate()

func get_bottom_layer_land_tile(
	top_is_land : bool,
	right_is_land : bool,
	bottom_is_land : bool,
	left_is_land : bool
) -> Vector2i:
	if top_is_land:
		if right_is_land:
			if bottom_is_land:
				if left_is_land:
					return Vector2i(1, 1)
				else:
					return Vector2i(0, 1)
			else:
				if left_is_land:
					return Vector2i(1, 2)
				else:
					return Vector2i(0, 2)
		else:
			if bottom_is_land:
				if left_is_land:
					return Vector2i(2, 1)
				else:
					return Vector2i(3, 1)
			else:
				if left_is_land:
					return Vector2i(2, 2)
				else:
					return Vector2i(3, 2)
	else:
		if right_is_land:
			if bottom_is_land:
				if left_is_land:
					return Vector2i(1, 0)
				else:
					return Vector2i(0, 0)
			else:
				if left_is_land:
					return Vector2i(1, 3)
				else:
					return Vector2i(0, 3)
		else:
			if bottom_is_land:
				if left_is_land:
					return Vector2i(2, 0)
				else:
					return Vector2i(3, 0)
			else:
				if left_is_land:
					return Vector2i(2, 3)
				else:
					return Vector2i(3, 3)

func get_upper_layer_land_tile(
	top_is_land : bool,
	right_is_land : bool,
	bottom_is_land : bool,
	left_is_land : bool
) -> Vector2i:
	return get_bottom_layer_land_tile(
		top_is_land,
		right_is_land,
		bottom_is_land,
		left_is_land
	) + Vector2i(5, 0)

func get_bottom_layer_pillar_tile(
	left_is_land : bool,
	right_is_land : bool
) -> Vector2i:
	if left_is_land:
		if right_is_land:
			return Vector2i(6, 5)
		else:
			return Vector2i(7, 5)
	else:
		if right_is_land:
			return Vector2i(5, 5)
		else:
			return Vector2i(8, 5)

func get_upper_layer_pillar_tile(
	left_is_land : bool,
	right_is_land : bool
) -> Vector2i:
	return get_bottom_layer_pillar_tile(
		left_is_land,
		right_is_land
	) + Vector2i(0, -1)

func regenerate() -> void:
	assert(
		_are_cutoffs_valid(),
		"Cutoffs must be arranged from least to greatest and be between -1 and 1 (inclusive)."
	)
	
	for child in get_children():
		child.queue_free()
	
	var noise : Image = terrain_noise.get_image(width, height)
	var noise_width : int = noise.get_width()
	var noise_format : Image.Format = noise.get_format()
	var noise_data : PackedByteArray = noise.get_data()
	var accessor : Callable = func(): assert(false)
	
	# Assign a function to obtain values from the raw data and convert them to a float in the range -1 to 1.
	# Float and half-based images are presumbed to already be in this range and are clamped.
	match noise_format:
		Image.Format.FORMAT_L8:
			accessor = func(x : int, y : int, data : PackedByteArray) -> float:
				return data.decode_u8(y*noise_width+x) as float / 255 * 2 - 1
		Image.Format.FORMAT_RF:
			accessor = func(x : int, y : int, data : PackedByteArray) -> float:
				return clamp(data.decode_float(y*noise_width+x) as float, -1, 1)
		Image.Format.FORMAT_RH:
			accessor = func(x : int, y : int, data : PackedByteArray) -> float:
				return clamp(data.decode_half(y*noise_width+x) as float, -1, 1)
		_:
			print("I don't understand the image format '{0}'. Ask ekobadd to add support.".format([noise_format]))
			assert(false)
	
	# TODO: Replace this terrain matrix with a packed int array for space and performance reasons.
	terrain = []
	for x : int in width:
		terrain.append([])
		for y : int in height:
			var sample : float = accessor.call(x, y, noise_data)
			var did_find_level : bool = false
			for i : int in len(cutoffs):
				if sample < cutoffs[i]:
					terrain[-1].append(i)
					did_find_level = true
					break
			
			if not did_find_level:
				terrain[-1].append(len(cutoffs))
	
	levels = []
	for level in len(cutoffs):
		var new_level : TileMapLayer = TileMapLayer.new()
		levels.append(new_level)
		
		new_level.tile_set = atlas
		new_level.position -= Vector2(0, atlas.tile_size.y) * level # Raise terrain.
		
		add_child(new_level)
		
		# Set plain land tiles.
		for x : int in width:
			for y : int in height:
				if terrain[x][y] == level + 1:
					var top_is_land    : bool = y > 0        and terrain[x  ][y-1] >= level + 1
					var right_is_land  : bool = x < width-1  and terrain[x+1][y  ] >= level + 1
					var bottom_is_land : bool = y < height-1 and terrain[x  ][y+1] >= level + 1
					var left_is_land   : bool = x > 0        and terrain[x-1][y  ] >= level + 1
					
					var atlas_coords : Vector2i
					if level == 0:
						atlas_coords = get_bottom_layer_land_tile(top_is_land, right_is_land, bottom_is_land, left_is_land)
					else:
						atlas_coords = get_upper_layer_land_tile(top_is_land, right_is_land, bottom_is_land, left_is_land)
					
					new_level.set_cell(Vector2i(x, y), 1, atlas_coords)
		
		# Set pillar tiles
		for x : int in width:
			for y : int in range(1, height):
				if terrain[x][y] < terrain[x][y-1]:
					pass

func _are_cutoffs_valid() -> bool:
	# Allows margin of error for floating-point imprecision.
	const epsilon = 0.0000001
	
	for cutoff in cutoffs: # Between -1 and 1 (inclusive)
		if cutoff < -1 - epsilon or cutoff > 1 + epsilon:
			return false
	
	for i in range(1, len(cutoffs)): # Monotonically ascending.
		if cutoffs[i] - cutoffs[i-1] < -epsilon:
			return false
	
	return true
