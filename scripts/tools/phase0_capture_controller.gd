extends Node

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const MAIN_MENU_SCREENSHOT := "res://artifacts/screenshots/phase_5_main_menu.png"
const BATTLE_SCREENSHOT := "res://artifacts/screenshots/phase_5_battle_scene.png"

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	call_deferred("_run")

func _run() -> void:
	await _wait_frames(2)
	var main_error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if main_error != OK:
		push_error("Failed to load main menu scene: %s" % main_error)
		get_tree().quit(1)
		return

	await _wait_frames(6)
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE:
		push_error("Expected main menu scene, got: %s" % _current_scene_path())
		get_tree().quit(1)
		return

	var main_capture_error := _capture(MAIN_MENU_SCREENSHOT)
	if main_capture_error != OK:
		get_tree().quit(1)
		return

	var start_button := get_tree().current_scene.get_node_or_null("%StartButton")
	if start_button == null:
		push_error("MainMenu is missing %StartButton.")
		get_tree().quit(1)
		return

	start_button.pressed.emit()
	await _wait_frames(10)
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != BATTLE_SCENE:
		push_error("Expected battle scene after StartButton press, got: %s" % _current_scene_path())
		get_tree().quit(1)
		return

	var battle_capture_error := _capture(BATTLE_SCREENSHOT)
	if battle_capture_error != OK:
		get_tree().quit(1)
		return

	get_tree().quit(0)

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _capture(path: String) -> Error:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Screenshot image is empty: %s" % path)
		return ERR_CANT_CREATE

	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save screenshot %s: %s" % [path, error])
	return error

func _current_scene_path() -> String:
	if get_tree().current_scene == null:
		return "<none>"
	return get_tree().current_scene.scene_file_path