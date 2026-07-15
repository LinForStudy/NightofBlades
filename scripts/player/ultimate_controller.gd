class_name UltimateController
extends Node

signal ultimate_cast(data: Resource)

@export var ultimate_data: Resource
@export var effect_root_path: NodePath

var _effect_root: Node

func _ready() -> void:
	_effect_root = get_node_or_null(effect_root_path)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or not event.is_action_pressed(&"ultimate"):
		return
	if try_cast():
		_mark_input_handled()

func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func try_cast() -> bool:
	if owner == null or ultimate_data == null:
		return false
	if not bool(owner.call("consume_ultimate_energy")):
		return false
	var scene: PackedScene = ultimate_data.get("effect_scene")
	if scene == null:
		return false
	var effect := scene.instantiate()
	var target_root := _effect_root if _effect_root != null else get_tree().current_scene
	target_root.add_child(effect)
	effect.setup(owner as Node2D, ultimate_data, target_root)
	ultimate_cast.emit(ultimate_data)
	return true