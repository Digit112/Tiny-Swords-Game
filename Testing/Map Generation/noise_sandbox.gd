@tool
extends Node2D

## Regenerate the map.
@export_tool_button("Regenerate") var Regenerate = regenerate

## Whether to generate 1, 2, or 3 layers.
@export_range(1, 3, 1) var layer_count : int

@export_group("Noise")

## Noise used to generate the terrain color.
## An identical noise object with a diffferent seed is combined with this to
## choose between two color variants.
@export var terrain_color_noise : FastNoiseLite

## Noise used to generate the first layer of terrain.
@export var terrain_layer_1_noise : FastNoiseLite

## Noise used to generate the second layer of terrain.
## Multiplied by the output of the layer 1 noise and checked against
## the height threshhold to determine whether the terrain exists or is empty.
@export var terrain_layer_2_noise : FastNoiseLite

## Noise used to generate the third layer of terrain.
## Multiplied by the output of the layer 1 and 2 noise and checked against
## the height threshhold to determine whether the terrain exists or is empty.
@export var terrain_layer_3_noise : FastNoiseLite

@export_group("Tile Atlas and Coordinates")

## The TileSet containing all the usable tiles for map generation.
@export var atlas : TileSet

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	regenerate()

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

func get_upper_layer_land_tiles(
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

func regenerate() -> void:
	pass
	
