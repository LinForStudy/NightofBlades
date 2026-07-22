extends Node

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const BLADE_STORM_DATA := preload("res://resources/skills/blade_storm.tres")

var _skill_cast_counts: Dictionary = {}
var _ultimate_cast_count := 0
var _stage := "initialization"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(20.0, true, false, true).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	_set_stage("loading BattleScene")
	await get_tree().process_frame
	var load_error := get_tree().change_scene_to_file(BATTLE_SCENE)
	if load_error != OK:
		_fail("Failed to load BattleScene: %s" % load_error)
		return
	await _wait_physics_frames(12)

	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("World/EntityRoot/Player") if scene != null else null
	var hud := scene.get_node_or_null("CanvasLayer/BattleHUD") if scene != null else null
	var wave_manager := scene.get_node_or_null("Managers/WaveManager") if scene != null else null
	var skill_manager := player.get_node_or_null("SkillManager") if player != null else null
	var ultimate_controller := player.get_node_or_null("UltimateController") if player != null else null
	if scene == null or player == null or hud == null or wave_manager == null or skill_manager == null or ultimate_controller == null:
		_fail("Battle HUD runtime validation is missing required BattleScene nodes.")
		return

	GameManager.current_state = GameManager.GameState.BATTLE
	GameManager.previous_state = GameManager.GameState.BATTLE
	get_tree().paused = false
	Engine.time_scale = 1.0
	wave_manager.stop_waves()
	if wave_manager.has_method("clear_active_enemies"):
		wave_manager.clear_active_enemies()
	player.global_position = Vector2(720.0, 570.0)

	skill_manager.skill_cast.connect(_on_skill_cast)
	ultimate_controller.ultimate_cast.connect(_on_ultimate_cast)
	_ensure_three_runtime_skills(skill_manager)
	hud.call("_refresh_skill_slots")
	await _wait_process_frames(2)

	_set_stage("testing U/I/O skill inputs")
	var skill_keys := [KEY_U, KEY_I, KEY_O]
	var skill_names := [&"skill_1", &"skill_2", &"skill_3"]
	for index in skill_keys.size():
		var data: Resource = skill_manager.get_skill_data(index)
		if data == null:
			_fail("Skill slot %s has no runtime data." % (index + 1))
			return
		var skill_id := StringName(str(data.get("skill_id")))
		var casts_before := int(_skill_cast_counts.get(skill_id, 0))
		await _tap_key(skill_keys[index])
		await _wait_physics_frames(2)
		if int(_skill_cast_counts.get(skill_id, 0)) != casts_before + 1:
			_fail("Input %s did not cast skill %s exactly once." % [skill_names[index], skill_id])
			return
		if skill_manager.cooldowns.get_remaining(skill_id) <= 0.0:
			_fail("Skill %s did not enter cooldown." % skill_id)
			return
		var slot := hud.get_node_or_null("SkillBar/Slots/SkillSlot%s" % (index + 1))
		if slot == null or not slot.visible:
			_fail("HUD slot %s is missing or hidden after casting." % (index + 1))
			return
		if not slot.get_node("Content/CooldownMask").visible or slot.get_node("Content/CooldownText").text.is_empty():
			_fail("HUD slot %s did not show its cooldown mask and number." % (index + 1))
			return
		if index == 0:
			await _tap_key(KEY_U)
			await _wait_physics_frames(2)
			if int(_skill_cast_counts.get(skill_id, 0)) != casts_before + 1:
				_fail("Skill cooldown allowed U to cast twice immediately.")
				return

	_set_stage("testing empty-energy L input")
	await _tap_key(KEY_L)
	await _wait_physics_frames(2)
	if _ultimate_cast_count != 0 or float(player.ultimate_energy) != 0.0:
		_fail("Ultimate cast without full energy.")
		return

	_set_stage("testing full-energy L input")
	player.ultimate_energy = player.ultimate_energy_max
	player.ultimate_energy_changed.emit(player.ultimate_energy, player.ultimate_energy_max)
	await _wait_process_frames(2)
	if hud.get_node("SkillBar/Slots/UltimateSlot/Content/UltimateText").text != "100%":
		_fail("Ultimate HUD did not show 100% energy.")
		return
	if not hud.get_node("SkillBar/Slots/UltimateSlot/Content/ReadyGlow").visible:
		_fail("Ultimate HUD ready glow did not activate at 100%.")
		return

	await _tap_key(KEY_L)
	await _wait_physics_frames(2)
	if _ultimate_cast_count != 1 or float(player.ultimate_energy) != 0.0:
		_fail("Ultimate did not cast once and consume full energy.")
		return
	if hud.get_node("SkillBar/Slots/UltimateSlot/Content/UltimateText").text != "0%":
		_fail("Ultimate HUD did not return to 0% after casting.")
		return
	if hud.get_node("SkillBar/Slots/UltimateSlot/Content/ReadyGlow").visible:
		_fail("Ultimate HUD ready glow remained visible after casting.")
		return

	_set_stage("testing low-health HUD state")
	hud.call("_on_player_health_changed", 20.0, 100.0)
	await _wait_process_frames(2)
	if not hud.get_node("PlayerStatusPanel/LowHealthFrame").visible:
		_fail("Low-health HUD pulse did not activate below 30%.")
		return
	hud.call("_on_player_health_changed", 0.0, 100.0)
	await _wait_process_frames(2)
	if hud.get_node("PlayerStatusPanel/LowHealthFrame").visible:
		_fail("Low-health HUD pulse remained active at zero health.")
		return

	_set_stage("testing pause button and keyboard resume")
	await _tap_key(KEY_ESCAPE)
	if not get_tree().paused or not hud.get_node("PausePanel").visible:
		_fail("Pause input did not pause the tree and show the pause panel.")
		return
	var resume_button: Button = hud.get_node("%ResumeButton")
	resume_button.pressed.emit()
	await _wait_process_frames(2)
	if get_tree().paused or hud.get_node("PausePanel").visible:
		_fail("Resume button did not resume the battle.")
		return
	await _tap_key(KEY_ESCAPE)
	if not get_tree().paused or not hud.get_node("PausePanel").visible:
		_fail("Second pause input did not reopen the pause panel.")
		return
	await _tap_key(KEY_ESCAPE)
	if get_tree().paused or hud.get_node("PausePanel").visible:
		_fail("Pause keyboard toggle did not resume the battle.")
		return

	_set_stage("testing button bindings and layout")
	if not _validate_button_bindings(hud):
		return
	if not _validate_layout(hud):
		return

	print("Battle HUD runtime validation passed: U/I/O cooldowns, L energy, low-health state, pause/resume, buttons, and 1280x720 layout.")
	get_tree().quit(0)

func _ensure_three_runtime_skills(skill_manager: Node) -> void:
	if skill_manager.get_skill_data(2) != null:
		return
	skill_manager.skills.append(BLADE_STORM_DATA)
	skill_manager.call("_ensure_state", BLADE_STORM_DATA)

func _validate_button_bindings(hud: Node) -> bool:
	var overlay: Control = hud.get_parent().get_node_or_null("OverlayUI")
	var pause_panel: Control = hud.get_node("PausePanel")
	if overlay == null or overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Battle overlay must ignore empty-area mouse input.")
		return false
	if pause_panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Pause panel must receive mouse input.")
		return false
	var bindings := [
		["DefeatRestartButton", "_restart_battle"],
		["DefeatMenuButton", "_return_to_menu"],
		["ResumeButton", "_resume_battle"],
		["RestartButton", "_restart_battle"],
		["PauseMenuButton", "_return_to_menu"],
	]
	for binding in bindings:
		var button: Button = hud.get_node_or_null("%%%s" % binding[0])
		if button == null or button.disabled or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			_fail("HUD button cannot receive input: %s" % binding[0])
			return false
		if not button.pressed.is_connected(Callable(hud, binding[1])):
			_fail("HUD button binding is missing: %s -> %s" % binding)
			return false
	return true

func _validate_layout(hud: Node) -> bool:
	var skill_bar: Control = hud.get_node("SkillBar")
	var player_panel: Control = hud.get_node("PlayerStatusPanel")
	var run_info: Control = hud.get_node("RunInfoPanel")
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	for control in [skill_bar, player_panel, run_info]:
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_fail("HUD control is outside the 1280x720 viewport: %s %s" % [control.name, rect])
			return false
	if absf(skill_bar.size.x - 430.0) > 0.5 or absf(skill_bar.size.y - 90.0) > 0.5:
		_fail("Skill dock runtime size is not 430x90: %s" % skill_bar.size)
		return false
	if absf(skill_bar.position.x - 425.0) > 0.5 or absf(skill_bar.position.y - 616.0) > 0.5:
		_fail("Skill dock runtime position is incorrect: %s" % skill_bar.position)
		return false
	return true

func _on_skill_cast(skill_id: StringName, _skill_data: Resource) -> void:
	_skill_cast_counts[skill_id] = int(_skill_cast_counts.get(skill_id, 0)) + 1

func _on_ultimate_cast(_data: Resource) -> void:
	_ultimate_cast_count += 1

func _tap_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

func _wait_process_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _set_stage(stage: String) -> void:
	_stage = stage
	print("[HUD-RUNTIME] %s" % _stage)

func _on_watchdog_timeout() -> void:
	_fail("Runtime validation timed out during: %s" % _stage)

func _fail(message: String) -> void:
	push_error(message)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit(1)