class_name SkillEffect
extends Node2D

signal completed(effect: SkillEffect)

var caster: Node2D
var skill_data: Resource
var effect_root: Node
var runtime_stats: Dictionary = {}

func setup(caster_node: Node2D, data: Resource, target_root: Node, runtime: Dictionary = {}) -> void:
	caster = caster_node
	skill_data = data
	effect_root = target_root
	runtime_stats = runtime.duplicate(true)
	_execute()

func _execute() -> void:
	finish()

func finish() -> void:
	completed.emit(self)
	queue_free()

func get_facing_direction() -> int:
	if caster != null:
		return int(caster.get("facing_direction"))
	return 1

func get_stat(key: StringName, fallback: float = 1.0) -> float:
	return float(runtime_stats.get(key, fallback))

func has_effect_tag(tag: StringName) -> bool:
	if skill_data != null:
		for base_tag in skill_data.get("tags"):
			if StringName(str(base_tag)) == tag:
				return true
	for extra_tag in runtime_stats.get("extra_tags", []):
		if StringName(str(extra_tag)) == tag:
			return true
	return false

func get_effect_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	if skill_data != null:
		for base_tag in skill_data.get("tags"):
			result.append(StringName(str(base_tag)))
	for extra_tag in runtime_stats.get("extra_tags", []):
		var tag_name := StringName(str(extra_tag))
		if tag_name not in result:
			result.append(tag_name)
	return result