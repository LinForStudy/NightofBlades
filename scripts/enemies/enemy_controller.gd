class_name EnemyController
extends CharacterBody2D

signal enemy_died(enemy: Node)
signal attack_started(enemy: Node)

enum Behavior { MELEE, ARCHER, BOMBER, FLYING }
enum EnemyState { IDLE, CHASE, AIM, ATTACK, COOLDOWN, RETREAT, WINDUP, DEAD }

const PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")

@export var enemy_data: Resource
@export var behavior := Behavior.MELEE
@export var gravity := 1200.0
@export var max_fall_speed := 820.0
@export var explosion_range := 90.0
@export var flying_hover_height := 92.0
@export var projectile_scene: PackedScene = PROJECTILE_SCENE
@export var projectile_offset := Vector2(18.0, -42.0)
@export var flying_recoil_duration := 0.24
@export var flying_recoil_speed := 230.0

@onready var health: Node = %HealthComponent
@onready var hurtbox: Area2D = %Hurtbox
@onready var attack_hitbox: Area2D = %AttackHitbox
@onready var body: ColorRect = %Body
@onready var visual: EnemyVisual = get_node_or_null("EnemyVisual") as EnemyVisual
@onready var label: Label = %NameLabel
@onready var warning: CanvasItem = %Warning

var current_state := EnemyState.IDLE
var target: Node2D
var facing_direction := -1
var _state_timer := 0.0
var _attack_cooldown := 0.0
var _dead := false
var _base_color := Color(0.7, 0.18, 0.18, 1)
var _display_color := Color(0.7, 0.18, 0.18, 1)
var _entry_target_x: float = NAN
var _explosion_committed := false
var _flying_recoil_timer := 0.0
var _flying_recoil_velocity := Vector2.ZERO
var is_elite := false
var _wave_health_multiplier := 1.0
var _wave_damage_multiplier := 1.0
var _wave_speed_multiplier := 1.0
var _elite_health_multiplier := 1.0
var _elite_damage_multiplier := 1.0
var _elite_speed_multiplier := 1.0
var _elite_experience_multiplier := 1.0

func _ready() -> void:
	_resolve_target()
	_apply_data()
	if health != null:
		health.damaged.connect(_on_damaged)
		health.depleted.connect(_on_depleted)
	if warning != null:
		warning.visible = false
	_set_state(EnemyState.CHASE)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_resolve_target()
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_state_timer = maxf(_state_timer - delta, 0.0)
	if _process_entry(delta):
		return

	match behavior:
		Behavior.MELEE:
			_process_melee(delta)
		Behavior.ARCHER:
			_process_archer(delta)
		Behavior.BOMBER:
			_process_bomber(delta)
		Behavior.FLYING:
			_process_flying(delta)

	if behavior != Behavior.FLYING and not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	_update_facing()

func reset_enemy() -> void:
	_dead = false
	_explosion_committed = false
	_flying_recoil_timer = 0.0
	_flying_recoil_velocity = Vector2.ZERO
	_attack_cooldown = 0.0
	_state_timer = 0.0
	velocity = Vector2.ZERO
	visible = true
	set_physics_process(true)
	_reset_runtime_modifiers()
	_apply_data()
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", true)
	_entry_target_x = NAN
	_set_state(EnemyState.CHASE)

func apply_wave_scaling(health_multiplier: float, damage_multiplier: float, speed_multiplier: float) -> void:
	_wave_health_multiplier = maxf(health_multiplier, 0.1)
	_wave_damage_multiplier = maxf(damage_multiplier, 0.1)
	_wave_speed_multiplier = maxf(speed_multiplier, 0.1)
	_refresh_runtime_stats()

func apply_elite(modifier: Resource) -> void:
	if modifier == null:
		return
	is_elite = true
	_elite_health_multiplier = maxf(float(modifier.get("health_multiplier")), 0.1)
	_elite_damage_multiplier = maxf(float(modifier.get("damage_multiplier")), 0.1)
	_elite_speed_multiplier = maxf(float(modifier.get("speed_multiplier")), 0.1)
	_elite_experience_multiplier = maxf(float(modifier.get("experience_multiplier")), 1.0)
	var color_value: Variant = modifier.get("body_color")
	if color_value is Color:
		_display_color = color_value
	_refresh_runtime_stats()
	if label != null:
		var base_name: String = enemy_data.display_name if enemy_data != null else "Enemy"
		label.text = "[精英·%s] %s" % [modifier.get("display_name"), base_name]

func get_experience_value() -> int:
	var base_value: float = enemy_data.experience_value if enemy_data != null else 5.0
	return maxi(int(round(base_value * _elite_experience_multiplier)), 1)

func _reset_runtime_modifiers() -> void:
	is_elite = false
	_wave_health_multiplier = 1.0
	_wave_damage_multiplier = 1.0
	_wave_speed_multiplier = 1.0
	_elite_health_multiplier = 1.0
	_elite_damage_multiplier = 1.0
	_elite_speed_multiplier = 1.0
	_elite_experience_multiplier = 1.0

func begin_entry(target_x: float) -> void:
	_entry_target_x = target_x
	velocity = Vector2.ZERO

func _process_entry(delta: float) -> bool:
	if is_nan(_entry_target_x):
		return false
	var remaining_x := _entry_target_x - global_position.x
	if absf(remaining_x) <= 4.0:
		_entry_target_x = NAN
		return false
	var direction := signf(remaining_x)
	facing_direction = 1 if direction >= 0.0 else -1
	if behavior == Behavior.FLYING:
		global_position.x = move_toward(global_position.x, _entry_target_x, _data_move_speed() * 3.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * _data_move_speed() * 3.0, 1000.0 * delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()
	_update_facing()
	return true

func _process_melee(delta: float) -> void:
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return
	if current_state == EnemyState.WINDUP:
		velocity.x = 0.0
		if _state_timer <= 0.0:
			_execute_melee_attack()
		return
	var distance := target.global_position.distance_to(global_position)
	if distance <= _data_attack_range() and _attack_cooldown <= 0.0:
		_start_melee_windup()
	else:
		_chase_target(delta, _data_move_speed())

func _process_archer(delta: float) -> void:
	if target == null:
		return
	var distance_x := absf(target.global_position.x - global_position.x)
	if current_state == EnemyState.AIM and _state_timer <= 0.0:
		_fire_projectile()
		_set_state(EnemyState.COOLDOWN)
		_attack_cooldown = _data_attack_interval()
	elif _attack_cooldown <= 0.0 and distance_x <= _data_preferred_range() + 40.0:
		velocity.x = 0.0
		_set_state(EnemyState.AIM)
		_state_timer = _data_aim_time()
	elif distance_x < _data_preferred_range() * 0.65:
		_retreat_from_target(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

func _process_bomber(delta: float) -> void:
	if target == null:
		return
	var distance := target.global_position.distance_to(global_position)
	if current_state == EnemyState.WINDUP:
		velocity.x = 0.0
		_show_warning(Color(1.0, 0.18, 0.22, 0.86))
		if _state_timer <= 0.0:
			_explode()
		return
	if distance <= explosion_range:
		_set_state(EnemyState.WINDUP)
		_state_timer = maxf(_data_aim_time(), 0.1)
		velocity.x = 0.0
		_show_warning(Color(1.0, 0.18, 0.22, 0.86))
	else:
		_chase_target(delta, _data_move_speed())

func _process_flying(delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return
	if _flying_recoil_timer > 0.0:
		_flying_recoil_timer = maxf(_flying_recoil_timer - delta, 0.0)
		velocity = _flying_recoil_velocity
		_flying_recoil_velocity = _flying_recoil_velocity.move_toward(Vector2.ZERO, flying_recoil_speed * 3.0 * delta)
		return
	if current_state == EnemyState.AIM:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		if _state_timer <= 0.0:
			_fire_projectile()
			_attack_cooldown = _data_attack_interval()
			_hide_warning()
			_set_state(EnemyState.COOLDOWN)
		return
	var horizontal_side := 1.0 if global_position.x >= target.global_position.x else -1.0
	var horizontal_offset := clampf(_data_preferred_range() * 0.5, 100.0, 160.0)
	var desired := target.global_position + Vector2(horizontal_side * horizontal_offset, -flying_hover_height)
	var desired_velocity := (desired - global_position) * 2.8
	var maximum_speed := _data_move_speed() * 1.6
	velocity = desired_velocity.limit_length(maximum_speed)
	_set_state(EnemyState.CHASE)
	if _attack_cooldown <= 0.0 and target.global_position.distance_to(global_position) <= _data_attack_range():
		_set_state(EnemyState.AIM)
		_state_timer = maxf(_data_aim_time(), 0.2)
		velocity = Vector2.ZERO
		_show_warning(Color(0.72, 0.32, 1.0, 0.88))

func _chase_target(delta: float, speed: float) -> void:
	if target == null:
		return
	var direction := signf(target.global_position.x - global_position.x)
	velocity.x = move_toward(velocity.x, direction * speed, 700.0 * delta)
	_set_state(EnemyState.CHASE)

func _retreat_from_target(delta: float) -> void:
	var direction := -signf(target.global_position.x - global_position.x)
	velocity.x = move_toward(velocity.x, direction * _data_move_speed(), 700.0 * delta)
	_set_state(EnemyState.RETREAT)

func _start_melee_windup() -> void:
	_set_state(EnemyState.WINDUP)
	_state_timer = 0.28
	velocity.x = 0.0
	_show_warning(Color(1.0, 0.62, 0.12, 0.62))

func _execute_melee_attack() -> void:
	_set_state(EnemyState.COOLDOWN)
	attack_started.emit(self)
	_attack_cooldown = _data_attack_interval()
	_hide_warning()
	attack_hitbox.activate(self, _data_damage(), 160.0, facing_direction, 0.14, [StringName("enemy_melee")])

func _fire_projectile() -> void:
	if target == null:
		return
	var projectile_root: Node = _resolve_projectile_root()
	if projectile_root == null:
		return
	var selected_scene: PackedScene = projectile_scene if projectile_scene != null else PROJECTILE_SCENE
	var projectile_instance: Node = selected_scene.instantiate()
	if projectile_instance == null:
		return
	if not projectile_instance is Node2D:
		projectile_instance.free()
		return
	var projectile := projectile_instance as Node2D
	attack_started.emit(self)
	projectile_root.add_child(projectile)
	var offset := Vector2(absf(projectile_offset.x) * float(facing_direction), projectile_offset.y)
	projectile.global_position = global_position + offset
	if projectile.has_method("launch"):
		projectile.call("launch", self, (target.global_position + Vector2(0, -28) - projectile.global_position).normalized(), _data_damage())

func _resolve_projectile_root() -> Node:
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.name == &"World":
			var world_projectile_root: Node = ancestor.get_node_or_null("ProjectileRoot")
			if world_projectile_root != null:
				return world_projectile_root
		var nested_projectile_root: Node = ancestor.get_node_or_null("World/ProjectileRoot")
		if nested_projectile_root != null:
			return nested_projectile_root
		ancestor = ancestor.get_parent()
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		return scene_root.get_node_or_null("World/ProjectileRoot")
	return null

func _explode() -> void:
	if _dead or _explosion_committed:
		return
	_explosion_committed = true
	attack_started.emit(self)
	if attack_hitbox.has_method("activate_radial"):
		attack_hitbox.call("activate_radial", self, _data_damage(), 260.0, 0.18, [StringName("explode")])
	else:
		attack_hitbox.activate(self, _data_damage(), 260.0, facing_direction, 0.18, [StringName("explode")])
	velocity = Vector2.ZERO
	set_physics_process(false)
	await get_tree().create_timer(0.05, false, true).timeout
	if not _dead and _explosion_committed:
		_die(null)

func _on_damaged(_amount: float, context: Variant) -> void:
	if behavior == Behavior.FLYING and _is_player_melee_context(context):
		_start_flying_recoil(context)
	if visual != null:
		visual.play_hurt()
	if body != null:
		body.color = Color(1, 1, 1, 1)
		await get_tree().create_timer(0.08, false, true).timeout
		if body != null and not _dead:
			body.color = _display_color

func _on_depleted(context: Variant) -> void:
	_die(context)

func _die(_context: Variant) -> void:
	if _dead:
		return
	_dead = true
	_set_state(EnemyState.DEAD)
	if visual != null:
		visual.spawn_death_fx(global_position)
	velocity = Vector2.ZERO
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	if attack_hitbox != null and attack_hitbox.has_method("deactivate"):
		attack_hitbox.deactivate()
	_hide_warning()
	visible = false
	set_physics_process(false)
	enemy_died.emit(self)

func _apply_data() -> void:
	match behavior:
		Behavior.MELEE:
			_base_color = Color(0.75, 0.22, 0.18, 1)
		Behavior.ARCHER:
			_base_color = Color(0.75, 0.48, 0.18, 1)
		Behavior.BOMBER:
			_base_color = Color(0.86, 0.26, 0.45, 1)
		Behavior.FLYING:
			_base_color = Color(0.55, 0.3, 0.9, 1)
	_display_color = _base_color
	_refresh_runtime_stats()

func _refresh_runtime_stats() -> void:
	if health != null:
		var base_health: float = enemy_data.max_health if enemy_data != null else 30.0
		health.max_health = base_health * _wave_health_multiplier * _elite_health_multiplier
		health.reset_health()
	if label != null:
		label.text = enemy_data.display_name if enemy_data != null else "Enemy"
	if body != null:
		body.color = _display_color
	if visual != null:
		visual.set_tint(_display_color if is_elite else Color.WHITE)

func _resolve_target() -> void:
	if target != null and is_instance_valid(target):
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D

func _update_facing() -> void:
	if target != null:
		facing_direction = -1 if target.global_position.x < global_position.x else 1
	if body != null:
		body.scale.x = float(facing_direction)
	if visual != null:
		visual.set_facing(facing_direction)

func _set_state(new_state: EnemyState) -> void:
	current_state = new_state

func _start_flying_recoil(context: Variant) -> void:
	var knockback := Vector2.ZERO
	if context is Dictionary:
		var context_dictionary: Dictionary = context
		var knockback_value: Variant = context_dictionary.get("knockback", Vector2.ZERO)
		if knockback_value is Vector2:
			knockback = knockback_value
	if knockback.length_squared() < 0.001 and target != null:
		knockback = global_position - target.global_position
	if knockback.length_squared() < 0.001:
		knockback = Vector2.RIGHT * float(-facing_direction)
	_flying_recoil_velocity = knockback.normalized() * flying_recoil_speed + Vector2(0, -55.0)
	_flying_recoil_timer = flying_recoil_duration
	_attack_cooldown = maxf(_attack_cooldown, 0.45)
	_set_state(EnemyState.RETREAT)
	_hide_warning()

func _is_player_melee_context(context: Variant) -> bool:
	if not context is Dictionary:
		return false
	var context_dictionary: Dictionary = context
	var tags_value: Variant = context_dictionary.get("tags", [])
	if not tags_value is Array:
		return false
	for tag in tags_value:
		var tag_text := str(tag)
		if tag_text.begins_with("attack_") or tag_text in ["air_attack", "charge_attack"]:
			return true
	return false

func _show_warning(color: Color) -> void:
	if warning == null:
		return
	if warning is ColorRect:
		(warning as ColorRect).color = color
	elif warning is EnemyWarningVisual:
		(warning as EnemyWarningVisual).ring_color = color
	warning.visible = true

func _hide_warning() -> void:
	if warning != null:
		warning.visible = false

func _data_move_speed() -> float:
	return (enemy_data.move_speed if enemy_data != null else 60.0) * _wave_speed_multiplier * _elite_speed_multiplier

func _data_damage() -> float:
	return (enemy_data.base_damage if enemy_data != null else 8.0) * _wave_damage_multiplier * _elite_damage_multiplier

func _data_attack_range() -> float:
	return enemy_data.attack_range if enemy_data != null else 56.0

func _data_preferred_range() -> float:
	return enemy_data.preferred_range if enemy_data != null else 160.0

func _data_attack_interval() -> float:
	return enemy_data.attack_interval if enemy_data != null else 1.3

func _data_aim_time() -> float:
	return enemy_data.aim_time if enemy_data != null else 0.25