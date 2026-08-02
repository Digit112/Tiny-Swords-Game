@tool
extends Node2D

## Regenerate the map.
@export_tool_button("Regenerate") var Generate = generate

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
@export var tile_set : TileSet

@export_group("Noise")

## Noise used to generate the terrain color.
## An identical noise object with a diffferent seed is combined with this to
## choose between two color variants.
@export var terrain_color_noise : Noise

## Noise used to generate the terrain.
## Threshholds determine the cutoffs between layers.
@export var terrain_noise : Noise

enum LayerPurpose {
	LAND, # Contains flat tiles and stairs
	WALL  # Contains walls supporting LAND tiles on the same level.
}

enum CardinalAlignment {
	NORTH_SOUTH,
	EAST_WEST
}

# Indexed as terrain[row][col] and contains ints.
# The value gives the height of terrain at that index, with 0 being no terrain at all.
var terrain : Array[Array] = []

# The TileMapLayer nodes that make up each successive layer of terrain.
var layers : Array[TileMapLayer]

# GENERATOR RULES

# The model of the generated world is a fully 3D voxel space, mostly represented by a eightmap.
# The heightmap determines the terrain height,
# with -1 being a water-only tile and 0 being the lowest land tile.
#
# Each cell, identified with an x and y coordinate, cooresponds to a TerrainPillar entity.
# A pillar has four neighbors: north, south, east, and west.
# A TerrainPillar has an integer height and a "form",
# which determines the cap tile and first supporting tile to use.
# The cap tile is the tile at the top of the pillar, either flat or one of four ramps.
#
# For each level in the heigtmap, we spawn two TileMapLayer entities:
# The higher of the two contains the cap tiles for that layer,
# the lower of the two contains the first supporting tile for that layer's cap tiles.
# Each layer is shifted up according to its height, and supporting layers are shifted down one tile.
#     This means that all tiles placed for any given pillar are at the same coordinate
#     relative to the layers they're on.
#
# Flat cap tiles connect to all neighbors of the same height or higher.
# Flat tiles are also placed on the layer immediately beneath supporting tiles,
#     this prevents visual leakage from lower layers.
# These "backing" flat tiles also connect to neighbors at or above their level.
#
# There are four ramp variants, categorized by the direction you travel across them to go up:
# North, South, East, West.
# They are taken to belong to the higher of the two layers they connect.
# So if a ramp allows traversing between layers 0 and 1, it is on layer 1.
# Threfore, the lowest level aa ramp can be is 1.
#
# East, West, and North ramps have a double-height representation.
# The upper half of East and West is really the cap and the lower half is the support.
# South ramps are represented by a pair of normal flat tiles, a cap and a support,
# each connected above and below.
#
# South ramps are special. With an isometric camera angled down and into them,
# they become infinitely thin, and characters traversing them appear stationary
# (as they are moving exactly towards or away from the isometric caamera)
# South ramps have no cap tile and no supporting tilew. The spaces are left blank.
#
# East-West ramps cannot be connected to by tiles on the same layer from the north or south.
# North-South ramps cannot be connected to by tiles on the same layer from the east or west.

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate()

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

func get_pillar_tile(
	left_is_land : bool,
	right_is_land : bool
) -> Vector2i:
	if left_is_land:
		if right_is_land:
			return Vector2i(6, 4)
		else:
			return Vector2i(7, 4)
	else:
		if right_is_land:
			return Vector2i(5, 4)
		else:
			return Vector2i(8, 4)

func get_land_tile(
	is_bottom_layer : bool,
	top_is_land : bool,
	right_is_land : bool,
	bottom_is_land : bool,
	left_is_land : bool
) -> Vector2i:
	if is_bottom_layer:
		return get_bottom_layer_land_tile(top_is_land, right_is_land, bottom_is_land, left_is_land)
	else:
		return get_upper_layer_land_tile(top_is_land, right_is_land, bottom_is_land, left_is_land)

## Deleted all TileMapLayer nodes.
func clear_render() -> void:
	for layer in layers:
		layer.queue_free()
	
	layers = []

## Delete generated terrain.
func clear_terrain() -> void:
	terrain = []

## Generate sufficient TileMapLayer nodes to hold the terrain.
func regenerate_blank_layers() -> void:
	clear_render()
	
	for i : int in len(cutoffs):
		if i > 0:
			var supporting_layer := TileMapLayer.new()
			
			supporting_layer.tile_set = tile_set
			supporting_layer.position -= Vector2(0, tile_set.tile_size.y) * (i - 1) # Raise terrain.
			
			layers.append(supporting_layer)
			add_child(supporting_layer)
		
		var land_layer := TileMapLayer.new()
		
		land_layer.tile_set = tile_set
		land_layer.position -= Vector2(0, tile_set.tile_size.y) * i # Raise terrain.
		
		layers.append(land_layer)
		add_child(land_layer)

## Sets the necessary tiles to render the pillar at the given position.
## This includes the flat or ramp tiles and all necessary supporting and backing tiles.
func render_pillar(pillar_position : Vector2i) -> void:
	var pillar := get_pillar(pillar_position)
	assert(pillar != null)
	
	if pillar.height == -1:
		return
	
	var north_neighbor := get_north_neighbor(pillar_position)
	var south_neighbor := get_south_neighbor(pillar_position)
	var west_neighbor := get_west_neighbor(pillar_position)
	var east_neighbor := get_east_neighbor(pillar_position)
	
	var max_depth : int = pillar.height
	if south_neighbor != null and south_neighbor.height > -1:
		max_depth = pillar.height - south_neighbor.height
	
	for depth in max_depth+1:
		var level := pillar.height - depth
		var land_layer := get_layer(level, LayerPurpose.LAND)
		
		var connect_north := do_connect(pillar, north_neighbor, depth, CardinalAlignment.NORTH_SOUTH)
		var connect_south := do_connect(pillar, south_neighbor, depth, CardinalAlignment.NORTH_SOUTH)
		var connect_east  := do_connect(pillar, east_neighbor,  depth, CardinalAlignment.EAST_WEST)
		var connect_west  := do_connect(pillar, west_neighbor,  depth, CardinalAlignment.EAST_WEST)
		
		var flat_tile := get_land_tile(
			level == 0, connect_north, connect_east, connect_south, connect_west
		)
		
		land_layer.set_cell(
			pillar_position,
			1,
			flat_tile
		)
		
		if depth < max_depth:
			var wall_layer := get_layer(level, LayerPurpose.WALL)
			
			var connet_wall_west := do_connect_support(pillar, west_neighbor, depth)
			var connet_wall_east := do_connect_support(pillar, east_neighbor, depth)
			
			var wall_tile := get_pillar_tile(connet_wall_west, connet_wall_east)
			
			wall_layer.set_cell(
				pillar_position,
				1,
				wall_tile
			)

## Returns the pillar at the specified position.
## Returns null if the specified position is outside the bounds of the map.
func get_pillar(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.x < 0 or pillar_position.x >= width:
		return null
	if pillar_position.y < 0 or pillar_position.y >= height:
		return null
	
	return terrain[pillar_position.y][pillar_position.x]

func get_layer(level : int, purpose : LayerPurpose) -> TileMapLayer:
	assert(level >= 0, "Level must not be negative.")
	assert(not (level == 0 and purpose == LayerPurpose.WALL), "Level 0 has no support layer.")
	
	var index := level * 2
	if purpose == LayerPurpose.WALL:
		index -= 1
	
	return layers[index]

## Returns true if the land tile at the given depth below pillar1
## should connect in the direction of pillar2.
## A depth of 0 refers to the cap. 
## Has no information about the pillars' actual positions and assumes they are adjacent.
func do_connect(
	pillar1 : TerrainPillar,
	pillar2 : TerrainPillar,
	depth : int,
	alignment : CardinalAlignment
) -> bool:
	assert(depth >= 0)
	assert(pillar1 != null)
	
	if pillar2 == null:
		return false
	
	if pillar1.height - depth < pillar2.height:
		return true
		
	if pillar1.height - depth == pillar2.height:
		if pillar2.is_flat():
			return true
		
		elif pillar2.is_east_west_ramp():
			if alignment == CardinalAlignment.EAST_WEST:
				return true
		else:
			assert(pillar2.is_noth_south_ramp(), "Possible form not accounted for.")
			if alignment == CardinalAlignment.NORTH_SOUTH:
				return true
			
			# North ramps can connect to eachother
			elif depth == 0 and pillar1.form == TerrainPillar.Form.RAMP_NORTH and pillar2.form == TerrainPillar.Form.RAMP_NORTH:
				return true
		
	return false

## Returns true if the support at the given depth under pillar1 should connect to pillar2.
## A depth of 0 refers to the highest support in the pillar, right below the cap.
## Has no information about the pillars' actual positions and assumes they are adjacent.
func do_connect_support(
	pillar1 : TerrainPillar,
	pillar2 : TerrainPillar,
	depth : int
) -> bool:
	assert(pillar1 != null)
	assert(pillar1.height - depth > 0)
	
	if pillar2 == null:
		return false
	
	return pillar1.height - depth <= pillar2.height

func get_north_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.y > 0:
		return get_pillar(pillar_position + Vector2i(0, -1))
	
	return null

func get_south_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.y < height-1:
		return get_pillar(pillar_position + Vector2i(0, 1))
	
	return null

func get_west_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.x > 0:
		return get_pillar(pillar_position + Vector2i(-1, 0))
	
	return null

func get_east_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.x < width-1:
		return get_pillar(pillar_position + Vector2i(1, 0))
	
	return null

func generate() -> void:
	#regenerate_old()
	#return
	
	regenerate_blank_layers()
	regenerate_terrain()
	
	for x : int in width:
		for y : int in height:
			render_pillar(Vector2i(x, y))
	

func regenerate_terrain() -> void:
	assert(
		_are_cutoffs_valid(),
		"Cutoffs must be arranged from least to greatest and be between -1 and 1 (inclusive)."
	)
	
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
			
			# Set terrain height according to sample and cutoffs.
			var did_find_level : bool = false
			for i : int in len(cutoffs):
				if sample < cutoffs[i]:
					terrain[-1].append(
						TerrainPillar.new(i-1, TerrainPillar.Form.FLAT, 1)
					)
					
					did_find_level = true
					break
			
			if not did_find_level:
				terrain[-1].append(
					TerrainPillar.new(len(cutoffs)-1, TerrainPillar.Form.FLAT, 1)
				)

func regenerate_old() -> void:
	regenerate_blank_layers()
	regenerate_terrain()
	
	for level in len(cutoffs):
		# Set land tiles.
		for x : int in width:
			for y : int in height:
				if terrain[x][y].height >= level + 1:
					var top_is_land    : bool = y > 0        and terrain[x  ][y-1].height  >= level + 1
					var right_is_land  : bool = x < width-1  and terrain[x+1][y  ].height  >= level + 1
					var bottom_is_land : bool = y < height-1 and terrain[x  ][y+1].height  >= level + 1
					var left_is_land   : bool = x > 0        and terrain[x-1][y  ].height  >= level + 1
					
					var atlas_coords := get_land_tile(level == 0, top_is_land, right_is_land, bottom_is_land, left_is_land)
					
					get_layer(level, LayerPurpose.LAND).set_cell(Vector2i(x, y), 1, atlas_coords)
	
	# Set pillar tiles
	for x : int in width:
		for y : int in range(0, height):
			if (y == height-1 or terrain[x][y].height > terrain[x][y+1].height) and terrain[x][y].height > 1:
				var target_height : int = 1
				if y < height - 1:
					target_height = terrain[x][y+1].height
				
				for i : int in terrain[x][y].height - target_height:
					var left_is_land  : bool = x > 0       and terrain[x-1][y].height >= terrain[x][y].height - i
					var right_is_land : bool = x < width-1 and terrain[x+1][y].height >= terrain[x][y].height - i
					
					var level = terrain[x][y].height - 1 - i
					var atlas_coords : Vector2i
					atlas_coords = get_pillar_tile(left_is_land, right_is_land)
					
					get_layer(level, LayerPurpose.WALL).set_cell(
						Vector2i(x, y),
						1,
						atlas_coords
					)

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
