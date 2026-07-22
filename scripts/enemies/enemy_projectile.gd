class_name EnemyProjectile
extends Area2D

const DAMAGE_CONTEXT := preload("res://scripts/combat/damage_context.gd")

@export var speed := 260.0
@export var damage := 8.0
@export var lifetime := 2.2
@export var faction := StringName("enemy")
@export var animation_frames := 1
@export var animation_fps := 10.0

@onready var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D

var direction := Vector2.LEFT
var source: Node
var _timer := 0.0
var _hit_targets: Array[Area2D] = []
var _animation_elapsed := 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_timer = lifetime
	_setup_animation()

func launch(source_node: Node, launch_direction: Vector2, attack_damage: float) -> void:
	source = source_node
	direction = launch_direction.normalized()
	rotation = direction.angle()
	damage = attack_damage
	_timer = lifetime
	_animation_elapsed = 0.0
	if visual != null:
		visual.frame = 0

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_process_animation(delta)
	_timer -= delta
	if _timer <= 0.0:
		queue_free()

func _setup_animation() -> void:
	if visual == null:
		return
	visual.hframes = maxi(animation_frames, 1)
	visual.vframes = 1
	visual.frame = 0

func _process_animation(delta: float) -> void:
	if visual == null or animation_frames <= 1:
		return
	_animation_elapsed += delta
	var frame_duration := 1.0 / maxf(animation_fps, 0.1)
	while _animation_elapsed >= frame_duration:
		_animation_elapsed -= frame_duration
		visual.frame = (visual.frame + 1) % animation_frames

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