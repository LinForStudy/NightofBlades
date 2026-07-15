class_name WaveManager
extends Node

signal enemy_spawned(enemy: Node)
signal enemy_recycled(enemy: Node)
signal wave_changed(wave: Resource)
signal final_boss_ready()

@export var waves: Array[Resource] = []
@export var enemy_root_path: NodePath
@export var player_path: NodePath
@export var ground_spawn_points_path: NodePath
@export var air_spawn_points_path: NodePath
@export var prewarm_per_enemy := 2
@export var auto_start := true
@export var elite_modifiers: Array[Resource] = []
@export var final_boss_time := 720.0

var elapsed_time := 0.0
var is_running := false
var current_wave: Resource

var _spawn_timer := 0.0
var _final_boss_emitted := false
var _alive_enemies: Array[Node] = []
var _enemy_root: Node
var _player: Node2D
var _ground_spawn_points: Node
var _air_spawn_points: Node
var _pool_ids_by_enemy: Dictionary = {}

func _ready() -> void:
	_enemy_root = get_node_or_null(enemy_root_path)
	_player = get_node_or_null(player_path) as Node2D
	_ground_spawn_points = get_node_or_null(ground_spawn_points_path)
	_air_spawn_points = get_node_or_null(air_spawn_points_path)
	_register_wave_pools()
	if auto_start:
		start_waves()

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	elapsed_time += delta
	if not _final_boss_emitted and elapsed_time >= final_boss_time:
		_final_boss_emitted = true
		stop_waves()
		final_boss_ready.emit()
		return
	_update_current_wave()
	if current_wave == null:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(float(current_wave.spawn_interval), 0.1)
		_try_spawn_enemy()
func start_waves() -> void:
	is_running = true
	elapsed_time = 0.0
	_spawn_timer = 0.1
	_final_boss_emitted = false
	_update_current_wave()

func stop_waves() -> void:
	is_running = false

func get_alive_count() -> int:
	_cleanup_alive_list()
	return _alive_enemies.size()

func clear_active_enemies() -> void:
	_cleanup_alive_list()
	var active_enemies: Array[Node] = []
	for enemy in _alive_enemies:
		active_enemies.append(enemy)
	_alive_enemies.clear()
	for enemy in active_enemies:
		_recycle_enemy(enemy)

func force_spawn_once() -> Node:
	_update_current_wave()
	return _try_spawn_enemy(true)

func _register_wave_pools() -> void:
	var registered: Dictionary = {}
	for wave in waves:
		if wave == null:
			continue
		for scene in wave.enemy_scenes:
			if scene == null:
				continue
			var pool_id := _pool_id_for_scene(scene)
			if registered.has(pool_id):
				continue
			registered[pool_id] = true
			ObjectPoolManager.register_pool(pool_id, Callable(scene, "instantiate"), prewarm_per_enemy)

func _instantiate_enemy(scene: PackedScene) -> Node:
	return scene.instantiate()

func _update_current_wave() -> void:
	var next_wave: Resource = null
	for wave in waves:
		if wave == null:
			continue
		if elapsed_time >= float(wave.start_time) and elapsed_time < float(wave.end_time):
			next_wave = wave
			break
	if next_wave != current_wave:
		current_wave = next_wave
		wave_changed.emit(current_wave)

func _try_spawn_enemy(ignore_alive_limit := false) -> Node:
	if current_wave == null or _enemy_root == null:
		return null
	_cleanup_alive_list()
	if not ignore_alive_limit and _alive_enemies.size() >= int(current_wave.max_alive):
		return null
	var scene := _choose_enemy_scene(current_wave)
	if scene == null:
		return null
	var pool_id := _pool_id_for_scene(scene)
	var enemy := ObjectPoolManager.get_object(pool_id) as Node
	if enemy == null:
		return null
	if enemy.get_parent() != null:
		enemy.get_parent().remove_child(enemy)
	_enemy_root.add_child(enemy)
	enemy.global_position = _choose_spawn_position(scene)
	_pool_ids_by_enemy[enemy] = pool_id
	_alive_enemies.append(enemy)
	if enemy.has_method("reset_enemy"):
		enemy.reset_enemy()
	if enemy.has_method("apply_wave_scaling"):
		enemy.apply_wave_scaling(float(current_wave.health_multiplier), float(current_wave.damage_multiplier), float(current_wave.speed_multiplier))
	if randf() < float(current_wave.elite_chance) and enemy.has_method("apply_elite"):
		var elite_modifier: Resource = _choose_elite_modifier()
		if elite_modifier != null:
			enemy.apply_elite(elite_modifier)
	if enemy.has_method("begin_entry"):
		enemy.begin_entry(_entry_target_x(enemy.global_position.x))
	if enemy.has_signal("enemy_died") and not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died)
	enemy_spawned.emit(enemy)
	return enemy

func _choose_elite_modifier() -> Resource:
	if elite_modifiers.is_empty():
		return null
	var valid_modifiers: Array[Resource] = []
	for modifier in elite_modifiers:
		if modifier != null:
			valid_modifiers.append(modifier)
	return valid_modifiers.pick_random() if not valid_modifiers.is_empty() else null
func _choose_enemy_scene(wave: Resource) -> PackedScene:
	if wave.enemy_scenes.is_empty():
		return null
	var weights: Array[int] = wave.enemy_weights
	var total := 0
	for index in wave.enemy_scenes.size():
		var weight := 1
		if index < weights.size():
			weight = maxi(weights[index], 0)
		total += weight
	if total <= 0:
		return wave.enemy_scenes[0]
	var roll := randi_range(1, total)
	var cursor := 0
	for index in wave.enemy_scenes.size():
		var weight := 1
		if index < weights.size():
			weight = maxi(weights[index], 0)
		cursor += weight
		if roll <= cursor:
			return wave.enemy_scenes[index]
	return wave.enemy_scenes[0]

func _choose_spawn_position(scene: PackedScene) -> Vector2:
	var points := _air_spawn_points if _is_air_enemy(scene) else _ground_spawn_points
	if points == null or points.get_child_count() == 0:
		return Vector2(900, 570)
	var candidates: Array[Node2D] = []
	for child in points.get_children():
		if child is Node2D:
			candidates.append(child)
	if candidates.is_empty():
		return Vector2(900, 570)
	if _player == null:
		return candidates.pick_random().global_position
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)
	return candidates[0].global_position

func _entry_target_x(spawn_x: float) -> float:
	if _player == null:
		return spawn_x
	var direction: float = signf(spawn_x - _player.global_position.x)
	if is_zero_approx(direction):
		direction = 1.0
	return clampf(_player.global_position.x + direction * 620.0, 20.0, 2380.0)

func _is_air_enemy(scene: PackedScene) -> bool:
	return scene.resource_path.find("flying_eye") >= 0

func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies.erase(enemy)
	_recycle_enemy(enemy)

func _recycle_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	var pool_id: StringName = _pool_ids_by_enemy.get(enemy, StringName(""))
	if enemy.get_parent() != null:
		enemy.get_parent().remove_child(enemy)
	if pool_id != StringName(""):
		ObjectPoolManager.recycle_object(pool_id, enemy)
	enemy_recycled.emit(enemy)

func _cleanup_alive_list() -> void:
	_alive_enemies = _alive_enemies.filter(func(enemy: Node) -> bool:
		return enemy != null and is_instance_valid(enemy) and enemy.get_parent() != null and enemy.visible
	)

func _pool_id_for_scene(scene: PackedScene) -> StringName:
	return StringName(scene.resource_path)