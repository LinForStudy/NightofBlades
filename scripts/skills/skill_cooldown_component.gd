class_name SkillCooldownComponent
extends Node

signal cooldown_changed(skill_id: StringName, remaining: float, total: float)
signal cooldown_finished(skill_id: StringName)

var _remaining_by_skill: Dictionary = {}
var _total_by_skill: Dictionary = {}

func _physics_process(delta: float) -> void:
	for skill_id_variant in _remaining_by_skill.keys():
		var skill_id := StringName(skill_id_variant)
		var remaining := maxf(float(_remaining_by_skill[skill_id]) - delta, 0.0)
		_total_by_skill.get(skill_id, 0.0)
		_remaining_by_skill[skill_id] = remaining
		cooldown_changed.emit(skill_id, remaining, float(_total_by_skill.get(skill_id, 0.0)))
		if is_zero_approx(remaining):
			_remaining_by_skill.erase(skill_id)
			cooldown_finished.emit(skill_id)

func start_cooldown(skill_id: StringName, duration: float) -> void:
	var total := maxf(duration, 0.05)
	_remaining_by_skill[skill_id] = total
	_total_by_skill[skill_id] = total
	cooldown_changed.emit(skill_id, total, total)

func is_ready(skill_id: StringName) -> bool:
	return not _remaining_by_skill.has(skill_id)

func get_remaining(skill_id: StringName) -> float:
	return float(_remaining_by_skill.get(skill_id, 0.0))