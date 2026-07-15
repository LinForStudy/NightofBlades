class_name ExperienceManager
extends Node

signal experience_changed(current: int, required: int, level: int)
signal level_up_choices_ready(options: Array[Resource], pending_count: int)
signal level_up_finished(level: int)

@export var experience_orb_scene: PackedScene
@export var orb_root_path: NodePath
@export var upgrade_manager_path: NodePath
@export var level_curve: Array[int] = [20, 35, 55, 80, 110, 145, 185, 230, 280]

var level := 1
var current_experience := 0
var pending_level_ups := 0
var is_selecting_upgrade := false

var _orb_root: Node2D
var _upgrade_manager: Node
var _current_options: Array[Resource] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_orb_root = get_node_or_null(orb_root_path) as Node2D
	_upgrade_manager = get_node_or_null(upgrade_manager_path)
	_emit_experience_changed()

func spawn_experience_orb(value: int, world_position: Vector2) -> Node:
	if experience_orb_scene == null or _orb_root == null:
		return null
	var orb := experience_orb_scene.instantiate()
	_orb_root.add_child(orb)
	if orb.has_method("setup"):
		orb.setup(value, world_position)
	if orb.has_signal("collected"):
		orb.collected.connect(_on_orb_collected)
	return orb

func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	current_experience += amount
	while current_experience >= _required_for_next_level():
		current_experience -= _required_for_next_level()
		level += 1
		pending_level_ups += 1
	_emit_experience_changed()
	_try_present_level_up()

func choose_upgrade(index: int) -> void:
	if not is_selecting_upgrade or index < 0 or index >= _current_options.size():
		return
	var upgrade := _current_options[index]
	if _upgrade_manager != null and _upgrade_manager.has_method("apply_upgrade"):
		_upgrade_manager.apply_upgrade(upgrade)
	pending_level_ups = maxi(pending_level_ups - 1, 0)
	is_selecting_upgrade = false
	_current_options.clear()
	if pending_level_ups > 0:
		_try_present_level_up()
	else:
		get_tree().paused = false
		level_up_finished.emit(level)

func _try_present_level_up() -> void:
	if is_selecting_upgrade or pending_level_ups <= 0:
		return
	if _upgrade_manager == null or not _upgrade_manager.has_method("get_upgrade_choices"):
		return
	_current_options = _upgrade_manager.get_upgrade_choices(3)
	if _current_options.is_empty():
		pending_level_ups = 0
		get_tree().paused = false
		return
	is_selecting_upgrade = true
	get_tree().paused = true
	level_up_choices_ready.emit(_current_options, pending_level_ups)

func _required_for_next_level() -> int:
	var index := clampi(level - 1, 0, level_curve.size() - 1)
	var required := level_curve[index]
	if level > level_curve.size():
		required = int(round(float(level_curve[level_curve.size() - 1]) * pow(1.18, float(level - level_curve.size()))))
	return maxi(required, 1)

func _on_orb_collected(value: int) -> void:
	add_experience(value)

func _emit_experience_changed() -> void:
	experience_changed.emit(current_experience, _required_for_next_level(), level)