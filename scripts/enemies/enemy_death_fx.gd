class_name EnemyDeathFx
extends Node2D

@onready var body: Sprite2D = $Body

var _frames := 6
var _fps := 10.0
var _frame := 0
var _elapsed := 0.0

func setup(texture: Texture2D, frames: int, fps: float, facing_scale: float, tint: Color) -> void:
	body.texture = texture
	_frames = maxi(frames, 1)
	_fps = maxf(fps, 0.1)
	body.hframes = _frames
	body.frame = 0
	body.scale = Vector2(facing_scale, absf(facing_scale))
	body.modulate = tint

func _process(delta: float) -> void:
	_elapsed += delta
	var duration := 1.0 / _fps
	while _elapsed >= duration:
		_elapsed -= duration
		_frame += 1
		if _frame >= _frames:
			queue_free()
			return
		body.frame = _frame