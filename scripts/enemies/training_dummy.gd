class_name TrainingDummy
extends CharacterBody2D

@export var recovery_speed := 900.0
@export var gravity := 1200.0
@export var max_fall_speed := 820.0

@onready var health: Node = %HealthComponent
@onready var body: ColorRect = %Body
@onready var health_label: Label = %HealthLabel

var _flash_timer := 0.0

func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_depleted)
	_on_health_changed(health.current_health, health.max_health)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	velocity.x = move_toward(velocity.x, 0.0, recovery_speed * delta)
	move_and_slide()
	_update_flash(delta)

func _on_damaged(amount: float, context: Variant) -> void:
	velocity = context.get("knockback", Vector2.ZERO)
	_flash_timer = 0.09
	if owner != null and owner.has_method("spawn_damage_number"):
		owner.spawn_damage_number(amount, global_position + Vector2(-12, -76))

func _on_health_changed(current: float, maximum: float) -> void:
	if health_label != null:
		health_label.text = "Dummy HP: %d/%d" % [int(current), int(maximum)]

func _on_depleted(_context: Variant) -> void:
	health.reset_health()

func _update_flash(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	if body == null:
		return
	body.color = Color(1, 1, 1, 1) if _flash_timer > 0.0 else Color(0.84, 0.22, 0.18, 1)