class_name RiftColossusController
extends CharacterBody2D

signal boss_health_changed(current: float, maximum: float)
signal boss_poise_changed(current: float, maximum: float)
signal boss_phase_changed(phase: int)
signal boss_announcement(message: String)
signal boss_died(boss: Node)
signal boss_defeated(boss: Node)

enum BossState { IDLE, WINDUP, ACTIVE, RECOVERY, TRANSITION, STAGGER, DEAD }

@export var max_health := 900.0
@export var phase_thresholds: Array[float] = [0.60, 0.25]
@export var engagement_range := 620.0
@export var max_poise := 120.0
@export var stagger_duration := 1.6
@export var poise_recovery_delay := 1.2
@export var poise_recovery_per_second := 24.0

@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var attack_hitbox: HitboxComponent = %AttackHitbox
@onready var attack_shape: CollisionShape2D = %AttackCollision
@onready var warning_area: ColorRect = %WarningArea

const ATTACKS: Array[Dictionary] = [
	{ "tag": &"boss_slam", "name": "砸地", "windup": 0.85, "active": 0.14, "recovery": 1.10, "cooldown": 1.50, "damage": 14.0, "knockback": 260.0, "offset": Vector2(-105, -36), "size": Vector2(210, 28), "warning_color": Color(1.0, 0.62, 0.12, 0.60) },
	{ "tag": &"boss_shockwave", "name": "冲击波", "windup": 0.95, "active": 0.18, "recovery": 1.20, "cooldown": 1.60, "damage": 18.0, "knockback": 280.0, "offset": Vector2(-195, -22), "size": Vector2(390, 20), "warning_color": Color(1.0, 0.35, 0.12, 0.58) },
	{ "tag": &"boss_charge", "name": "冲锋", "windup": 0.90, "active": 0.16, "recovery": 1.10, "cooldown": 1.50, "damage": 22.0, "knockback": 320.0, "offset": Vector2(-165, -54), "size": Vector2(330, 62), "warning_color": Color(0.95, 0.18, 0.20, 0.62) }
]

var phase := 1
var state: BossState = BossState.IDLE
var _state_timer := 1.15
var _attack_index := 0
var _current_attack: Dictionary = {}
var _target: Node2D
var _dead := false
var is_activated := false
var current_poise := 120.0
var _poise_recovery_timer := 0.0

func _ready() -> void:
	health.max_health = max_health
	health.current_health = max_health
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	warning_area.visible = false
	attack_hitbox.deactivate()
	hurtbox.set_deferred("monitorable", false)
	visible = false
	current_poise = max_poise
	boss_health_changed.emit(max_health, max_health)
	boss_poise_changed.emit(current_poise, max_poise)

func activate_boss(intro_delay := 1.5) -> void:
	if is_activated or _dead:
		return
	is_activated = true
	visible = true
	hurtbox.set_deferred("monitorable", true)
	boss_announcement.emit("裂隙巨像降临")
	_enter_state(BossState.IDLE, intro_delay)

func _physics_process(delta: float) -> void:
	if _dead or not is_activated:
		return
	_state_timer -= delta
	_update_poise_recovery(delta)
	match state:
		BossState.IDLE:
			if _state_timer <= 0.0 and _target_is_in_engagement_range():
				_begin_attack()
		BossState.WINDUP:
			if _state_timer <= 0.0:
				_begin_active_window()
		BossState.ACTIVE:
			if _state_timer <= 0.0:
				attack_hitbox.deactivate()
				warning_area.visible = false
				_enter_state(BossState.RECOVERY, float(_current_attack["recovery"]))
		BossState.RECOVERY:
			if _state_timer <= 0.0:
				_enter_state(BossState.IDLE, float(_current_attack["cooldown"]) * _phase_cooldown_factor())
		BossState.TRANSITION:
			if _state_timer <= 0.0:
				hurtbox.set_invincible(false)
				_enter_state(BossState.IDLE, 0.65)
		BossState.STAGGER:
			if _state_timer <= 0.0:
				current_poise = max_poise
				boss_poise_changed.emit(current_poise, max_poise)
				_enter_state(BossState.IDLE, 1.20)

func _begin_attack() -> void:
	_current_attack = ATTACKS[_attack_index % ATTACKS.size()]
	_attack_index += 1
	_target = get_tree().get_first_node_in_group(&"player") as Node2D
	if _target != null and _target.global_position.x < global_position.x:
		attack_hitbox.position.x = -absf(float(_current_attack["offset"].x))
	else:
		attack_hitbox.position.x = absf(float(_current_attack["offset"].x))
	attack_hitbox.position.y = float(_current_attack["offset"].y)
	var active_shape := attack_shape.shape as RectangleShape2D
	if active_shape != null:
		active_shape.size = _current_attack["size"]
	warning_area.position = attack_hitbox.position - Vector2(float(_current_attack["size"].x) * 0.5, 0.0)
	warning_area.size = _current_attack["size"]
	warning_area.color = _current_attack["warning_color"]
	warning_area.visible = true
	boss_announcement.emit("巨像蓄力：%s" % _current_attack["name"])
	_enter_state(BossState.WINDUP, float(_current_attack["windup"]))

func _begin_active_window() -> void:
	warning_area.color = Color(1.0, 0.35, 0.22, 0.75)
	attack_hitbox.activate(self, float(_current_attack["damage"]), float(_current_attack["knockback"]), _facing_to_target(), float(_current_attack["active"]), [_current_attack["tag"]])
	_enter_state(BossState.ACTIVE, float(_current_attack["active"]))

func _target_is_in_engagement_range() -> bool:
	_target = get_tree().get_first_node_in_group(&"player") as Node2D
	return _target != null and absf(_target.global_position.x - global_position.x) <= engagement_range

func _phase_cooldown_factor() -> float:
	if phase == 3:
		return 0.82
	if phase == 2:
		return 0.90
	return 1.0

func _facing_to_target() -> int:
	if _target != null and _target.global_position.x < global_position.x:
		return -1
	return 1

func _enter_state(next_state: BossState, duration: float) -> void:
	state = next_state
	_state_timer = maxf(duration, 0.0)
	if next_state != BossState.WINDUP:
		warning_area.color = Color(0.95, 0.20, 0.25, 0.42)

func _on_damaged(amount: float, _context: Variant) -> void:
	if not is_activated or state == BossState.STAGGER or state == BossState.DEAD:
		return
	current_poise = maxf(current_poise - amount, 0.0)
	_poise_recovery_timer = poise_recovery_delay
	boss_poise_changed.emit(current_poise, max_poise)
	if is_zero_approx(current_poise):
		_interrupt_into_stagger()

func _update_poise_recovery(delta: float) -> void:
	if not is_activated or state == BossState.STAGGER or current_poise >= max_poise:
		return
	if _poise_recovery_timer > 0.0:
		_poise_recovery_timer = maxf(_poise_recovery_timer - delta, 0.0)
		return
	var previous_poise: float = current_poise
	current_poise = minf(current_poise + poise_recovery_per_second * delta, max_poise)
	if not is_equal_approx(previous_poise, current_poise):
		boss_poise_changed.emit(current_poise, max_poise)

func _interrupt_into_stagger() -> void:
	attack_hitbox.deactivate()
	warning_area.visible = false
	boss_announcement.emit("裂隙巨像失衡")
	_enter_state(BossState.STAGGER, stagger_duration)

func _on_health_changed(current: float, maximum: float) -> void:
	boss_health_changed.emit(current, maximum)
	var ratio := current / maxf(maximum, 1.0)
	var next_phase := 1
	if ratio <= phase_thresholds[1]:
		next_phase = 3
	elif ratio <= phase_thresholds[0]:
		next_phase = 2
	if next_phase > phase:
		phase = next_phase
		attack_hitbox.deactivate()
		warning_area.visible = false
		hurtbox.set_invincible(true)
		boss_phase_changed.emit(phase)
		boss_announcement.emit("裂隙巨像进入 Phase %s" % phase)
		_enter_state(BossState.TRANSITION, 0.90)

func _on_depleted(_context: Variant) -> void:
	if _dead:
		return
	_dead = true
	state = BossState.DEAD
	_state_timer = 0.0
	attack_hitbox.deactivate()
	warning_area.visible = false
	hurtbox.set_invincible(true)
	hurtbox.set_deferred("monitorable", false)
	boss_died.emit(self)
	boss_defeated.emit(self)
	queue_free()