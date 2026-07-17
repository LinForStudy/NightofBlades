class_name PlayerController
extends CharacterBody2D

signal state_changed(new_state: StringName)
signal attack_landed(context: Variant)
signal dodge_started
signal perfect_dodge(context: Variant)
signal ultimate_energy_changed(current: float, maximum: float)
signal player_died(player: Node)

enum PlayerState { IDLE, RUN, JUMP, FALL, ATTACK, CHARGE, DODGE, HURT, DEAD }

@export var move_speed := 260.0
@export var acceleration := 1800.0
@export var friction := 2200.0
@export var air_control := 0.78
@export var jump_velocity := -430.0
@export var gravity := 1200.0
@export var max_fall_speed := 820.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12
@export var attack_buffer_time := 0.15
@export var charge_windup := 0.52
@export var dodge_buffer_time := 0.10
@export var dodge_cooldown := 1.0
@export var dodge_duration := 0.18
@export var dodge_speed := 720.0
@export var perfect_dodge_window := 0.12
@export var ultimate_energy_max := 100.0
@export var hurt_duration := 0.18
@export var world_bounds := Rect2(18.0, -80.0, 2364.0, 728.0)

@onready var health: HealthComponent = $HealthComponent
@onready var visual_pivot: Node2D = %VisualPivot
@onready var state_label: Label = %StateLabel
@onready var attack_hitbox: Area2D = %AttackHitbox
@onready var attack_arc: ColorRect = %AttackArc
@onready var hurtbox: Area2D = %Hurtbox
@onready var afterimage: ColorRect = %DodgeAfterimage
@onready var hit_flash: ColorRect = %HitFlash
@onready var player_visual: PlayerVisual = %PlayerVisual

var current_state: PlayerState = PlayerState.IDLE
var facing_direction := 1
var ultimate_energy := 0.0
var attack_damage_multiplier := 1.0
var attack_speed_multiplier := 1.0
var critical_chance := 0.0
var critical_damage_multiplier := 1.6
var ultimate_gain_multiplier := 1.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _attack_buffer_timer := 0.0
var _dodge_buffer_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _dodge_timer := 0.0
var _perfect_window_timer := 0.0
var _perfect_dodge_triggered := false
var _hurt_timer := 0.0
var _death_handled := false
var _attack_index := 0
var _attack_elapsed := 0.0
var _queued_combo := false
var _attack_hitbox_fired := false
var _attack_feedback_sent := false

var _attacks: Array[Dictionary] = [
	{"damage": 10.0, "duration": 0.24, "active_start": 0.07, "active_end": 0.13, "combo_open": 0.12, "knockback": 180.0, "label": "attack_1"},
	{"damage": 12.0, "duration": 0.30, "active_start": 0.09, "active_end": 0.16, "combo_open": 0.15, "knockback": 210.0, "label": "attack_2"},
	{"damage": 20.0, "duration": 0.40, "active_start": 0.12, "active_end": 0.22, "combo_open": 0.18, "knockback": 300.0, "label": "attack_3"}
]
var _air_attack: Dictionary = {"damage": 16.0, "duration": 0.34, "active_start": 0.07, "active_end": 0.18, "combo_open": 0.0, "knockback": 230.0, "label": "air_attack"}
var _charge_attack: Dictionary = {"damage": 42.0, "duration": 0.46, "active_start": 0.05, "active_end": 0.19, "combo_open": 0.0, "knockback": 420.0, "label": "charge_attack"}
var _active_attack: Dictionary = {}
var _active_attack_allows_combo := true
var _charge_timer := 0.0

func _ready() -> void:
	attack_hitbox.hit_confirmed.connect(_on_attack_hit_confirmed)
	health.damaged.connect(_on_health_damaged)
	health.depleted.connect(_on_health_depleted)
	if hurtbox.has_signal("hit_ignored"):
		hurtbox.hit_ignored.connect(_on_hurtbox_hit_ignored)
	if attack_arc != null:
		attack_arc.visible = false
	if afterimage != null:
		afterimage.visible = false
	if hit_flash != null:
		hit_flash.visible = false
	ProgressionManager.apply_to_player(self)
	_set_state(PlayerState.IDLE)
	ultimate_energy_changed.emit(ultimate_energy, ultimate_energy_max)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if current_state == PlayerState.DEAD:
		velocity = Vector2.ZERO
		return
	_capture_jump_input()
	_capture_attack_input()
	_capture_charge_input()
	_capture_dodge_input()
	_try_drop_through_platform()

	if current_state == PlayerState.DODGE:
		_process_dodge(delta)
	elif current_state == PlayerState.CHARGE:
		_process_charge(delta)
		_apply_attack_motion(delta)
	elif current_state == PlayerState.ATTACK:
		_process_attack(delta)
		_apply_attack_motion(delta)
	elif current_state == PlayerState.HURT:
		_process_hurt(delta)
	else:
		_apply_horizontal_motion(delta)
		_try_dodge()
		_try_jump()

	_apply_gravity(delta)
	move_and_slide()
	_clamp_to_world_bounds()
	_update_floor_memory()
	_update_state()
	_update_visual_direction()

func get_state_name() -> StringName:
	return StringName(PlayerState.keys()[current_state].to_lower())

func can_dodge() -> bool:
	return _dodge_cooldown_timer <= 0.0 and current_state not in [PlayerState.DODGE, PlayerState.HURT, PlayerState.DEAD]

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	_dodge_buffer_timer = maxf(_dodge_buffer_timer - delta, 0.0)
	_dodge_cooldown_timer = maxf(_dodge_cooldown_timer - delta, 0.0)
	_perfect_window_timer = maxf(_perfect_window_timer - delta, 0.0)

func _capture_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

func _capture_attack_input() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	if not is_on_floor() and current_state not in [PlayerState.HURT, PlayerState.DEAD, PlayerState.DODGE]:
		_attack_buffer_timer = 0.0
		velocity.y = maxf(velocity.y, 180.0)
		_start_attack(0, _air_attack, false)
		return

	_attack_buffer_timer = attack_buffer_time
	if current_state == PlayerState.ATTACK and _can_queue_combo():
		_queued_combo = true

func _capture_charge_input() -> void:
	if not Input.is_action_just_pressed("charge_attack"):
		return
	if not is_on_floor() or current_state not in [PlayerState.IDLE, PlayerState.RUN]:
		return
	_charge_timer = charge_windup
	_attack_buffer_timer = 0.0
	attack_hitbox.deactivate()
	_update_attack_arc(true)
	attack_arc.color = Color(1.0, 0.42, 0.14, 0.64)
	_set_state(PlayerState.CHARGE)

func _try_drop_through_platform() -> void:
	if Input.is_action_just_pressed("drop_down") and is_on_floor():
		set_collision_mask_value(2, false)
		await get_tree().create_timer(0.18).timeout
		set_collision_mask_value(2, true)

func _capture_dodge_input() -> void:
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer_timer = dodge_buffer_time

func _apply_horizontal_motion(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * move_speed
	var control := 1.0 if is_on_floor() else air_control
	var rate := (acceleration if not is_zero_approx(direction) else friction) * control
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	if not is_zero_approx(direction):
		facing_direction = signi(int(direction))

func _apply_attack_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.45 * delta)

func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return

	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_set_state(PlayerState.JUMP)

func _try_dodge() -> void:
	if _dodge_buffer_timer <= 0.0 or not can_dodge():
		return
	_start_dodge()

func _start_dodge() -> void:
	_dodge_buffer_timer = 0.0
	_dodge_cooldown_timer = dodge_cooldown
	_dodge_timer = dodge_duration
	_perfect_window_timer = perfect_dodge_window
	_perfect_dodge_triggered = false
	velocity.x = float(facing_direction) * dodge_speed
	velocity.y = minf(velocity.y, 0.0)
	attack_hitbox.deactivate()
	_update_attack_arc(false)
	_set_invincible(true)
	_set_state(PlayerState.DODGE)
	_set_afterimage(true)
	dodge_started.emit()

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if _hurt_timer <= 0.0:
		_set_invincible(false)
		_set_state(PlayerState.IDLE if is_on_floor() else PlayerState.FALL)

func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	velocity.x = float(facing_direction) * dodge_speed
	if _dodge_timer <= 0.0:
		_end_dodge()

func _end_dodge() -> void:
	_set_invincible(false)
	_set_afterimage(false)
	_perfect_window_timer = 0.0
	velocity.x = move_toward(velocity.x, 0.0, 120.0)
	_set_state(PlayerState.IDLE if is_on_floor() else PlayerState.FALL)

func _try_start_attack() -> void:
	if _attack_buffer_timer <= 0.0:
		return
	if current_state in [PlayerState.HURT, PlayerState.DEAD, PlayerState.ATTACK, PlayerState.DODGE]:
		return

	_attack_buffer_timer = 0.0
	_start_attack(0)

func _start_attack(index: int, profile_override: Dictionary = {}, allows_combo := true) -> void:
	_attack_index = clampi(index, 0, _attacks.size() - 1)
	_active_attack = profile_override if not profile_override.is_empty() else _attacks[_attack_index]
	_active_attack_allows_combo = allows_combo
	_attack_elapsed = 0.0
	_queued_combo = false
	_attack_hitbox_fired = false
	_attack_feedback_sent = false
	attack_hitbox.deactivate()
	_set_state(PlayerState.ATTACK)
	if player_visual != null:
		player_visual.play_action(StringName(_active_attack.get("label", "attack_1")))
	_update_attack_arc(false)

func _process_attack(delta: float) -> void:
	_attack_elapsed += delta
	var attack: Dictionary = _active_attack
	var attack_speed_scale := 1.0 / maxf(attack_speed_multiplier, 0.1)
	var active_start: float = float(attack["active_start"]) * attack_speed_scale
	var active_end: float = float(attack["active_end"]) * attack_speed_scale

	if not _attack_hitbox_fired and _attack_elapsed >= active_start:
		_attack_hitbox_fired = true
		var active_time := maxf(active_end - active_start, 0.04)
		var attack_damage := _roll_attack_damage(float(attack["damage"]))
		attack_hitbox.activate(self, attack_damage, attack["knockback"], facing_direction, active_time, [StringName(attack["label"])])
		_update_attack_arc(true)
		if player_visual != null:
			player_visual.play_slash()

	if _attack_elapsed >= active_end:
		_update_attack_arc(false)

	if _attack_elapsed >= float(attack["duration"]) * attack_speed_scale:
		attack_hitbox.deactivate()
		if _active_attack_allows_combo and _queued_combo and _attack_index < _attacks.size() - 1:
			_start_attack(_attack_index + 1)
		else:
			_attack_index = 0
			_active_attack = {}
			_set_state(PlayerState.IDLE if is_on_floor() else PlayerState.FALL)

func _process_charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_start_attack(0, _charge_attack, false)

func _apply_gravity(delta: float) -> void:
	if current_state == PlayerState.DODGE:
		return
	if is_on_floor() and velocity.y >= 0.0:
		return

	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

func _update_floor_memory() -> void:
	if is_on_floor():
		_coyote_timer = coyote_time

func _update_state() -> void:
	if current_state in [PlayerState.ATTACK, PlayerState.CHARGE, PlayerState.DODGE, PlayerState.HURT, PlayerState.DEAD]:
		return

	_try_dodge()
	if current_state == PlayerState.DODGE:
		return

	_try_start_attack()
	if current_state == PlayerState.ATTACK:
		return

	if not is_on_floor():
		_set_state(PlayerState.JUMP if velocity.y < 0.0 else PlayerState.FALL)
		return

	if absf(velocity.x) > 5.0:
		_set_state(PlayerState.RUN)
	else:
		_set_state(PlayerState.IDLE)

func _can_queue_combo() -> bool:
	if _attack_index >= _attacks.size() - 1:
		return false
	return _attack_elapsed >= float(_attacks[_attack_index]["combo_open"])

func _set_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	var state_name := get_state_name()
	if state_label != null:
		state_label.text = "State: %s" % state_name
	state_changed.emit(state_name)
	if player_visual != null:
		player_visual.play_action(state_name)

func _set_invincible(value: bool) -> void:
	if hurtbox != null and hurtbox.has_method("set_invincible"):
		hurtbox.set_invincible(value)

func _set_afterimage(is_visible: bool) -> void:
	if afterimage != null:
		afterimage.visible = is_visible

func _update_visual_direction() -> void:
	if visual_pivot == null:
		return
	visual_pivot.scale.x = float(facing_direction)

func _update_attack_arc(is_visible: bool) -> void:
	if attack_arc == null:
		return
	attack_arc.visible = is_visible
	attack_arc.color = Color(1.0, 0.83, 0.28, 0.72)

func apply_passive_upgrade(effect_key: StringName, effect_value: float, _stack_count: int, _upgrade: Resource) -> void:
	match String(effect_key):
		"attack_damage_multiplier":
			attack_damage_multiplier += effect_value
		"attack_speed_multiplier":
			attack_speed_multiplier += effect_value
		"move_speed_bonus":
			move_speed += effect_value
		"max_health_bonus":
			if health != null:
				health.max_health += effect_value
				health.current_health = minf(health.current_health + effect_value, health.max_health)
				health.health_changed.emit(health.current_health, health.max_health)
		"dodge_cooldown_reduction":
			dodge_cooldown = maxf(dodge_cooldown - effect_value, 0.35)
		"perfect_dodge_window_bonus":
			perfect_dodge_window = minf(perfect_dodge_window + effect_value, 0.32)
		"critical_chance_bonus":
			critical_chance = minf(critical_chance + effect_value, 0.75)
		"ultimate_gain_multiplier":
			ultimate_gain_multiplier += effect_value

func consume_ultimate_energy() -> bool:
	if ultimate_energy < ultimate_energy_max or current_state == PlayerState.DEAD:
		return false
	ultimate_energy = 0.0
	ultimate_energy_changed.emit(ultimate_energy, ultimate_energy_max)
	return true

func set_ultimate_invincible(value: bool) -> void:
	_set_invincible(value)

func can_cast_active_skill() -> bool:
	return current_state not in [PlayerState.HURT, PlayerState.DEAD]

func perform_skill_dash(direction: Vector2, distance: float, invincible_duration: float) -> void:
	if current_state == PlayerState.DEAD:
		return
	var dash_direction := direction.normalized()
	if is_zero_approx(dash_direction.length()):
		dash_direction = Vector2(float(facing_direction), 0.0)
	facing_direction = 1 if dash_direction.x >= 0.0 else -1
	_update_visual_direction()
	_set_invincible(true)
	global_position += dash_direction * distance
	_clamp_to_world_bounds()
	await get_tree().create_timer(maxf(invincible_duration, 0.05), true, false, true).timeout
	if current_state != PlayerState.DODGE and current_state != PlayerState.DEAD:
		_set_invincible(false)

func _clamp_to_world_bounds() -> void:
	var minimum := world_bounds.position
	var maximum := world_bounds.end
	var clamped_position := Vector2(
		clampf(global_position.x, minimum.x, maximum.x),
		clampf(global_position.y, minimum.y, maximum.y)
	)
	if not is_equal_approx(clamped_position.x, global_position.x):
		velocity.x = 0.0
	if not is_equal_approx(clamped_position.y, global_position.y):
		velocity.y = 0.0
	global_position = clamped_position

func _roll_attack_damage(base_damage: float) -> float:
	var damage := base_damage * attack_damage_multiplier
	if critical_chance > 0.0 and randf() < critical_chance:
		damage *= critical_damage_multiplier
	return damage
func _on_attack_hit_confirmed(_hurtbox: Area2D, context: Variant) -> void:
	attack_landed.emit(context)
	if player_visual != null:
		player_visual.play_hit(context.get("hit_position", global_position + Vector2(82.0 * float(facing_direction), -48.0)))
	var battle := get_tree().current_scene
	if battle != null and battle.has_method("spawn_damage_number"):
		battle.spawn_damage_number(float(context.get("final_damage", 0.0)), context.get("hit_position", global_position) + Vector2(8, -42))
	if not _attack_feedback_sent and battle != null and battle.has_method("request_hit_feedback"):
		_attack_feedback_sent = true
		battle.request_hit_feedback(_attack_index)

func _on_health_damaged(_amount: float, context: Variant) -> void:
	if current_state == PlayerState.DEAD:
		return
	_hurt_timer = hurt_duration
	var knockback: Vector2 = context.get("knockback", Vector2.ZERO)
	velocity = knockback
	_set_invincible(true)
	_set_state(PlayerState.HURT)
	_show_hit_feedback()

func _show_hit_feedback() -> void:
	if hit_flash != null:
		hit_flash.visible = true
	var battle := get_tree().current_scene
	if battle != null and battle.has_method("request_player_hit_feedback"):
		battle.request_player_hit_feedback(global_position)
	await get_tree().create_timer(0.12, false, true).timeout
	if hit_flash != null and current_state != PlayerState.DEAD:
		hit_flash.visible = false

func _on_health_depleted(_context: Variant) -> void:
	if _death_handled:
		return
	_death_handled = true
	velocity = Vector2.ZERO
	_set_invincible(true)
	attack_hitbox.deactivate()
	_update_attack_arc(false)
	_set_state(PlayerState.DEAD)
	player_died.emit(self)

func _on_hurtbox_hit_ignored(context: Variant) -> void:
	if current_state != PlayerState.DODGE or _perfect_dodge_triggered or _perfect_window_timer <= 0.0:
		return
	_perfect_dodge_triggered = true
	ultimate_energy = minf(ultimate_energy + 8.0 * ultimate_gain_multiplier, ultimate_energy_max)
	ultimate_energy_changed.emit(ultimate_energy, ultimate_energy_max)
	perfect_dodge.emit(context)
	var battle := get_tree().current_scene
	if battle != null and battle.has_method("request_perfect_dodge_feedback"):
		battle.request_perfect_dodge_feedback(global_position)