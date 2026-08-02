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
var form : Form
var variant : int

func _init(init_height : int = -1, init_form : Form = Form.FLAT, init_variant : int = 1) -> void:
	height = init_height
	form = init_form
	variant = init_variant

func is_flat() -> bool:
	return form == Form.FLAT

func is_east_west_ramp() -> bool:
	return form == Form.RAMP_EAST or form == Form.RAMP_WEST

func is_noth_south_ramp() -> bool:
	return form == Form.RAMP_NORTH or form == Form.RAMP_SOUTH
