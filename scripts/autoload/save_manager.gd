extends Node

const SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://save_data.json"

func get_default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"settings": {
			"master_volume_db": 0.0,
			"fullscreen": false
		},
		"meta_progress": {
			"rift_crystals": 0,
			"talents": {}
		},
		"unlocks": {
			"skills": {
				"fire_slash": true,
				"lightning_dash": true,
				"blade_storm": false
			}
		},
		"statistics": {
			"runs_played": 0,
			"victories": 0,
			"defeats": 0,
			"total_kills": 0,
			"total_crystals_earned": 0,
			"best_survival_seconds": 0.0,
			"best_combo": 0,
			"total_damage_dealt": 0.0
		}
	}

func load_save() -> Dictionary:
	if not FileAccess.file_exists(DEFAULT_SAVE_PATH):
		return get_default_save_data()

	var file := FileAccess.open(DEFAULT_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager could not open save file for reading: %s" % DEFAULT_SAVE_PATH)
		return get_default_save_data()

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("SaveManager found invalid save data; using defaults.")
		return get_default_save_data()
	return _normalize_save(parsed)

func write_save(data: Dictionary) -> bool:
	var payload := _normalize_save(data)
	var file := FileAccess.open(DEFAULT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager could not open save file for writing: %s" % DEFAULT_SAVE_PATH)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true

func _normalize_save(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager found a newer save version; preserving known fields.")
	var normalized := _merge_defaults(data, get_default_save_data())
	normalized["version"] = SAVE_VERSION
	return normalized

func _merge_defaults(current: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	for key in current:
		var current_value: Variant = current[key]
		if defaults.has(key) and defaults[key] is Dictionary:
			if current_value is Dictionary:
				merged[key] = _merge_defaults(current_value as Dictionary, defaults[key] as Dictionary)
			continue
		merged[key] = current_value
	return merged
