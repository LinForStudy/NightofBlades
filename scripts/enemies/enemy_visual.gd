class_name EnemyVisual
extends Node2D

const DEATH_FX_SCENE := preload("res://scenes/enemies/enemy_death_fx.tscn")

@export var idle_sheet: Texture2D
@export var move_sheet: Texture2D
@export var attack_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export var death_sheet: Texture2D
@export var frame_size := Vector2i(96, 96)
@export var idle_fps := 6.0
@export var move_fps := 10.0
@export var attack_fps := 12.0
@export var hurt_fps := 14.0
@export var death_fps := 10.0
@export_range(-1, 1, 2) var source_facing := -1

@onready var body: Sprite2D = $Body

var _action := &"idle"
var _frame := 0
var _elapsed := 0.0
var _frames := 4
var _fps := 6.0
var _loop := true
var _one_shot_until := 0.0

func _ready() -> void:
	var enemy := get_parent()
	if enemy != null and enemy.has_signal("attack_started"):
		enemy.attack_started.connect(play_attack)
	play_action(&"idle")

func _process(delta: float) -> void:
	_elapsed += delta
	var duration := 1.0 / maxf(_fps, 0.1)
	while _elapsed >= duration:
		_elapsed -= duration
		if _loop:
			_frame = (_frame + 1) % _frames
		elif _frame < _frames - 1:
			_frame += 1
		body.hframes = _frames
		body.vframes = 1
		body.frame = clampi(_frame, 0, _frames - 1)
	if Time.get_ticks_msec() >= _one_shot_until:
		_update_from_owner()

func set_facing(direction: int) -> void:
	var authored_facing := -1 if source_facing < 0 else 1
	scale.x = float(direction * authored_facing)

func set_tint(tint: Color) -> void:
	body.modulate = tint

func play_hurt() -> void:
	play_action(&"hurt", true)

func play_attack(_enemy: Node = null) -> void:
	play_action(&"attack", true)

func spawn_death_fx(world_position: Vector2) -> void:
	if death_sheet == null:
		return
	var root := get_tree().current_scene.get_node_or_null("World/EffectRoot")
	if root == null:
		return
	var effect := DEATH_FX_SCENE.instantiate()
	root.add_child(effect)
	effect.global_position = world_position
	effect.setup(death_sheet, 6, death_fps, scale.x, body.modulate)

func _update_from_owner() -> void:
	var enemy := get_parent()
	if enemy == null:
		return
	var state: int = int(enemy.get("current_state"))
	if state in [2, 3, 6]:
		play_action(&"attack")
	elif absf(enemy.velocity.x) > 5.0:
		play_action(&"move")
	else:
		play_action(&"idle")

func play_action(next_action: StringName, force := false) -> void:
	if next_action == _action and not force:
		return
	var profile := _profile(next_action)
	if profile["texture"] == null:
		return
	_action = next_action
	_frame = 0
	_elapsed = 0.0
	_frames = profile["frames"]
	_fps = profile["fps"]
	_loop = profile["loop"]
	body.texture = profile["texture"]
	body.hframes = _frames
	body.vframes = 1
	body.frame = 0
	if not _loop:
		_one_shot_until = Time.get_ticks_msec() + int(ceil(float(_frames) / _fps * 1000.0))

func _profile(action: StringName) -> Dictionary:
	match action:
		&"move":
			return {"texture": move_sheet, "frames": 4, "fps": move_fps, "loop": true}
		&"attack":
			return {"texture": attack_sheet, "frames": 4, "fps": attack_fps, "loop": false}
		&"hurt":
			return {"texture": hurt_sheet, "frames": 2, "fps": hurt_fps, "loop": false}
		_:
			return {"texture": idle_sheet, "frames": 4, "fps": idle_fps, "loop": true}