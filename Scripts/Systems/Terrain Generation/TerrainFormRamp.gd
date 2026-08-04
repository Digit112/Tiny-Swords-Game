@tool
class_name TerrainFormRamp extends TerrainForm

@export var direction : TerrainGenerator.CardinalDirection

func can_generate_here(terrain : TerrainGenerator, pillar_position : Vector2) -> bool:
	var pillar := terrain.get_pillar(pillar_position)
	if pillar.height <= 0:
		return false
	
	var north_neighbor = terrain.get_north_neighbor(pillar_position)
	var south_neighbor = terrain.get_south_neighbor(pillar_position)
	var east_neighbor = terrain.get_east_neighbor(pillar_position)
	var west_neighbor = terrain.get_west_neighbor(pillar_position)
	
	match direction:
		TerrainGenerator.CardinalDirection.NORTH:
			if north_neighbor == null or south_neighbor == null:
				return false
			if north_neighbor.height != pillar.height or south_neighbor.height != pillar.height - 1:
				return false
			if north_neighbor.form is TerrainFormRamp or south_neighbor.form is TerrainFormRamp:
				return false
			
			if west_neighbor != null and west_neighbor.form is TerrainFormRamp and (
				west_neighbor.form.direction == TerrainGenerator.CardinalDirection.WEST or
				west_neighbor.form.direction == TerrainGenerator.CardinalDirection.EAST
			):
				return false
			if east_neighbor != null and east_neighbor.form is TerrainFormRamp and (
				east_neighbor.form.direction == TerrainGenerator.CardinalDirection.WEST or
				east_neighbor.form.direction == TerrainGenerator.CardinalDirection.EAST
			):
				return false
		
		TerrainGenerator.CardinalDirection.SOUTH:
			if north_neighbor == null or south_neighbor == null:
				return false
			if north_neighbor.height != pillar.height - 1 or south_neighbor.height != pillar.height:
				return false
			if north_neighbor.form is TerrainFormRamp or south_neighbor.form is TerrainFormRamp:
				return false
			
			if west_neighbor != null and west_neighbor.form is TerrainFormRamp and (
				west_neighbor.form.direction == TerrainGenerator.CardinalDirection.WEST or
				west_neighbor.form.direction == TerrainGenerator.CardinalDirection.EAST
			):
				return false
			if east_neighbor != null and east_neighbor.form is TerrainFormRamp and (
				east_neighbor.form.direction == TerrainGenerator.CardinalDirection.WEST or
				east_neighbor.form.direction == TerrainGenerator.CardinalDirection.EAST
			):
				return false
		
		TerrainGenerator.CardinalDirection.EAST:
			if east_neighbor == null or west_neighbor == null:
				return false
			if east_neighbor.form is TerrainFormRamp or west_neighbor.form is TerrainFormRamp:
				return false
			if east_neighbor.height != pillar.height or west_neighbor.height != pillar.height - 1:
				return false
			
			if north_neighbor != null and north_neighbor.form is TerrainFormRamp and (
				north_neighbor.form.direction == TerrainGenerator.CardinalDirection.NORTH or
				north_neighbor.form.direction == TerrainGenerator.CardinalDirection.SOUTH
			):
				return false
			if south_neighbor != null and south_neighbor.form is TerrainFormRamp and (
				south_neighbor.form.direction == TerrainGenerator.CardinalDirection.NORTH or
				south_neighbor.form.direction == TerrainGenerator.CardinalDirection.SOUTH
			):
				return false
		
		TerrainGenerator.CardinalDirection.WEST:
			if east_neighbor == null or west_neighbor == null:
				return false
			if east_neighbor.form is TerrainFormRamp or west_neighbor.form is TerrainFormRamp:
				return false
			if east_neighbor.height != pillar.height - 1 or west_neighbor.height != pillar.height:
				return false
			
			if north_neighbor != null and north_neighbor.form is TerrainFormRamp and (
				north_neighbor.form.direction == TerrainGenerator.CardinalDirection.NORTH or
				north_neighbor.form.direction == TerrainGenerator.CardinalDirection.SOUTH
			):
				return false
			if south_neighbor != null and south_neighbor.form is TerrainFormRamp and (
				south_neighbor.form.direction == TerrainGenerator.CardinalDirection.NORTH or
				south_neighbor.form.direction == TerrainGenerator.CardinalDirection.SOUTH
			):
				return false
		
		_:
			assert(false)
			return false
	
	return true

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
			return Vector2i(1, 4)
		
		TerrainGenerator.CardinalDirection.EAST:
			return Vector2i(0, 4)
		
		TerrainGenerator.CardinalDirection.WEST:
			return Vector2i(3, 4)
		
		_:
			assert(false)
			return Vector2i(-1, -1)

func get_bot_half_atlas_coords(
	terrain : TerrainGenerator, pillar_position : Vector2,
	connect_east : bool, connect_west : bool
) -> Vector2i:
	match direction:
		# North ramps have the same tile for the top and bottom half.
		TerrainGenerator.CardinalDirection.NORTH:
			return get_top_half_atlas_coords(
				terrain, pillar_position, false, false, false, connect_east, connect_west
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

func do_connect_wall(
	_terrain : TerrainGenerator,
	pillar1 : TerrainPillar,
	pillar2 : TerrainPillar,
	depth : int,
	_alignment : TerrainGenerator.CardinalDirection
) -> bool:
	assert(depth >= 0)
	assert(pillar1 != null)
	assert(pillar1.height - depth >= 1)
	
	if pillar2 == null:
		return false
	
	if pillar1.form.direction == TerrainGenerator.CardinalDirection.NORTH:
		# North ramps can connect to adjacent north ramps.
		# Here we simply match the north ramp supporting wall to its variant.
		return do_connect_land(_terrain, pillar1, pillar2, depth, _alignment)
	
	else:
		return false
