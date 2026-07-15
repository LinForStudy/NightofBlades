class_name ExperienceOrb
extends Area2D

signal collected(value: int)

@export var value := 5
@export var magnet_range := 150.0
@export var move_speed := 420.0

var _target: Node2D
var _is_collected := false

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_resolve_target()

func setup(experience_value: int, start_position: Vector2) -> void:
	value = experience_value
	global_position = start_position
	_is_collected = false
	visible = true
	monitoring = true

func _physics_process(delta: float) -> void:
	if _is_collected:
		return
	_resolve_target()
	if _target == null:
		return
	var distance := global_position.distance_to(_target.global_position)
	if distance <= 22.0:
		_collect()
	elif distance <= magnet_range:
		global_position = global_position.move_toward(_target.global_position + Vector2(0, -26), move_speed * delta)

func _resolve_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	_target = get_tree().get_first_node_in_group("player") as Node2D

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	monitoring = false
	visible = false
	collected.emit(value)
	queue_free()