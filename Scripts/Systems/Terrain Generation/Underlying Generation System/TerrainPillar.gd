@tool
class_name TerrainPillar extends Object

## The game world is actually a 3-dimensional voxel space
## based on a procedurally generated heightmap and rendered using 2D tiles.
## As opposed to representing a vertical slice of the map,
## a TerrainColumn represents a cell in the heightmap.
## It has a height, color variant, and form variant, all affecting collision.

enum Form {
	FLAT,
	RAMP_EAST,
	RAMP_WEST,
	RAMP_NORTH,
	RAMP_SOUTH
}

var height : int
var form : TerrainForm
var variant : int

func _init(init_form : TerrainForm, init_height : int = -1, init_variant : int = 1) -> void:
	height = init_height
	form = init_form
	variant = init_variant

## Accepts a value from (0, 0) to (1, 1) representing a position on this pillar,
## with (0, 0) being the northwest corner, and returns the height of the ground at that position.
func get_height_at_relative_position(relative_position : Vector2) -> float:
	assert(relative_position.x >= 0)
	assert(relative_position.x <= 1)
	assert(relative_position.y >= 0)
	assert(relative_position.y <= 1)
	
	return height + form.get_relative_height_at_relative_position(relative_position)
