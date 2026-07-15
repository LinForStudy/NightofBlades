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

@onready var health: Node = %HealthComponent
@onready var hurtbox: Area2D = %Hurtbox
@onready var attack_hitbox: Area2D = %AttackHitbox
@onready var body: ColorRect = %Body
@onready var visual: EnemyVisual = get_node_or_null("EnemyVisual") as EnemyVisual
@onready var label: Label = %NameLabel
@onready var warning: ColorRect = %Warning

var current_state := EnemyState.IDLE
var target: Node2D
var facing_direction := -1
var _state_timer := 0.0
var _attack_cooldown := 0.0
var _dead := false
var _base_color := Color(0.7, 0.18, 0.18, 1)
var _display_color := Color(0.7, 0.18, 0.18, 1)
var _entry_target_x: float = NAN
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
		if warning != null:
			warning.visible = true
		if _state_timer <= 0.0:
			_explode()
		return
	if distance <= explosion_range:
		_set_state(EnemyState.WINDUP)
		_state_timer = 1.0
	else:
		_chase_target(delta, _data_move_speed())

func _process_flying(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + Vector2(-120.0 * float(facing_direction), -flying_hover_height)
	global_position = global_position.lerp(desired, 1.0 - exp(-2.8 * delta))
	velocity = Vector2.ZERO
	if _attack_cooldown <= 0.0:
		_fire_projectile()
		_attack_cooldown = _data_attack_interval()

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
	if warning != null:
		warning.color = Color(1.0, 0.62, 0.12, 0.62)
		warning.visible = true

func _execute_melee_attack() -> void:
	_set_state(EnemyState.COOLDOWN)
	attack_started.emit(self)
	_attack_cooldown = _data_attack_interval()
	if warning != null:
		warning.visible = false
	attack_hitbox.activate(self, _data_damage(), 160.0, facing_direction, 0.14, [StringName("enemy_melee")])

func _fire_projectile() -> void:
	if target == null:
		return
	attack_started.emit(self)
	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.get_node("World/ProjectileRoot").add_child(projectile)
	projectile.global_position = global_position + Vector2(18.0 * float(facing_direction), -42.0)
	projectile.launch(self, (target.global_position + Vector2(0, -28) - projectile.global_position).normalized(), _data_damage())

func _explode() -> void:
	attack_started.emit(self)
	attack_hitbox.activate(self, _data_damage(), 260.0, facing_direction, 0.18, [StringName("explode")])
	_die(null)

func _on_damaged(_amount: float, _context: Variant) -> void:
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
	if warning != null:
		warning.visible = false
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
		visual.set_tint(_display_color)

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