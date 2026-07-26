extends Camera2D

enum MotionTestingMode {
	SPIRAL,
	TELEPORT
}

@export var mode : MotionTestingMode

var pos = 0
var timer = 2

func _process(delta: float) -> void:
	if mode == MotionTestingMode.SPIRAL:
		pos += 200 * delta
		position = Vector2(pos * sin(pos/360), pos * cos(pos/360))
	
	elif mode == MotionTestingMode.TELEPORT:
		timer -= delta
		if timer < 0:
			position += Vector2(100000, 100000)
			timer = 2
