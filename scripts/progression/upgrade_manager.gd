class_name UpgradeManager
extends Node

signal upgrade_applied(upgrade: Resource, stack_count: int)

@export var upgrades: Array[Resource] = []
@export var player_path: NodePath
@export var skill_manager_path: NodePath

var stacks_by_upgrade: Dictionary = {}
var _player: Node
var _skill_manager: Node

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_skill_manager = get_node_or_null(skill_manager_path)

func get_upgrade_choices(count := 3) -> Array[Resource]:
	var choices: Array[Resource] = []
	var candidates := _get_available_upgrades()
	while choices.size() < count and not candidates.is_empty():
		var picked := _pick_weighted(candidates)
		if picked == null:
			break
		choices.append(picked)
		candidates.erase(picked)
	return choices

func apply_upgrade(upgrade: Resource) -> bool:
	if _is_skill_upgrade(upgrade):
		if _skill_manager == null:
			_skill_manager = get_node_or_null(skill_manager_path)
		if _skill_manager == null or not _skill_manager.apply_skill_upgrade(upgrade):
			return false
		upgrade_applied.emit(upgrade, int(upgrade.get("target_level")))
		return true
	if upgrade == null or not _is_passive_upgrade_available(upgrade):
		return false
	var upgrade_id := _upgrade_id(upgrade)
	var next_stack := int(stacks_by_upgrade.get(upgrade_id, 0)) + 1
	stacks_by_upgrade[upgrade_id] = next_stack
	if _player == null:
		_player = get_node_or_null(player_path)
	if _player != null and _player.has_method("apply_passive_upgrade"):
		_player.apply_passive_upgrade(StringName(str(upgrade.get("effect_key"))), float(upgrade.get("effect_value")), next_stack, upgrade)
	upgrade_applied.emit(upgrade, next_stack)
	return true

func get_stack_count(upgrade: Resource) -> int:
	if _is_skill_upgrade(upgrade):
		if _skill_manager == null:
			_skill_manager = get_node_or_null(skill_manager_path)
		if _skill_manager != null:
			return _skill_manager.get_skill_level(StringName(str(upgrade.get("skill_id"))))
		return 1
	if upgrade == null:
		return 0
	return int(stacks_by_upgrade.get(_upgrade_id(upgrade), 0))

func get_max_progress(upgrade: Resource) -> int:
	if _is_skill_upgrade(upgrade):
		return 5
	return int(upgrade.get("max_stacks"))

func _get_available_upgrades() -> Array[Resource]:
	var available: Array[Resource] = []
	for upgrade in upgrades:
		if _is_passive_upgrade_available(upgrade):
			available.append(upgrade)
	if _skill_manager == null:
		_skill_manager = get_node_or_null(skill_manager_path)
	if _skill_manager != null and _skill_manager.has_method("get_available_skill_upgrades"):
		available.append_array(_skill_manager.get_available_skill_upgrades())
	return available

func _is_passive_upgrade_available(upgrade: Resource) -> bool:
	if upgrade == null or _is_skill_upgrade(upgrade):
		return false
	if _upgrade_id(upgrade) == StringName(""):
		return false
	return int(stacks_by_upgrade.get(_upgrade_id(upgrade), 0)) < int(upgrade.get("max_stacks"))

func _is_skill_upgrade(upgrade: Resource) -> bool:
	return upgrade is SkillUpgradeData

func _pick_weighted(candidates: Array[Resource]) -> Resource:
	var total := 0
	for upgrade in candidates:
		total += maxi(int(upgrade.get("weight")), 0)
	if total <= 0:
		return candidates[0]
	var roll := randi_range(1, total)
	var cursor := 0
	for upgrade in candidates:
		cursor += maxi(int(upgrade.get("weight")), 0)
		if roll <= cursor:
			return upgrade
	return candidates[0]

func _upgrade_id(upgrade: Resource) -> StringName:
	return StringName(str(upgrade.get("upgrade_id")))