class_name PlayerVisual
extends Node2D

@export var idle_sheet: Texture2D
@export var run_sheet: Texture2D
@export var jump_start_sheet: Texture2D
@export var jump_loop_sheet: Texture2D
@export var fall_sheet: Texture2D
@export var land_sheet: Texture2D
@export var dodge_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export var death_sheet: Texture2D
@export var attack_1_sheet: Texture2D
@export var attack_2_sheet: Texture2D
@export var attack_3_sheet: Texture2D
@export var slash_sheet: Texture2D
@export var slash_2_sheet: Texture2D
@export var slash_3_sheet: Texture2D
@export var hit_sheet: Texture2D
@export var heavy_hit_sheet: Texture2D
@export var frame_size := Vector2i(96, 96)

@onready var outline: Sprite2D = $Outline
@onready var body: Sprite2D = $Body
@onready var slash: Sprite2D = $Slash
@onready var hit: Sprite2D = $Hit

var _action := &"idle"
var _frame := 0
var _elapsed := 0.0
var _frame_count := 4
var _fps := 8.0
var _loop := true
var _next_action := StringName()
var _attack_action := &"attack_1"
var _hit_default_position := Vector2.ZERO
var _hit_playback_id := 0

func _ready() -> void:
	slash.visible = false
	hit.visible = false
	_hit_default_position = hit.position
	play_action(&"idle")

func _process(delta: float) -> void:
	_elapsed += delta
	var frame_duration := 1.0 / maxf(_fps, 0.1)
	while _elapsed >= frame_duration:
		_elapsed -= frame_duration
		_advance_frame()

func play_action(action: StringName) -> void:
	if action == _action and not _is_restartable(action):
		return
	_action = action
	if action in [&"attack_1", &"attack_2", &"attack_3", &"air_attack", &"charge_attack"]:
		_attack_action = action
	_frame = 0
	_elapsed = 0.0
	var profile := _get_action_profile(action)
	_set_body(profile["texture"], profile["frames"], profile["fps"], profile["loop"], profile["next_action"])

func play_slash() -> void:
	var profile := _get_slash_profile(_attack_action)
	slash.position = profile["position"]
	slash.scale = profile["scale"]
	slash.rotation = profile["rotation"]
	_play_fx(slash, profile["texture"], profile["frames"], profile["fps"])

func play_hit(hit_position := Vector2.INF) -> void:
	var is_heavy := _attack_action in [&"attack_3", &"charge_attack"]
	hit.scale = Vector2.ONE * (1.2 if is_heavy else 1.0)
	if hit_position != Vector2.INF:
		hit.global_position = hit_position
	else:
		hit.position = _hit_default_position
	_hit_playback_id += 1
	var playback_id := _hit_playback_id
	_play_fx(hit, _texture_or(heavy_hit_sheet if is_heavy else hit_sheet, hit_sheet), 4, 22.0)
	var duration := 4.0 / 22.0
	await get_tree().create_timer(duration).timeout
	if playback_id == _hit_playback_id:
		hit.position = _hit_default_position

func _advance_frame() -> void:
	if _loop:
		_frame = (_frame + 1) % _frame_count
	else:
		if _frame < _frame_count - 1:
			_frame += 1
		elif _next_action != StringName():
			play_action(_next_action)
			return
		else:
			_frame = _frame_count - 1
	body.hframes = _frame_count
	outline.hframes = _frame_count
	var safe_frame := clampi(_frame, 0, _frame_count - 1)
	body.frame = safe_frame
	outline.frame = safe_frame

func _set_body(texture: Texture2D, frames: int, fps: float, loop := true, next_action := StringName()) -> void:
	if texture == null:
		return
	outline.texture = texture
	outline.hframes = frames
	outline.frame = 0
	body.texture = texture
	body.hframes = frames
	body.frame = 0
	_frame_count = maxi(frames, 1)
	_fps = maxf(fps, 0.1)
	_loop = loop
	_next_action = next_action

func _get_action_profile(action: StringName) -> Dictionary:
	match action:
		&"run":
			return {"texture": run_sheet, "frames": 8, "fps": 12.0, "loop": true, "next_action": StringName()}
		&"jump":
			return {"texture": jump_start_sheet, "frames": 2, "fps": 14.0, "loop": false, "next_action": &"jump_loop"}
		&"jump_loop":
			return {"texture": jump_loop_sheet, "frames": 2, "fps": 8.0, "loop": true, "next_action": StringName()}
		&"fall":
			return {"texture": fall_sheet, "frames": 2, "fps": 8.0, "loop": true, "next_action": StringName()}
		&"land":
			return {"texture": land_sheet, "frames": 2, "fps": 12.0, "loop": false, "next_action": &"idle"}
		&"dodge":
			return {"texture": dodge_sheet, "frames": 6, "fps": 24.0, "loop": false, "next_action": StringName()}
		&"hurt":
			return {"texture": hurt_sheet, "frames": 3, "fps": 12.0, "loop": false, "next_action": StringName()}
		&"death":
			return {"texture": death_sheet, "frames": 8, "fps": 9.0, "loop": false, "next_action": StringName()}
		&"attack_1":
			return {"texture": attack_1_sheet, "frames": 6, "fps": 25.0, "loop": false, "next_action": StringName()}
		&"attack_2":
			return {"texture": attack_1_sheet, "frames": 6, "fps": 20.0, "loop": false, "next_action": StringName()}
		&"attack_3":
			return {"texture": attack_1_sheet, "frames": 6, "fps": 16.0, "loop": false, "next_action": StringName()}
		&"air_attack", &"charge_attack":
			return {"texture": attack_1_sheet, "frames": 6, "fps": 18.0, "loop": false, "next_action": StringName()}
		_:
			return {"texture": idle_sheet, "frames": 4, "fps": 8.0, "loop": true, "next_action": StringName()}

func _is_restartable(action: StringName) -> bool:
	return action in [&"attack_1", &"attack_2", &"attack_3", &"air_attack", &"charge_attack", &"hurt", &"death", &"land"]

func _texture_or(primary: Texture2D, fallback: Texture2D) -> Texture2D:
	return primary if primary != null else fallback

func _get_slash_profile(action: StringName) -> Dictionary:
	match action:
		&"attack_2":
			return {"texture": _texture_or(slash_2_sheet, slash_sheet), "frames": 4, "fps": 22.0, "position": Vector2(54, -52), "scale": Vector2(1.12, 1.12), "rotation": -0.16}
		&"attack_3", &"charge_attack":
			return {"texture": _texture_or(slash_3_sheet, slash_sheet), "frames": 4, "fps": 16.0, "position": Vector2(60, -58), "scale": Vector2(1.32, 1.32), "rotation": 0.14}
		_:
			return {"texture": slash_sheet, "frames": 4, "fps": 18.0, "position": Vector2(50, -55), "scale": Vector2.ONE, "rotation": 0.0}

func _play_fx(sprite: Sprite2D, texture: Texture2D, frames: int, fps: float) -> void:
	if texture == null:
		return
	sprite.texture = texture
	sprite.hframes = frames
	sprite.vframes = 1
	sprite.frame = 0
	sprite.visible = true
	var duration := float(frames) / maxf(fps, 0.1)
	await get_tree().create_timer(duration).timeout
	sprite.visible = false