@tool
class_name TerrainFormRamp extends TerrainForm

@export var direction : TerrainGenerator.CardinalDirection

func can_generate_here(terrain : TerrainGenerator, pillar_position : Vector2) -> bool:
	var pillar := terrain.get_pillar(pillar_position)
	if pillar.height <= 0:
		return false
	
	match direction:
		TerrainGenerator.CardinalDirection.NORTH:
			var north_neighbor = terrain.get_north_neighbor(pillar_position)

func get_top_half_atlas_coords(
	_terrain : TerrainGenerator, _pillar_position : Vector2,
	_is_at_level_zero : bool,
	_connect_north : bool, _connect_south : bool,
	connect_east : bool, connect_west : bool
) -> Vector2i:
	match direction:
		# North ramps are unique in that they can connect to the sides,
		# but only to other north ramps.
		TerrainGenerator.CardinalDirection.NORTH:
			if connect_east:
				if connect_west:
					return Vector2i(6, 1)
				else:
					return Vector2i(5, 1)
			else:
				if connect_west:
					return Vector2i(7, 1)
				else:
					return Vector2i(8, 1)
		
		# South tiles have no representation
		TerrainGenerator.CardinalDirection.SOUTH:
			return Vector2i(-1, -1)
		
		TerrainGenerator.CardinalDirection.EAST:
			return Vector2i(0, 4)
		
		TerrainGenerator.CardinalDirection.WEST:
			return Vector2i(3, 4)
		
		_:
			assert(false)
			return Vector2i(-1, -1)

func get_bot_half_atlas_coords(
	_terrain : TerrainGenerator, _pillar_position : Vector2,
	connect_east : bool, connect_west : bool
) -> Vector2i:
	match direction:
		# North ramps have the same tile for the top and bottom half.
		TerrainGenerator.CardinalDirection.NORTH:
			return get_top_half_atlas_coords(
				_terrain, _pillar_position, false, false, false, connect_east, connect_west
			)
		
		# South tiles have no representation
		TerrainGenerator.CardinalDirection.SOUTH:
			return Vector2i(-1, -1)
		
		TerrainGenerator.CardinalDirection.EAST:
			return Vector2i(0, 5)
		
		TerrainGenerator.CardinalDirection.WEST:
			return Vector2i(3, 5)
		
		_:
			assert(false)
			return Vector2i(-1, -1)

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
	
	# North ramps connect to one another when side-by-side.
	var heights_match := pillar1.height == pillar2.height
	var horizontally_adjacent := (
		alignment == TerrainGenerator.CardinalDirection.WEST or
		alignment == TerrainGenerator.CardinalDirection.EAST
	)
	var both_north_ramps : bool = (
		pillar1.form is TerrainFormRamp and # Always true, but included for symmetry.
		pillar1.form.direction == TerrainGenerator.CardinalDirection.NORTH and
		pillar2.form is TerrainFormRamp and
		pillar2.form.direction == TerrainGenerator.CardinalDirection.NORTH
	)
	
	return heights_match and both_north_ramps and horizontally_adjacent
