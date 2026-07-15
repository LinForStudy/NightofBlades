class_name EnemyProjectile
extends Area2D

const DAMAGE_CONTEXT := preload("res://scripts/combat/damage_context.gd")

@export var speed := 260.0
@export var damage := 8.0
@export var lifetime := 2.2
@export var faction := StringName("enemy")

var direction := Vector2.LEFT
var source: Node
var _timer := 0.0
var _hit_targets: Array[Area2D] = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_timer = lifetime

func launch(source_node: Node, launch_direction: Vector2, attack_damage: float) -> void:
	source = source_node
	direction = launch_direction.normalized()
	damage = attack_damage
	_timer = lifetime

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_timer -= delta
	if _timer <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area in _hit_targets or not area.has_method("receive_hit"):
		return
	var target_faction: Variant = area.get("faction")
	if target_faction == faction:
		return
	_hit_targets.append(area)
	var context := DAMAGE_CONTEXT.create(source, damage, direction * 120.0, global_position, [StringName("projectile")])
	area.receive_hit(context)
	queue_free()