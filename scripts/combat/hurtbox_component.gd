class_name HurtboxComponent
extends Area2D

signal hit_received(context: Variant)
signal hit_ignored(context: Variant)

@export var faction := StringName("neutral")
@export var health_path: NodePath

var health: Node
var is_invincible := false

func _ready() -> void:
	monitoring = false
	monitorable = true
	if not health_path.is_empty():
		health = get_node_or_null(health_path)
	if health == null:
		health = _find_health_component()

func receive_hit(context: Variant) -> bool:
	context["target"] = owner
	if is_invincible:
		hit_ignored.emit(context)
		return false

	if health != null and health.has_method("apply_damage"):
		health.apply_damage(context)
	hit_received.emit(context)
	return true

func set_invincible(value: bool) -> void:
	is_invincible = value

func _find_health_component() -> Node:
	var search_root := owner if owner != null else get_parent()
	if search_root == null:
		return null
	for child in search_root.get_children():
		if child.has_method("apply_damage"):
			return child
	return null