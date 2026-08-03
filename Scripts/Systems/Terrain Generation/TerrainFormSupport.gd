@tool
class_name TerrainFormSupport extends TerrainForm

# TODO: Combine tile getters into one function to make it as easy to ignore as possible.

func get_top_half_atlas_coords(
	_terrain : TerrainGenerator, _pillar_position : Vector2,
	is_at_level_zero : bool,
	connect_north : bool, connect_south : bool,
	connect_east : bool, connect_west : bool
) -> Vector2i:
	if is_at_level_zero:
		return get_bottom_layer_land_tile(
			connect_north, connect_east,
			connect_south, connect_west
		)
	else:
		return get_upper_layer_land_tile(
			connect_north, connect_east,
			connect_south, connect_west
		)

func get_bot_half_atlas_coords(
	_terrain : TerrainGenerator, _pillar_position : Vector2,
	connect_east : bool, connect_west : bool
) -> Vector2i:
	if connect_west:
		if connect_east:
			return Vector2i(6, 4)
		else:
			return Vector2i(7, 4)
	else:
		if connect_east:
			return Vector2i(5, 4)
		else:
			return Vector2i(8, 4)

func do_connect_land(
	_terrain : TerrainGenerator,
	pillar1 : TerrainPillar,
	pillar2 : TerrainPillar,
	depth : int,
	alignment : TerrainGenerator.CardinalDirection
) -> bool:
	assert(depth >= 0)
	assert(pillar1 != null)
	assert(pillar1.height - depth >= 0)
	
	# Don't connect to the edge of the map.
	if pillar2 == null:
		return false
	
	# Support tiles connect in all directions to all taller pillars
	if pillar1.height - depth < pillar2.height:
		return true
	
	# Support tiles connect in all directions to tiles of equal height
	# except when this would mean connecting to the side of a ramp.
	if pillar1.height - depth == pillar2.height:
		if pillar2.form.identity == &"SUPPORT":
			return true
		
		# Connect to the east or west sides of an east or west ramp
		elif (
			pillar2.form.identity == &"RAMP" and (
				pillar2.form.direction == TerrainGenerator.CardinalDirection.EAST or
				pillar2.form.direction == TerrainGenerator.CardinalDirection.WEST
			)
		) and (
			alignment == TerrainGenerator.CardinalDirection.EAST or
			alignment == TerrainGenerator.CardinalDirection.WEST
		):
			return true
		
		# Connect to the north or south sides of a north or south ramp.
		elif (
			pillar2.form.identity == &"RAMP" and (
				pillar2.form.direction == TerrainGenerator.CardinalDirection.NORTH or
				pillar2.form.direction == TerrainGenerator.CardinalDirection.SOUTH
			) 
		) and (
			alignment == TerrainGenerator.CardinalDirection.NORTH or
			alignment == TerrainGenerator.CardinalDirection.SOUTH
		):
			return true
	
	return false

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
