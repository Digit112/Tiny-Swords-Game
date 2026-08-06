@tool
class_name TerrainNavAgent extends Node2D

## An entity capable of navigating the 3D terrain environment and rendering in isometric 2D space.

## The terrain generator with the terrain to be navigated.
@export var terrain_gen : TerrainGenerator

## The radius of collision around the navigation agent.
## Must be less than 1. Can be 0 for point collision.
@export var radius : float

## Maximum upward distance traversable by a unit in a single step.
## Only affects traversal across the edges of a cell.
@export var max_step_up := 0.1

## Maximum downward distance traversable by a unit in a single step.
## Only affects traversal across the edges of a cell.
@export var max_step_down := 0.1

## The sprite's location, a 2D coordinate.
## In tile-space, where each generated tile is considered to have a width and height of 1.
## Height is calculated by looking this value up in the heightmap.
@export var location : Vector2

const NORTH = TerrainGenerator.CardinalDirection.NORTH
const SOUTH = TerrainGenerator.CardinalDirection.SOUTH
const EAST  = TerrainGenerator.CardinalDirection.EAST
const WEST  = TerrainGenerator.CardinalDirection.WEST

## The velocity of this agent in tiles per second, a 2-dimensional quantity.
## Vertical velocity does not exist because units always snap to the terrain surface.
var velocity : Vector2

## Return the height of the agent.
func get_height() -> float:
	var pillar_index := pillar_coords(location)
	var relative_position := location - Vector2(pillar_index)
	var pillar := terrain_gen.get_pillar(pillar_index)
	
	return pillar.get_height_at_relative_position(relative_position)

## Moves the agent along the current velocity an amount scaled by delta.
## Collides with walls according to the underlying heightmap behind the generated terrain.
## Also collides with ledges, preventing units from falling off them.
func move_and_slide(delta : float) -> void:
	const epsilon := 0.0000001
	
	var remaining_time := delta
	var time_to_ew_edge := 0.0
	var time_to_ns_edge := 0.0
	
	# Each loop corresponds to a collision with the edge of a cell.
	# Uses a typical rectangular grid traversal algorithm.
	var iters_left := 6
	while remaining_time > 0.0:
		iters_left -= 1
		assert(iters_left >= 0, "Possible endless loop")
		
		var rel_location := location.posmod(1.0)
		
		# Find the time travelled at our velocity before we contact an east or west edge.
		if velocity.x > 0:
			time_to_ew_edge = (1 - rel_location.x) / velocity.x
		elif velocity.x < 0:
			# If exactly on the east-west border between cells and heading west, rel_position should be 1.
			# Use of epsilon adds buffer for FP-imprecision but makes it possible
			# to clip through cells with TAS-level precision.
			if rel_location.x <= 0 + epsilon:
				rel_location.x = 1
			
			time_to_ew_edge = -rel_location.x / velocity.x
		else:
			time_to_ew_edge = INF
		
		# Find the time travelled at our velocity before we contact a north or south edge.
		if velocity.y > 0:
			time_to_ns_edge = (1 - rel_location.y) / velocity.y
		elif velocity.y < 0:
			# If exactly on the north-south border between cells and heading north, rel_position should be 1.
			if rel_location.y <= 0 + epsilon:
				rel_location.y = 1
			
			time_to_ns_edge = -rel_location.y / velocity.y
		else:
			time_to_ns_edge = INF
		
		# Should be impossible thanks to posmod being applied to our location.
		# If the times are 0, it would casue an infinite loop since we would not move at all.
		assert(time_to_ew_edge > 0)
		assert(time_to_ns_edge > 0)
		
		var time_to_move : float = min(time_to_ew_edge, time_to_ns_edge, remaining_time)
		assert(time_to_move > 0)
		
		# Move.
		location += velocity * time_to_move
		remaining_time -= time_to_move
		
		if velocity.x >= 0:
			var can_traverse_edge := can_traverse(location, EAST, fposmod(location.y, 1.0))
			if not can_traverse_edge:
				push_off(EAST)
				if time_to_ew_edge <= time_to_move:
					velocity.x = 0
		
		if velocity.x <= 0:
			var can_traverse_edge := can_traverse(location, WEST, fposmod(location.y, 1.0))
			if not can_traverse_edge:
				push_off(WEST)
				if time_to_ew_edge <= time_to_move:
					velocity.x = 0
		
		if velocity.y >= 0:
			var can_traverse_edge := can_traverse(location, SOUTH, fposmod(location.x, 1.0))
			if not can_traverse_edge:
				push_off(SOUTH)
				if time_to_ns_edge <= time_to_move:
					velocity.y = 0
		
		if velocity.y <= 0:
			var can_traverse_edge := can_traverse(location, NORTH, fposmod(location.x, 1.0))
			if not can_traverse_edge:
				push_off(NORTH)
				if time_to_ns_edge <= time_to_move:
					velocity.y = 0
		

## Returns the index of the pillar containing this location, whether it exists or not.
func pillar_coords(loc : Vector2) -> Vector2i:
	return loc.floor()

## Whether the edge can be traversed across the given sample point.
## Give the current location and thedirection of travel.
## The sample is the position along the edge from 0 to 1 whered we are stepping over.
## 0 is the northernmost point along a vertical edge and the easternmost point along a horizontal edge.
##
## The "from" and "to" pillars will be sampled at the same point along their shared edge.
## The difference in the given heights will be compared to the given step size.
func can_traverse(loc : Vector2, direction : TerrainGenerator.CardinalDirection, sample_point : float) -> bool:
	assert(sample_point >= 0 and sample_point <= 1, str(sample_point))
	
	var coords := pillar_coords(loc)
	var from_pillar := terrain_gen.get_pillar(coords)
	var to_pillar := terrain_gen.get_neighbor(coords, direction)
	
	assert(from_pillar != null, "Undefined to request traversal from a non-existent pillar.")
	if to_pillar == null:
		return false
	
	var from_sample := Vector2(-1, -1)
	var to_sample := Vector2(-1, -1)
	match direction:
		NORTH:
			from_sample = Vector2(sample_point, 0)
			to_sample = Vector2(sample_point, 1)
		SOUTH:
			from_sample = Vector2(sample_point, 1)
			to_sample = Vector2(sample_point, 0)
		EAST:
			from_sample = Vector2(1, sample_point)
			to_sample = Vector2(0, sample_point)
		WEST:
			from_sample = Vector2(0, sample_point)
			to_sample = Vector2(1, sample_point)
	
	var from_height := from_pillar.get_height_at_relative_position(from_sample)
	var to_height := to_pillar.get_height_at_relative_position(to_sample)
	
	var step_size := to_height - from_height
	
	return step_size <= max_step_up and step_size >= -max_step_down

## Push off the edge in the given direction.
## Unit will travel exactly opposite the supplied direction, if necessary.
func push_off(direction : TerrainGenerator.CardinalDirection):
	var rel_location := location.posmod(1.0)
	
	match direction:
		NORTH:
			location.y += max(radius - rel_location.y, 0)
		SOUTH:
			location.y -= max(radius - (1 - rel_location.y), 0)
		EAST:
			location.x -= max(radius - (1 - rel_location.x), 0)
		WEST:
			location.x += max(radius - rel_location.x, 0)

func get_iso_projected_position() -> Vector2:
	return (location - Vector2(0, get_height())) * Vector2(terrain_gen.tile_set.tile_size) + terrain_gen.position
