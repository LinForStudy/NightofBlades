class_name SkillManager
extends Node

signal skill_cast(skill_id: StringName, skill_data: Resource)
signal skill_cooldown_changed(skill_id: StringName, remaining: float, total: float)
signal skill_upgrade_applied(upgrade: Resource, level: int, branch_id: StringName)

@export var skills: Array[Resource] = []
@export var skill_upgrades: Array[Resource] = []
@export var input_actions: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3"]
@export var effect_root_path: NodePath

@onready var cooldowns: SkillCooldownComponent = $SkillCooldownComponent

var _effect_root: Node
var _state_by_skill: Dictionary = {}

func _ready() -> void:
	_effect_root = get_node_or_null(effect_root_path)
	cooldowns.cooldown_changed.connect(_on_cooldown_changed)
	_filter_locked_skills()
	for skill in skills:
		if skill == null or skill.get("skill_id") == null:
			push_warning("SkillManager contains an invalid skill resource.")
			continue
		_ensure_state(skill)

func _filter_locked_skills() -> void:
	var unlocked_skills: Array[Resource] = []
	for skill in skills:
		if skill == null:
			continue
		var skill_id := StringName(str(skill.get("skill_id")))
		if ProgressionManager.is_skill_unlocked(skill_id):
			unlocked_skills.append(skill)
	skills = unlocked_skills

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	for index in input_actions.size():
		if event.is_action_pressed(input_actions[index]):
			try_cast(index)
			_mark_input_handled()
			return

func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func try_cast(index: int) -> bool:
	if index < 0 or index >= skills.size() or owner == null:
		return false
	if owner.has_method("can_cast_active_skill") and not owner.can_cast_active_skill():
		return false
	var data := skills[index]
	if data == null:
		return false
	var skill_id := StringName(str(data.get("skill_id")))
	var runtime := get_runtime_stats(skill_id)
	if skill_id == StringName("") or not cooldowns.is_ready(skill_id):
		return false
	var scene: PackedScene = data.get("skill_scene")
	if scene == null:
		push_warning("Skill %s has no skill scene." % skill_id)
		return false
	var effect := scene.instantiate()
	if not effect.has_method("setup"):
		push_warning("Skill %s effect does not implement setup()." % skill_id)
		effect.queue_free()
		return false
	var target_root := _effect_root if _effect_root != null else get_tree().current_scene
	target_root.add_child(effect)
	effect.setup(owner as Node2D, data, target_root, runtime)
	var cooldown := maxf(float(data.get("base_cooldown")) * float(runtime.get("cooldown_multiplier", 1.0)), float(data.get("base_cooldown")) * 0.2)
	cooldowns.start_cooldown(skill_id, cooldown)
	skill_cast.emit(skill_id, data)
	return true

func get_skill_data(index: int) -> Resource:
	if index < 0 or index >= skills.size():
		return null
	return skills[index]

func get_skill_level(skill_id: StringName) -> int:
	return int(get_runtime_stats(skill_id).get("level", 1))

func get_runtime_stats(skill_id: StringName) -> Dictionary:
	var data := _find_skill_data(skill_id)
	if data != null:
		_ensure_state(data)
	var state: Dictionary = _state_by_skill.get(skill_id, {})
	return state.duplicate(true)

func get_available_skill_upgrades() -> Array[Resource]:
	var available: Array[Resource] = []
	for upgrade in skill_upgrades:
		if is_skill_upgrade_available(upgrade):
			available.append(upgrade)
	return available

func is_skill_upgrade_available(upgrade: Resource) -> bool:
	if upgrade == null:
		return false
	var skill_id := StringName(str(upgrade.get("skill_id")))
	var data := _find_skill_data(skill_id)
	if data == null:
		return false
	var state := get_runtime_stats(skill_id)
	var target_level := int(upgrade.get("target_level"))
	if target_level != int(state.get("level", 1)) + 1 or target_level > int(data.get("max_level")):
		return false
	var selected_branch := StringName(str(state.get("branch_id", StringName(""))))
	var upgrade_branch := StringName(str(upgrade.get("branch_id")))
	if target_level >= 3 and selected_branch != StringName("") and upgrade_branch != selected_branch:
		return false
	if target_level >= 3 and selected_branch == StringName("") and upgrade_branch == StringName(""):
		return false
	return true

func apply_skill_upgrade(upgrade: Resource) -> bool:
	if not is_skill_upgrade_available(upgrade):
		return false
	var skill_id := StringName(str(upgrade.get("skill_id")))
	var state := get_runtime_stats(skill_id)
	state["level"] = int(upgrade.get("target_level"))
	var upgrade_branch := StringName(str(upgrade.get("branch_id")))
	if upgrade_branch != StringName(""):
		state["branch_id"] = upgrade_branch
	_apply_modifiers(state, upgrade.get("modifiers"))
	_state_by_skill[skill_id] = state
	skill_upgrade_applied.emit(upgrade, int(state["level"]), StringName(str(state.get("branch_id", StringName("")))))
	return true

func _ensure_state(data: Resource) -> void:
	var skill_id := StringName(str(data.get("skill_id")))
	if skill_id == StringName("") or _state_by_skill.has(skill_id):
		return
	_state_by_skill[skill_id] = {
		"level": 1,
		"branch_id": StringName(""),
		"damage_multiplier": 1.0,
		"cooldown_multiplier": 1.0,
		"range_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"extra_tags": []
	}

func _apply_modifiers(state: Dictionary, modifiers: Variant) -> void:
	if not (modifiers is Dictionary):
		return
	state["damage_multiplier"] = float(state.get("damage_multiplier", 1.0)) + float(modifiers.get("damage_bonus", 0.0))
	state["cooldown_multiplier"] = maxf(float(state.get("cooldown_multiplier", 1.0)) - float(modifiers.get("cooldown_reduction", 0.0)), 0.2)
	state["range_multiplier"] = float(state.get("range_multiplier", 1.0)) + float(modifiers.get("range_bonus", 0.0))
	state["duration_multiplier"] = float(state.get("duration_multiplier", 1.0)) + float(modifiers.get("duration_bonus", 0.0))
	var tags: Array[StringName] = []
	for existing_tag in state.get("extra_tags", []):
		tags.append(StringName(str(existing_tag)))
	for tag in modifiers.get("add_tags", []):
		var tag_name := StringName(str(tag))
		if tag_name not in tags:
			tags.append(tag_name)
	state["extra_tags"] = tags

func _find_skill_data(skill_id: StringName) -> Resource:
	for skill in skills:
		if skill != null and StringName(str(skill.get("skill_id"))) == skill_id:
			return skill
	return null

func _on_cooldown_changed(skill_id: StringName, remaining: float, total: float) -> void:
	skill_cooldown_changed.emit(skill_id, remaining, total)
