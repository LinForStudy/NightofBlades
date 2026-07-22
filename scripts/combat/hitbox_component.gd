class_name HitboxComponent
extends Area2D

const DAMAGE_CONTEXT := preload("res://scripts/combat/damage_context.gd")

signal hit_confirmed(hurtbox: Area2D, context: Variant)
signal hit_avoided(hurtbox: Area2D, context: Variant)

@export var faction := StringName("player")
@export var damage := 10.0
@export var knockback_strength := 180.0
@export var active_time := 0.08
@export var attack_tags: Array = []

var source: Node
var facing_direction := 1
var _active_timer := 0.0
var _hit_hurtboxes: Array[Area2D] = []
var _radial_knockback := false

func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func activate(source_node: Node, attack_damage: float, attack_knockback: float, direction: int, duration: float, tags: Array = []) -> void:
	_radial_knockback = false
	_begin_activation(source_node, attack_damage, attack_knockback, direction, duration, tags)

func activate_radial(source_node: Node, attack_damage: float, attack_knockback: float, duration: float, tags: Array = []) -> void:
	_radial_knockback = true
	_begin_activation(source_node, attack_damage, attack_knockback, 1, duration, tags)

func _begin_activation(source_node: Node, attack_damage: float, attack_knockback: float, direction: int, duration: float, tags: Array) -> void:
	source = source_node
	damage = attack_damage
	knockback_strength = attack_knockback
	facing_direction = direction
	active_time = duration
	attack_tags = tags
	_hit_hurtboxes.clear()
	_active_timer = active_time
	monitoring = true
	_deal_overlaps()

func deactivate() -> void:
	monitoring = false
	_active_timer = 0.0

func _physics_process(delta: float) -> void:
	if not monitoring:
		return
	_active_timer -= delta
	if _active_timer <= 0.0:
		deactivate()

func _on_area_entered(area: Area2D) -> void:
	if not monitoring:
		return
	_try_hit(area)

func _deal_overlaps() -> void:
	for area in get_overlapping_areas():
		_try_hit(area)

func _try_hit(area: Area2D) -> void:
	if area == null or area in _hit_hurtboxes or not area.has_method("receive_hit"):
		return
	var target_faction: Variant = area.get("faction")
	if target_faction == faction:
		return

	_hit_hurtboxes.append(area)
	var direction := Vector2(float(facing_direction), -0.25).normalized()
	if _radial_knockback:
		direction = area.global_position - global_position
		if direction.length_squared() < 0.001:
			direction = Vector2.UP
		else:
			direction = direction.normalized()
	var context: Variant = DAMAGE_CONTEXT.create(source, damage, direction * knockback_strength, global_position, attack_tags)
	var did_hit := bool(area.receive_hit(context))
	if did_hit:
		hit_confirmed.emit(area, context)
	else:
		hit_avoided.emit(area, context)