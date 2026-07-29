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

@onready var sprite = $Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	regenerate()


func regenerate() -> void:
	pass
	
