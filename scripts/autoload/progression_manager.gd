extends Node

signal progression_changed

const TALENT_DEFINITIONS: Dictionary = {
	"vitality": {"display_name": "坚守", "cost": 40, "max_level": 3},
	"combat_training": {"display_name": "锋锐", "cost": 50, "max_level": 3}
}
const SKILL_UNLOCK_DEFINITIONS: Dictionary = {
	"blade_storm": {"display_name": "旋刃风暴", "cost": 90}
}

var _save_data: Dictionary = {}

func _ready() -> void:
	_save_data = SaveManager.load_save()
	_ensure_progression_shape()
	_apply_settings()

func get_crystals() -> int:
	return int(_save_data["meta_progress"].get("rift_crystals", 0))

func award_crystals(amount: int) -> void:
	if amount <= 0:
		return
	_save_data["meta_progress"]["rift_crystals"] = get_crystals() + amount
	var statistics: Dictionary = _save_data["statistics"]
	statistics["total_crystals_earned"] = int(statistics.get("total_crystals_earned", 0)) + amount
	_save()

func get_talent_level(talent_id: StringName) -> int:
	return int(_save_data["meta_progress"]["talents"].get(String(talent_id), 0))

func purchase_talent(talent_id: StringName) -> bool:
	var key: String = String(talent_id)
	if not TALENT_DEFINITIONS.has(key):
		return false
	var definition: Dictionary = TALENT_DEFINITIONS[key]
	var level := get_talent_level(talent_id)
	if level >= int(definition["max_level"]) or get_crystals() < int(definition["cost"]):
		return false
	_save_data["meta_progress"]["rift_crystals"] = get_crystals() - int(definition["cost"])
	_save_data["meta_progress"]["talents"][key] = level + 1
	_save()
	return true

func apply_to_player(player: Node) -> void:
	if player == null:
		return
	var health: Node = player.get_node_or_null("HealthComponent")
	if health != null:
		health.max_health = 100.0 + float(get_talent_level(&"vitality")) * 10.0
		health.reset_health()
	player.attack_damage_multiplier += float(get_talent_level(&"combat_training")) * 0.06

func is_skill_unlocked(skill_id: StringName) -> bool:
	return bool(_save_data["unlocks"]["skills"].get(String(skill_id), false))

func unlock_skill(skill_id: StringName) -> bool:
	var key := String(skill_id)
	if is_skill_unlocked(skill_id) or not SKILL_UNLOCK_DEFINITIONS.has(key):
		return false
	var definition: Dictionary = SKILL_UNLOCK_DEFINITIONS[key]
	var cost := int(definition["cost"])
	if get_crystals() < cost:
		return false
	_save_data["meta_progress"]["rift_crystals"] = get_crystals() - cost
	_save_data["unlocks"]["skills"][key] = true
	_save()
	return true

func record_battle(success: bool, duration_seconds: float, kill_count: int, max_combo: int, damage_dealt: float) -> void:
	var statistics: Dictionary = _save_data["statistics"]
	statistics["runs_played"] = int(statistics.get("runs_played", 0)) + 1
	var result_key := "victories" if success else "defeats"
	statistics[result_key] = int(statistics.get(result_key, 0)) + 1
	statistics["total_kills"] = int(statistics.get("total_kills", 0)) + maxi(kill_count, 0)
	statistics["best_survival_seconds"] = maxf(float(statistics.get("best_survival_seconds", 0.0)), duration_seconds)
	statistics["best_combo"] = maxi(int(statistics.get("best_combo", 0)), max_combo)
	statistics["total_damage_dealt"] = float(statistics.get("total_damage_dealt", 0.0)) + maxf(damage_dealt, 0.0)
	_save()

func get_statistics() -> Dictionary:
	return _save_data["statistics"].duplicate(true)

func get_master_volume_db() -> float:
	return float(_save_data["settings"].get("master_volume_db", 0.0))

func is_fullscreen() -> bool:
	return bool(_save_data["settings"].get("fullscreen", false))

func set_master_volume_db(value: float) -> void:
	_save_data["settings"]["master_volume_db"] = clampf(value, -40.0, 0.0)
	_apply_settings()
	_save()

func set_fullscreen(value: bool) -> void:
	_save_data["settings"]["fullscreen"] = value
	_apply_window_mode(value)
	_save()

func _ensure_progression_shape() -> void:
	var defaults := SaveManager.get_default_save_data()
	for section in ["settings", "meta_progress", "unlocks", "statistics"]:
		if not _save_data.has(section) or not (_save_data[section] is Dictionary):
			_save_data[section] = defaults[section].duplicate(true)
	var meta: Dictionary = _save_data["meta_progress"]
	if not meta.has("rift_crystals"):
		meta["rift_crystals"] = 0
	if not meta.has("talents") or not (meta["talents"] is Dictionary):
		meta["talents"] = {}
	var unlocks: Dictionary = _save_data["unlocks"]
	if not unlocks.has("skills") or not (unlocks["skills"] is Dictionary):
		unlocks["skills"] = defaults["unlocks"]["skills"].duplicate(true)
	for skill_id in defaults["unlocks"]["skills"]:
		if not unlocks["skills"].has(skill_id):
			unlocks["skills"][skill_id] = defaults["unlocks"]["skills"][skill_id]
	var statistics: Dictionary = _save_data["statistics"]
	for key in defaults["statistics"]:
		if not statistics.has(key):
			statistics[key] = defaults["statistics"][key]
	_save()

func _apply_settings() -> void:
	AudioManager.set_master_volume_db(get_master_volume_db())
	_apply_window_mode(is_fullscreen())

func _apply_window_mode(fullscreen: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _save() -> void:
	if SaveManager.write_save(_save_data):
		progression_changed.emit()
