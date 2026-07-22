class_name RiftColossusVisual
extends Node2D

@export var idle_sheet: Texture2D
@export var slam_sheet: Texture2D
@export var shockwave_sheet: Texture2D
@export var idle_fps := 5.0
@export var slam_fps := 9.0
@export var shockwave_fps := 14.0

@onready var body: Sprite2D = $Body
@onready var attack_fx: Sprite2D = $AttackFx

var _body_frame := 0
var _body_elapsed := 0.0
var _body_frames := 9
var _body_fps := 5.0
var _body_loop := true
var _fx_frame := 0
var _fx_elapsed := 0.0
var _fx_playing := false

func _ready() -> void:
	attack_fx.visible = false
	play_idle()

func _process(delta: float) -> void:
	_animate_body(delta)
	_animate_fx(delta)

func play_idle() -> void:
	if idle_sheet == null:
		return
	_body_frames = 9
	_body_fps = idle_fps
	_body_loop = true
	_body_frame = 0
	_body_elapsed = 0.0
	body.texture = idle_sheet
	body.hframes = 3
	body.vframes = 3
	body.frame = 0

func play_attack(_tag: StringName, direction: int) -> void:
	if slam_sheet == null:
		return
	set_facing(direction)
	_body_frames = 4
	_body_fps = slam_fps
	_body_loop = false
	_body_frame = 0
	_body_elapsed = 0.0
	body.texture = slam_sheet
	body.hframes = 2
	body.vframes = 2
	body.frame = 0

func trigger_attack_fx(_tag: StringName, direction: int) -> void:
	if shockwave_sheet == null:
		return
	set_facing(direction)
	attack_fx.texture = shockwave_sheet
	attack_fx.hframes = 2
	attack_fx.vframes = 2
	attack_fx.frame = 0
	attack_fx.position = Vector2(118.0 * direction, -96.0)
	attack_fx.flip_h = direction > 0
	attack_fx.visible = true
	_fx_frame = 0
	_fx_elapsed = 0.0
	_fx_playing = true

func set_facing(direction: int) -> void:
	body.flip_h = direction > 0

func _animate_body(delta: float) -> void:
	if body.texture == null:
		return
	_body_elapsed += delta
	var duration := 1.0 / maxf(_body_fps, 0.1)
	while _body_elapsed >= duration:
		_body_elapsed -= duration
		if _body_loop:
			_body_frame = (_body_frame + 1) % _body_frames
		elif _body_frame < _body_frames - 1:
			_body_frame += 1
		body.frame = _body_frame

func _animate_fx(delta: float) -> void:
	if not _fx_playing:
		return
	_fx_elapsed += delta
	var duration := 1.0 / maxf(shockwave_fps, 0.1)
	while _fx_elapsed >= duration:
		_fx_elapsed -= duration
		_fx_frame += 1
		if _fx_frame >= 4:
			attack_fx.visible = false
			_fx_playing = false
			return
		attack_fx.frame = _fx_frame