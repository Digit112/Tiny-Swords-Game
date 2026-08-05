@tool
class_name TerrainForm extends Resource

## Represents a pair of tiles corresponding to a renderable unit of terrain.
## The top half is called the land tile and is rendered on the land layer.
## The bottom half is called the wall or support tile.
## For pillars of terrain jutting upwards, supporting entities are drawn
##     as needed to connect the pillar's uppermost land tile to the
##     lower terrain to its immediate south.
##
## A pillar is capped by the entities from the "form" field on the TerrainPillar.
## All supporting entities beneath that pair are of the special "SUPPORT" variety
##     as specified on the TerrainGenerator.
##
## The TileSet which the atlas coords index into is added,
##     along with the TerrainForm resources, to the TerrainGenerator itself.
##
## Be mindful that the exported properties allow the use of this
##     entity without extending it.
##     However, when extending it, these properties will often become useless
##     as they are replaced by calculated variables.
## Be very careful to remember which exported variables
##     need to be set and which are controlled 
## ALL EXTENDING CLASSES MUST BE MARKED @tool FOR THE IN-EDITOR PREVIEW TO WORK.

## Constant used to uniquely easily distinguish TerrainForm instances.
## Meant to be used when overriding the do_connect() function
## to apply rules about connections between different forms.
@export var identity : StringName = &"BASE"

## Weight given to this form for random generation purposes.
@export var weight : float = 1

## The top half of this entity.
## Will be placed on the LAND layer at the level at which the entity is generated.
@export var top_half_atlas_coords : Vector2i

## The bottom half of this entity.
## Will be placed on the WALL layer at the level at which the entity is generated.
## Placed at the same coords as the top half,
##     but since WALL layers are shifted down by one,
##     it will appear immediately under the top half (as expected)
@export var bot_half_atlas_coords : Vector2i

## If true, draw the lower half of this entity (the wall tile)
##     even if it *should* be obscured by the southward terrain.
## Useful for forms which may be positioned behind partially-transparent terrain.
@export var always_draw_wall : bool = false

## Returns whether this form can be generated in the given location.
## Extend TerrainForm to override this function and add sophisticated requirements.
## Note that the surrounding terrain's form is null
##     at the stage of generation where this function is called.
func can_generate_here(_terrain : TerrainGenerator, _pillar_position : Vector2) -> bool:
	return true

## Returns the weight.
## Extend TerrainForm to override this function and develop more sophisticated generation.
func get_weight(_terrain : TerrainGenerator, _pillar_position : Vector2) -> float:
	return weight

## Retrieve the atlas coordinates of the tiles to place when rendering this entity.
## Extend TerrainForm to override this method and produce complex arrangements.
## Can retrieve either the top half or bottom half,
##     which are placed on the LAND and WALL layers respectively,
##     appearing as a double-tall column.
##
## To ensure the connectedness of land tiles which generally
##     have corner, edge, and center variants,
##     this function recieves as parameters whether it should
##     connect in four cardinal directions.
##     These values are obtained using do_connect5().
##
## This method is a huge pain to write
##     and often is just a bunch of nested if-else statements.
func get_top_half_atlas_coords(
	_terrain : TerrainGenerator, _pillar_position : Vector2,
	_is_at_level_zero : bool,
	_connect_north : bool, _connect_south : bool,
	_connect_east : bool, _connect_west : bool
) -> Vector2i:
	return top_half_atlas_coords

## Like get_top_half_atlas_coords().
## Supporting (bottom) tiles do not connect to the north,
##     they always appear under their own top half.
## They also do not connect to the south,
##     they always appear overlaid on top of a backing tile which may do so.
## They never appear on layer 0 since the first layer to have backing tiles is layer 1.
func get_bot_half_atlas_coords(
	_terrain : TerrainGenerator, _pillar_position : Vector2,
	_connect_east : bool, _connect_west : bool
) -> Vector2i:
	return bot_half_atlas_coords

## Given the two adjcanet pillars whose heights and forms are finalized,
##     and the depth (with depth 0 referring to the to the uppermost rendered land-wall pair),
##     and the cardinal direction from pillar 1 to pillar 2,
## Return whether the land tile at the given depth should connect
##     in this cardinal direction.
func do_connect_land(
	_terrain : TerrainGenerator,
	pillar1 : TerrainPillar,
	pillar2 : TerrainPillar,
	depth : int,
	_alignment : TerrainGenerator.CardinalDirection
) -> bool:
	assert(depth >= 0)
	assert(pillar1 != null)
	assert(pillar1.height - depth >= 0)
	
	if pillar2 == null:
		# Return true to make tiles connect to the map boundaries.
		return false
	
	return pillar1.height - depth <= pillar2.height

## Very similar to do_connect_land, except this is used for the wall tiles.
## Wall tiles cannot connect to the north or south, only to the east and west.
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
		# Return true to make tiles connect to the map boundaries.
		return false
	
	return pillar1.height - depth <= pillar2.height

## Accepts a value from (0, 0) to (1, 1) representing a position on this form,
## with (0, 0) being the northwest corner, and returns the height of the ground at that position.
## A value of 0 means that the height at this point is equal to the height for this pixel in the heigtmap.
## For flat tiles, this should simply return 0 always.
##
## This function is very important and its behavior for inputs including 1s and 0s
## matters because when the navigation agent needs to determine whether it can cross
## a boundary between two cells, it checks the difference between their heights
## along their shared edge.
func get_relative_height_at_relative_position(relative_position : Vector2) -> float:
	return 0
