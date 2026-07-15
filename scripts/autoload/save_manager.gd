extends Node

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_data.json"

func get_default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"settings": {},
		"meta_progress": {},
		"unlocks": {},
		"statistics": {}
	}

func load_save() -> Dictionary:
	if not FileAccess.file_exists(DEFAULT_SAVE_PATH):
		return get_default_save_data()

	var file := FileAccess.open(DEFAULT_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager could not open save file for reading: %s" % DEFAULT_SAVE_PATH)
		return get_default_save_data()

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed

	push_warning("SaveManager found invalid save data; using defaults.")
	return get_default_save_data()

func write_save(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION

	var file := FileAccess.open(DEFAULT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager could not open save file for writing: %s" % DEFAULT_SAVE_PATH)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true