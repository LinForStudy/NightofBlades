class_name CameraFollow2D
extends Camera2D

@export var target_path: NodePath
@export var follow_smoothing := 8.0
@export var lookahead_pixels := 70.0
@export var world_left := 0.0
@export var world_right := 2400.0
@export var world_top := 0.0
@export var world_bottom := 720.0

var _target: Node2D
var _shake_timer := 0.0
var _shake_strength := 0.0

func _ready() -> void:
	make_current()
	limit_left = int(world_left)
	limit_right = int(world_right)
	limit_top = int(world_top)
	limit_bottom = int(world_bottom)
	_resolve_target()

func _physics_process(delta: float) -> void:
	if _target == null:
		_resolve_target()
		return

	var facing := 1.0
	var target_facing: Variant = _target.get("facing_direction")
	if target_facing != null:
		facing = float(target_facing)
	var desired := _target.global_position + Vector2(lookahead_pixels * facing, -40.0)
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	_update_shake(delta)

func request_shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_timer = maxf(_shake_timer, duration)

func _update_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		offset = Vector2.ZERO
		return

	_shake_timer = maxf(_shake_timer - delta, 0.0)
	var fade := _shake_timer / maxf(_shake_timer + delta, 0.001)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * fade
	if _shake_timer <= 0.0:
		offset = Vector2.ZERO

func _resolve_target() -> void:
	if target_path.is_empty():
		return
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		push_warning("CameraFollow2D target not found: %s" % target_path)