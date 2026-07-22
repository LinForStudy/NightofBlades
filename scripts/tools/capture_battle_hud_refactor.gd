extends Node

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_scene.tscn")
const SCREENSHOT_PATH := "res://artifacts/screenshots/battle_hud_refactor_1280x720.png"

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	call_deferred("_capture_preview")

func _capture_preview() -> void:
	var battle_scene := BATTLE_SCENE.instantiate()
	add_child(battle_scene)
	await _wait_frames(12)
	battle_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := battle_scene.get_node_or_null("CanvasLayer/BattleHUD")
	if hud == null:
		push_error("BattleScene is missing CanvasLayer/BattleHUD.")
		get_tree().quit(1)
		return
	hud.call("_on_player_health_changed", 96.0, 130.0)
	hud.call("_on_experience_changed", 80, 230, 8)
	var normal_slots := [
		hud.get_node_or_null("SkillBar/Slots/SkillSlot1"),
		hud.get_node_or_null("SkillBar/Slots/SkillSlot2"),
	]
	var cooldowns := [2.1, 3.2]
	for index in normal_slots.size():
		if normal_slots[index] != null:
			hud.call("_set_skill_slot_cooldown_visual", normal_slots[index], cooldowns[index], 8.0)
	hud.call("_on_ultimate_energy_changed", 0.0, 100.0)
	GameManager.set_battle_result_stats(134.0, 92, false, 72, 3694.0, 136.0, "裂隙斩")
	hud.call("show_defeat")
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	hud.call("set_run_stats", 134.0, 92, 72)
	await _wait_frames(4)
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("HUD preview screenshot image is empty.")
		get_tree().quit(1)
		return
	var save_error := image.save_png(SCREENSHOT_PATH)
	if save_error != OK:
		push_error("Failed to save HUD preview screenshot: %s" % save_error)
		get_tree().quit(1)
		return
	print("Saved HUD preview: %s (%sx%s)" % [SCREENSHOT_PATH, image.get_width(), image.get_height()])
	battle_scene.queue_free()
	await _wait_frames(2)
	get_tree().quit(0)

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame