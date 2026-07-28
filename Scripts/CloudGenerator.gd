#@tool
@icon("res://Assets/Godot Icons/node2d/cloud.svg")
class_name CloudGenerator extends Node2D

## Spawns and deletes clouds within the visible game area according to (basically) stateless random generation.
## This means that we can display homogenous random cloud generation anywhere within artifacting due to rapid or unpredictable camera movement.
## The node does manage state for performance reasons, which can be discarded by calling negotiate_cell_size().
##
## Under the hood, there is a (logical) infinite grid of rectangular cells, each with one or more clouds.
## When you call negotiate_cell_size, it calculates the cell shape and size that is
## statistically ideal for achieving the preferred cloud coverage and homogenous spacing.
## Cells which are on-screen have their cloud locations statelessly determined by
## combining the cell index with the seed.
##
## Calling negotiate_cell_size() completely shifts the grid and discards all state.
## It would be very visually jarring to see.

## Scenes to generate as clouds.
## Runtime changes will only apply to freshly generated cells and cause the effective cloud coverage to change.
## Call negotiate_cell_sizes to apply changes to this value. Failure to do so may cause unusual behavior.
@export var clouds : Array[PackedScene] = []

## Cloud velocity in pixels per second.
## You may change this at any time.
@export var cloud_vel : Vector2 = Vector2(-10, 0)

## Approximate fraction of space which should be covered in clouds.
## This is VERY approximate.
## Call negotiate_cell_sizes to apply changes to this value. Failure to do so may cause unusual behavior.
@export_range(0, 1) var density : float = 0.2

## The clouds to randomly place within a cell.
## More causes less predictable generation and marginally higher likelyhood of overlap.
## Call negotiate_cell_sizes to apply changes to this value. Failure to do so may cause unusual behavior.
@export var clouds_per_cell : int = 1

## If true, fill the rendered region with clouds instead of using the explicitly-specified rect.
@export var do_use_active_camera_rect : bool = false

## The rect to fill with clouds, RELATIVE TO THIS NODE'S POSITION.
## If do_use_active_camera_rect is true, this has no effect.
@export var cloudy_region : Rect2 = Rect2(-320, -180, 640, 360)

# Cumulative offset as a result of cloud motion
var cloud_offset : Vector2 = Vector2.ZERO

# The dimensions of cells. Set by negotiate_cell_size()
var cell_width : float = 1
var cell_height : float = 1

# A matrix of cells containing clouds.
var instanced_clouds : Array[Array] = []

# The cell index in the upper left of the sampled region.
var instanced_clouds_sampled_position : Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	negotiate_cell_size()

func _process(delta: float) -> void:
	cloud_offset += cloud_vel * delta
	
	for row in instanced_clouds:
		for cell in row:
			cell.position += cloud_vel * delta
	
	var cell_size : Vector2 = Vector2(cell_width, cell_height)
	var region : Rect2 = get_cloudy_region()
	
	# Calculate the region of the cell grid which must be rendered, inclusive.
	var region_to_sample : Rect2i = Rect2i(
		((region.position - cloud_offset) / cell_size).floor(),
		(region.size / cell_size).ceil()
	)
	region_to_sample.position -= Vector2i(1, 1)
	region_to_sample.size += Vector2i(2, 2)
	
	# Shrink rect as a test.
	region_to_sample.position += Vector2i(4, 4)
	region_to_sample.size -= Vector2i(8, 8)
	
	# Obtain the previously sampled region, from which the new region may be obtained.
	var cs_region : Rect2i # currently sampled region
	if len(instanced_clouds) > 0:
		cs_region = Rect2i(
			instanced_clouds_sampled_position,
			Vector2i(len(instanced_clouds[0])-1, len(instanced_clouds)-1)
		)
		
		if not region_to_sample.intersects(cs_region):
			#print("Discarding State")
			discard_state()
	
	# This can't be an else cus the previous block may discard state,
	# resetting the instanced_clouds to an empty array.
	if len(instanced_clouds) == 0:
		instanced_clouds_sampled_position = region_to_sample.position
		cs_region = Rect2i(
			instanced_clouds_sampled_position,
			Vector2i.ZERO
		)
		
		instanced_clouds = [[instance_cell(
			instanced_clouds_sampled_position.x,
			instanced_clouds_sampled_position.y
		)]]
	
	if region_to_sample == cs_region:
		return
	
	#print("Cell Size: ", cell_width, ", ", cell_height)
	#print("Cloudy Region: ", region)
	#print("From: ", cs_region)
	#print("To:   ", region_to_sample)
	
	# Expand managed region to encompass the cloudy area.
	while region_to_sample.position.y < cs_region.position.y:
		#print("Expanded up")
		instanced_clouds.insert(0, [])
		for x : int in range(cs_region.position.x, cs_region.end.x+1):
			instanced_clouds[0].append(instance_cell(x, cs_region.position.y-1))
		
		cs_region.position.y -= 1
		cs_region.size.y += 1
	
	while region_to_sample.end.y > cs_region.end.y:
		#print("Expanded down")
		instanced_clouds.append([])
		for x : int in range(cs_region.position.x, cs_region.end.x+1):
			instanced_clouds[-1].append(instance_cell(x, cs_region.end.y+1))
		
		cs_region.size.y += 1
	
	while region_to_sample.position.x < cs_region.position.x:
		#print("Expanded left")
		for y : int in range(cs_region.position.y, cs_region.end.y+1):
			var index : int = y - cs_region.position.y
			instanced_clouds[index].insert(0, instance_cell(cs_region.position.x-1, y))
		
		cs_region.position.x -= 1
		cs_region.size.x += 1
	
	while region_to_sample.end.x > cs_region.end.x:
		#print("Expanded right")
		for y : int in range(cs_region.position.y, cs_region.end.y+1):
			var index : int = y - cs_region.position.y
			instanced_clouds[index].append(instance_cell(cs_region.end.x+1, y))
		
		cs_region.size.x += 1
	
	if true:
		# Cull the managed cells that are no longer within the cloudy area.
		while region_to_sample.position.y > cs_region.position.y:
			#print("Culling up")
			for cell in instanced_clouds[0]:
				#print("Culling " + cell.name)
				cell.queue_free()
			
			instanced_clouds.remove_at(0)
			
			cs_region.position.y += 1
			cs_region.size.y -= 1
			
		while region_to_sample.end.y < cs_region.end.y:
			#print("Culling down")
			for cell in instanced_clouds[-1]:
				#print("Culling " + cell.name)
				cell.queue_free()
			
			instanced_clouds.remove_at(-1)
			
			cs_region.size.y -= 1
		
		while region_to_sample.position.x > cs_region.position.x:
			#print("Culling left")
			for y : int in range(cs_region.position.y, cs_region.end.y+1):
				var index : int = y - cs_region.position.y
				var cell = instanced_clouds[index][0]
				#print("Culling " + cell.name)
				cell.queue_free()
				instanced_clouds[index].remove_at(0)
			
			cs_region.position.x += 1
			cs_region.size.x -= 1
		
		while region_to_sample.end.x < cs_region.end.x:
			#print("Culling right")
			for y : int in range(cs_region.position.y, cs_region.end.y+1):
				var index : int = y - cs_region.position.y
				var cell = instanced_clouds[index][-1]
				#print("Culling " + cell.name)
				cell.queue_free()
				instanced_clouds[index].remove_at(-1)
			
			cs_region.size.x -= 1
	
	#print("From: ", cs_region)
	#print("To:   ", region_to_sample)
	instanced_clouds_sampled_position = cs_region.position
	
	#print("------ End Frame ------")

# Creates a cell and randomly positions clouds within it.
# Adds the cell to the scene tree, positions it, and returns it.
func instance_cell(x : int, y : int) -> Node2D:
	#print("    Instancing ", x, ", ", y)
	var cell = Node2D.new()
	cell.global_position = Vector2(x, y) * Vector2(cell_width, cell_height) + cloud_offset
	
	for i : int in clouds_per_cell:
		var cloud : Node2D = clouds[randi_range(0, len(clouds)-1)].instantiate()
		cloud.position = Vector2(randf()*cell_width, randf()*cell_height)
		cell.name = "Cell " + str(x) + ", " + str(y)
		cell.add_child(cloud)
	
	add_child(cell)
	return cell

func get_cloudy_region() -> Rect2:
	# Obtain the region to fill with clouds.
	if do_use_active_camera_rect:
		var active_camera : Camera2D = get_viewport().get_camera_2d()
		if active_camera == null:
			return get_viewport_rect()
		
		else:
			var visible_size := get_viewport_rect().size / active_camera.zoom
			var top_left := active_camera.global_position - (visible_size / 2.0)
			return Rect2(top_left, visible_size)
	
	else:
		return cloudy_region

## Discards the state, forcing cloud regeneration.
## Necessary to apply the effect of changing the seed.
func discard_state() -> void:
	for row : Array[Node2D] in instanced_clouds:
		for instanced_cloud : Node2D in row:
			instanced_cloud.queue_free()
	
	instanced_clouds = []
	instanced_clouds_sampled_position = Vector2i.ZERO
	cloud_offset = Vector2.ZERO
	

## Clouds are generated in random locations within cells in a grid
## Sets the size and shape of the cells to achieve the preferred cloud coverage and homogenous spacing,
## given the available cloud scenes.
func negotiate_cell_size() -> void:
	# Special case is handled by deleting all clouds.
	if density <= 0:
		return
	
	assert(len(clouds) > 0, "Must have clouds to generate.")
	
	var sum_of_cloud_widths : float = 0
	var sum_of_cloud_heights : float = 0
	var sum_of_cloud_areas : float = 0
	
	# Collect some info about the cloud texture sizes
	for cloud in clouds:
		var texture : Texture2D = null
		
		var temp_instance : Node2D = cloud.instantiate()
		if temp_instance is Sprite2D:
			texture = temp_instance.texture
		elif temp_instance is AnimatedSprite2D:
			texture = temp_instance.sprite_frames.get_frame_texture(temp_instance.animation, 0)
		
		assert(texture != null, "Cloud scene '" + str(cloud.resource_path) + "' must have a Sprite2D or AnimatedSprite2D for a root, containing a texture.")
		
		assert(texture.get_width() > 0)
		assert(texture.get_height() > 0)
		print(texture.get_width(), ", ", texture.get_height())
		sum_of_cloud_widths += texture.get_width()
		sum_of_cloud_heights += texture.get_height()
		sum_of_cloud_areas += texture.get_width() * texture.get_height()
	
	# The function giving the sum of the differences between the vertical and horizontal margins for each rect against
	# each hypothetical cell aspect ratio (the independent variable) has roots which may be found by the quadratic equation.
	# One of these roots is the correct aspect ratio for the cells.
	# Combined with the known area, we obtain the width and height of the cells.
	# https://www.desmos.com/calculator/wwvm5nzv0e
	var cell_area : float = sum_of_cloud_areas / len(clouds) / density * clouds_per_cell
	var quadratic_b = -2 - (sum_of_cloud_widths - sum_of_cloud_heights)**2 / (len(clouds)**2 * cell_area)
	
	var squared_quadratic_root_component = quadratic_b**2 - 4
	
	# This error is impossible.
	# If cell_area is positive (which it must be),
	# quadratic_b MUST be less than or equal to -2, thus this value must be at least 0
	# If you get this error, please send this scene (or at least the cloud textures) to ekobadd for analysis.
	assert(squared_quadratic_root_component >= 0)
	
	var quadratic_root_component = sqrt(squared_quadratic_root_component)
	var root_1 = -(quadratic_b - quadratic_root_component) / 2
	var root_2 = -(quadratic_b + quadratic_root_component) / 2
	
	# These errors are also impossible.
	assert(root_1 >= 0)
	assert(root_2 >= 0)
	
	# Calculate cell dimensions based on the first root.
	cell_width  = sqrt(cell_area * root_1)
	cell_height = sqrt(cell_area / root_1)
	
	# Check the sum of errors given these cell dimensions.
	var sum_of_errors_for_root_1 = (cell_width - cell_height)*len(clouds) + sum_of_cloud_widths - sum_of_cloud_heights
	
	# If the sum of errors is not zero, we have the wrong root.
	# Calculate new cell dimensions from the other root.
	if abs(sum_of_errors_for_root_1) < 0.000001:
		cell_width  = sqrt(cell_area * root_2)
		cell_height = sqrt(cell_area / root_2)
		
		var sum_of_errors_for_root_2 = (cell_width - cell_height)*len(clouds) + sum_of_cloud_widths - sum_of_cloud_heights
		assert(sum_of_errors_for_root_2 < 0.000001)
	
	# Disable aspect ratio caluculation
	#cell_width = sqrt(cell_area)
	#cell_height = sqrt(cell_area)
	discard_state()
