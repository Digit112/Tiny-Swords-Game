@tool
class_name TerrainGenerator extends Node2D

# TODO: Split responsibility into TerrainGenerator and TerrainRenderer
# TODO: Stop this from being a tool script and make it a resource.

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

@export_group("Terrain Forms")

## The tile which is used as the supporting entity for columns.
## When a pillar raises above the ground to its immediate south,
## support entities are rendered as needed to connect it to the ground.
@export var support_form : TerrainForm

## Forms which can be randomly selected as the forms assigned to pillars.
## These entities are rendered at the tops of pillars.
## An entity is two tiles tall,
##     consisting of a land tile (top half) and wall tile (bottom half)
## The wall (or support) tile is rendered below the land tile if it is not
##     obscured by the southward terrain.
@export var cap_forms : Array[TerrainForm]

@export_group("Noise")

## Noise used to generate the terrain color.
## An identical noise object with a different seed is combined with this to
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

enum CardinalDirection {
	NORTH,
	SOUTH,
	EAST,
	WEST
}

# Indexed as terrain[row][col] and contains ints.
# The value gives the height of terrain at that index, with 0 being no terrain at all.
var terrain : Array[Array] = []

# The TileMapLayer nodes that make up each successive layer of terrain.
var layers : Array[TileMapLayer] = []

# A cache of whether a tile at the given coords is opaque
var opaque_cache : Dictionary[Vector2i, bool] = {}

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

## Generates the 3D world and then renders it using the provided TileSet and other settings.
## Deletes any existing terrain and layers entirely before generating.
func generate() -> void:
	# Generate world
	generate_terrain()
	_debug_print_terrain()
	
	# Render
	generate_blank_layers()
	for x : int in width:
		for y : int in height:
			render_pillar(Vector2i(x, y))

## Regenerates the underlying 3D world by using the provided noise to make a heightmap.
func generate_terrain() -> void:
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
	for y : int in height:
		terrain.append([])
		for x : int in width:
			var sample : float = accessor.call(x, y, noise_data)
			
			# Set terrain height according to sample and cutoffs.
			var did_find_level : bool = false
			for i : int in len(cutoffs):
				if sample < cutoffs[i]:
					terrain[-1].append(
						TerrainPillar.new(null, i-1, 1)
					)
					
					did_find_level = true
					break
			
			if not did_find_level:
				terrain[-1].append(
					TerrainPillar.new(null, len(cutoffs)-1, 1)
				)
	
	# Randomly set the form of each tile.
	for x : int in width:
		for y : int in height:
			var pillar_position := Vector2i(x, y)
			get_pillar(pillar_position).form = generate_terrain_form(pillar_position)
			
			assert(get_pillar(pillar_position).form != null)

## Analyzes the terrain at the given position and provides a random, valid form.
func generate_terrain_form(pillar_position : Vector2i) -> TerrainForm:
	const epsilon = 0.000001
	
	# Get the sum of weights and other stats.
	# TODO: Any way to speed this up?
	var sum := 0
	var options : Array[TerrainForm] = []
	var weights : Array[int] = []
	
	for form : TerrainForm in cap_forms:
		#print(form.identity)
		options.append(form)
		
		weights.append(form.get_weight(self, pillar_position))
		sum += weights[-1]
	
	#print("Sum = ", sum, ", options = ", len(options))
	
	# Randomly select a form for this tile,
	var num_iters_left := len(options)
	while len(options) > 0:
		assert(num_iters_left >= 0)
		num_iters_left -= 1
		
		var rand := randf() * sum
		#print("  Got rand: ", rand)
		
		for index in len(options):
			rand -= weights[index]
			#print("    ", index, ": Current Rand ", rand)
			
			if rand <= 0 + epsilon:
				#print("      Attempting selection...")
				# Check if this option is valid.
				if options[index].can_generate_here(self, pillar_position):
					#print("      Selecting ", options[index].identity)
					# Assign this option to the pillar and break out of the loops.
					return options[index]
				
				else:
					#print("      Discarding.")
					# Remove this option
					sum -= weights[index]
					if index != len(options)-1:
						# Overwrite the invalid option with the last option in the list.
						# This is O(1), whereas a standard order-preserving remove_at() is O(n)
						options[index] = options[-1]
						weights[index] = weights[-1]
					
					options.remove_at(-1)
					weights.remove_at(-1)
				
				break
			
			else:
				assert(index < len(options)-1, "Failed to choose a tile because the random value was greater than the sum of weights.")
	
	# If no options were valid, simply use the support form.
	return support_form

## Generate sufficient TileMapLayer nodes to hold the terrain.
## Layers are shifted up according to their height,
## and wall layers are also shifted down one.
func generate_blank_layers() -> void:
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
		max_depth = max(pillar.height - south_neighbor.height, 0)
	
	for depth in max_depth+1:
		var level := pillar.height - depth
		var land_layer := get_layer(level, LayerPurpose.LAND)
		
		# Get form to draw at this depth.
		var form := pillar.form
		if depth > 0:
			form = support_form
		
		var connect_north := form.do_connect_land(
			self, pillar, north_neighbor, depth, CardinalDirection.NORTH
		)
		var connect_south := form.do_connect_land(
			self, pillar, south_neighbor, depth, CardinalDirection.SOUTH
		)
		var connect_east := form.do_connect_land(
			self, pillar, east_neighbor, depth, CardinalDirection.EAST
		)
		var connect_west := form.do_connect_land(
			self, pillar, west_neighbor, depth, CardinalDirection.WEST
		)
		
		var flat_tile := form.get_top_half_atlas_coords(
			self, pillar_position, level == 0,
			connect_north, connect_south, connect_east, connect_west
		)
		
		land_layer.set_cell(
			pillar_position, 1, flat_tile
		)
		
		var draw_excess_wall := form.always_draw_wall and level > 0
		if depth < max_depth or draw_excess_wall:
			var wall_layer := get_layer(level, LayerPurpose.WALL)
			
			var connect_wall_west := form.do_connect_wall(
				self, pillar, west_neighbor,
				depth, CardinalDirection.WEST
			)
			var connect_wall_east := form.do_connect_wall(
				self, pillar, east_neighbor,
				depth, CardinalDirection.EAST
			)
			
			var wall_tile := form.get_bot_half_atlas_coords(
				self, pillar_position, connect_wall_east, connect_wall_west
			)
			
			wall_layer.set_cell(pillar_position, 1, wall_tile)

func clear_render():
	for layer in layers:
		layer.queue_free()
	
	layers = []

func is_opaque(atlas_coords : Vector2i) -> bool:
	if atlas_coords.x < 0 or atlas_coords.y < 0:
		return false
	
	if opaque_cache.has(atlas_coords):
		return opaque_cache[atlas_coords]
	
	return false

## Returns the pillar at the specified position.
## Returns null if the specified position is outside the bounds of the map.
func get_pillar(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.x < 0 or pillar_position.x >= width:
		return null
	if pillar_position.y < 0 or pillar_position.y >= height:
		return null
	
	return terrain[pillar_position.y][pillar_position.x]

## Return the TileMapLayer at the specified level for the given tiles.
## Most levels have two layers, one for the ground itself
## and another for the supporting wall tiles beneath the ground at that level
## Level 0 does not have wall (supporting) tiles.
func get_layer(level : int, purpose : LayerPurpose) -> TileMapLayer:
	assert(level >= 0, "Level must not be negative.")
	assert(not (level == 0 and purpose == LayerPurpose.WALL), "Level 0 has no support layer.")
	
	var index := level * 2
	if purpose == LayerPurpose.WALL:
		index -= 1
	
	return layers[index]

func get_neighbor(pillar_position : Vector2i, direction : CardinalDirection) -> TerrainPillar:
	match direction:
		CardinalDirection.NORTH:
			return get_north_neighbor(pillar_position)
		CardinalDirection.SOUTH:
			return get_south_neighbor(pillar_position)
		CardinalDirection.EAST:
			return get_east_neighbor(pillar_position)
		CardinalDirection.WEST:
			return get_west_neighbor(pillar_position)
		_:
			assert(false)
			return null

## Returns the pillar one unit north of the given position if it exists, null otherwise.
func get_north_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.y > 0:
		return get_pillar(pillar_position + Vector2i(0, -1))
	
	return null

## Returns the pillar one unit south of the given position if it exists, null otherwise.
func get_south_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.y < height-1:
		return get_pillar(pillar_position + Vector2i(0, 1))
	
	return null

## Returns the pillar one unit west of the given position if it exists, null otherwise.
func get_west_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.x > 0:
		return get_pillar(pillar_position + Vector2i(-1, 0))
	
	return null

## Returns the pillar one unit east of the given position if it exists, null otherwise.
func get_east_neighbor(pillar_position : Vector2i) -> TerrainPillar:
	if pillar_position.x < width-1:
		return get_pillar(pillar_position + Vector2i(1, 0))
	
	return null

## Validates that the provided cutoffs are valid.
## Prevents undefined behavior from unusual inputs.
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

func _debug_print_terrain():
	var my_str := ""
	for row in terrain:
		for pillar in row:
			if pillar.form is TerrainFormSupport:
				if pillar.height == -1:
					my_str += "~~"
				else:
					my_str += str(pillar.height).lpad(2, ".")
			else:
				match pillar.form.direction:
					CardinalDirection.NORTH:
						my_str += "^"
					CardinalDirection.SOUTH:
						my_str += "v"
					CardinalDirection.EAST:
						my_str += ">"
					CardinalDirection.WEST:
						my_str += "<"
				
				my_str += str(pillar.height)
		
		my_str += "\n"
	
	print(my_str)
