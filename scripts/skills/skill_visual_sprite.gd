extends Sprite2D

@export var fps := 12.0
@export var loop := true

var _elapsed := 0.0

func _ready() -> void:
	frame = 0
	visible = texture != null

func _process(delta: float) -> void:
	if texture == null:
		return
	var frame_count := hframes * vframes
	if frame_count <= 1:
		return
	_elapsed += delta
	var next_frame := int(_elapsed * fps)
	if loop:
		frame = next_frame % frame_count
	else:
		frame = mini(next_frame, frame_count - 1)