extends Node

signal progression_changed

const TALENT_DEFINITIONS: Dictionary = {
	"vitality": {"display_name": "坚守", "cost": 40, "max_level": 3},
	"combat_training": {"display_name": "锋锐", "cost": 50, "max_level": 3}
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
	return bool(_save_data["unlocks"]["skills"].get(String(skill_id), true))

func set_master_volume_db(value: float) -> void:
	_save_data["settings"]["master_volume_db"] = clampf(value, -40.0, 0.0)
	_apply_settings()
	_save()

func set_fullscreen(value: bool) -> void:
	_save_data["settings"]["fullscreen"] = value
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()

func _ensure_progression_shape() -> void:
	if not _save_data.has("settings") or not (_save_data["settings"] is Dictionary):
		_save_data["settings"] = {}
	if not _save_data.has("meta_progress") or not (_save_data["meta_progress"] is Dictionary):
		_save_data["meta_progress"] = {}
	if not _save_data.has("unlocks") or not (_save_data["unlocks"] is Dictionary):
		_save_data["unlocks"] = {}
	var meta: Dictionary = _save_data["meta_progress"]
	if not meta.has("rift_crystals"):
		meta["rift_crystals"] = 0
	if not meta.has("talents") or not (meta["talents"] is Dictionary):
		meta["talents"] = {}
	_save_data["meta_progress"] = meta
	var unlocks: Dictionary = _save_data["unlocks"]
	if not unlocks.has("skills") or not (unlocks["skills"] is Dictionary):
		unlocks["skills"] = {"fire_slash": true, "lightning_dash": true, "blade_storm": true}
	_save_data["unlocks"] = unlocks

func _apply_settings() -> void:
	var settings: Dictionary = _save_data["settings"]
	AudioManager.set_master_volume_db(float(settings.get("master_volume_db", 0.0)))

func _save() -> void:
	SaveManager.write_save(_save_data)
	progression_changed.emit()