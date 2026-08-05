extends Node2D

## An entity capable of navigating the 3D terrain environment and rendering in isometric 2D space.

## The terrain generator with the terrain to be navigated.
var terrain_gen : TerrainGenerator

## The radius of collision around the navigation agent.
## Must be less than 1. Can be 0 for point collision.
var radius : float

## The sprite's location, a 2D coordinate.
## In tile-space, where each generated tile is considered to have a width and height of 1.
## Height is calculated by looking this value up in the heightmap.
var location : Vector2

## The velocity of this agent in tiles per second, a 2-dimensional quantity.
## Vertical velocity does not exist because units always snap to the terrain surface.
var velocity : Vector2

func _init(init_terrain_gen : TerrainGenerator, init_location : Vector2, init_radius : float = 0.0) -> void:
	terrain_gen = init_terrain_gen
	radius = init_radius
	location = init_location

## Return the height of the agent.
func get_height() -> float:
	var pillar_index := Vector2i(floor(location.x), floor(location.y))
	var relative_position := location - Vector2(pillar_index)
	var pillar := terrain_gen.get_pillar(pillar_index)
	
	return pillar.get_height_at_relative_position(relative_position)

## Moves the agent along the current velocity an amount scaled by delta.
## Collides with walls according to the underlying heightmap behind the generated terrain.
## Also collides with ledges, preventing units from falling off them.
func move_and_slide(delta : float) -> void:
	var loc_delta := velocity*delta
	var distance := loc_delta.length()
	var rel_location := location - Vector2(floor(location.x), floor(location.y))
	
