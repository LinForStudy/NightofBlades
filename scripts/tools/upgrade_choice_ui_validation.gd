extends Node

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_scene.tscn")
const ACTIVE_UPGRADE: Resource = preload("res://resources/skill_upgrades/fire_slash_lv2.tres")
const EVOLUTION_UPGRADE: Resource = preload("res://resources/skill_upgrades/lightning_dash_chain_lv3.tres")
const PASSIVE_UPGRADE: Resource = preload("res://resources/upgrades/iron_body.tres")
const SCREENSHOT_PATH := "res://artifacts/screenshots/upgrade_choice_ui_1280x720.png"

var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var window := get_window()
	if window != null and DisplayServer.get_name() != "headless":
		window.mode = Window.MODE_WINDOWED
		window.size = Vector2i(1280, 720)
	call_deferred("_run_validation")

func _run_validation() -> void:
	var battle_scene := BATTLE_SCENE.instantiate()
	add_child(battle_scene)
	await _wait_frames(8)
	var wave_manager := battle_scene.get_node_or_null("Managers/WaveManager")
	if wave_manager != null:
		wave_manager.process_mode = Node.PROCESS_MODE_DISABLED
	var experience_manager := battle_scene.get_node_or_null("Managers/ExperienceManager")
	var skill_manager := battle_scene.get_node_or_null("World/EntityRoot/Player/SkillManager")
	var level_up_panel := battle_scene.get_node_or_null("CanvasLayer/OverlayUI/LevelUpPanel") as PanelContainer
	var level_up_dimmer := battle_scene.get_node_or_null("CanvasLayer/OverlayUI/LevelUpDimmer") as ColorRect
	var cards: Array[Button] = [
		battle_scene.get_node_or_null("CanvasLayer/OverlayUI/LevelUpPanel/InnerFrame/Content/Cards/UpgradeButton1") as Button,
		battle_scene.get_node_or_null("CanvasLayer/OverlayUI/LevelUpPanel/InnerFrame/Content/Cards/UpgradeButton2") as Button,
		battle_scene.get_node_or_null("CanvasLayer/OverlayUI/LevelUpPanel/InnerFrame/Content/Cards/UpgradeButton3") as Button,
	]
	_expect(experience_manager != null, "ExperienceManager exists")
	_expect(skill_manager != null, "SkillManager exists")
	_expect(level_up_panel != null, "LevelUpPanel exists")
	_expect(level_up_dimmer != null, "LevelUpDimmer exists")
	for index in cards.size():
		_expect(cards[index] != null, "Upgrade card %d exists" % (index + 1))
	if not _failures.is_empty():
		_finish(battle_scene)
		return
	var options: Array[Resource] = [ACTIVE_UPGRADE, EVOLUTION_UPGRADE, PASSIVE_UPGRADE]
	experience_manager.set("pending_level_ups", 1)
	experience_manager.set("is_selecting_upgrade", true)
	experience_manager.set("_current_options", options)
	get_tree().paused = true
	battle_scene.call("_on_level_up_choices_ready", options, 1)
	await _wait_frames(4)
	_validate_overlay(level_up_panel, level_up_dimmer, cards)
	if DisplayServer.get_name() != "headless":
		await _capture_screenshot()
	var before_level := int(skill_manager.call("get_skill_level", &"fire_slash"))
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_1
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await _wait_frames(4)
	var after_level := int(skill_manager.call("get_skill_level", &"fire_slash"))
	_expect(not level_up_panel.visible, "Selection hides level-up panel")
	_expect(not level_up_dimmer.visible, "Selection hides dimmer")
	_expect(not get_tree().paused, "Selection resumes the battle")
	_expect(before_level == 1 and after_level == 2, "KEY_1 applies the existing fire-slash upgrade")
	_finish(battle_scene)

func _validate_overlay(level_up_panel: PanelContainer, level_up_dimmer: ColorRect, cards: Array[Button]) -> void:
	_expect(level_up_panel.visible, "Level-up panel becomes visible")
	_expect(level_up_dimmer.visible, "Dimmer becomes visible")
	var viewport_rect := get_viewport().get_visible_rect()
	var panel_rect := level_up_panel.get_global_rect()
	_expect(viewport_rect.encloses(panel_rect), "Level-up panel stays inside 1280x720")
	_expect(roundi(panel_rect.size.x) == 860 and roundi(panel_rect.size.y) == 460, "Level-up panel is 860x460")
	var card_rects: Array[Rect2] = []
	for index in cards.size():
		var card := cards[index]
		_expect(card.visible and not card.disabled, "Upgrade card %d is selectable" % (index + 1))
		var card_rect := card.get_global_rect()
		card_rects.append(card_rect)
		_expect(viewport_rect.encloses(card_rect), "Upgrade card %d stays inside viewport" % (index + 1))
		_expect(is_equal_approx(card_rect.position.x, roundf(card_rect.position.x)), "Upgrade card %d uses integer X" % (index + 1))
		_expect(is_equal_approx(card_rect.position.y, roundf(card_rect.position.y)), "Upgrade card %d uses integer Y" % (index + 1))
		var icon := card.find_child("UpgradeIcon", true, false) as TextureRect
		var category := card.find_child("CategoryLabel", true, false) as Label
		var name_label := card.find_child("NameLabel", true, false) as Label
		var level_label := card.find_child("LevelLabel", true, false) as Label
		var stat_label := card.find_child("StatChangeLabel", true, false) as Label
		var description := card.find_child("DescriptionLabel", true, false) as Label
		var shortcut := card.find_child("ShortcutLabel", true, false) as Label
		_expect(icon != null and icon.texture != null, "Upgrade card %d has an icon" % (index + 1))
		_expect(icon != null and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Upgrade card %d icon uses nearest filtering" % (index + 1))
		_expect(category != null and not category.text.is_empty(), "Upgrade card %d has a category" % (index + 1))
		_expect(name_label != null and not name_label.text.is_empty(), "Upgrade card %d has a name" % (index + 1))
		_expect(level_label != null and not level_label.text.is_empty(), "Upgrade card %d has level progress" % (index + 1))
		_expect(stat_label != null and not stat_label.text.is_empty(), "Upgrade card %d has a stat change" % (index + 1))
		_expect(description != null and not description.text.is_empty(), "Upgrade card %d has a description" % (index + 1))
		_expect(shortcut != null and shortcut.text == "[%d]" % (index + 1), "Upgrade card %d has the correct shortcut" % (index + 1))
	for first_index in card_rects.size():
		for second_index in range(first_index + 1, card_rects.size()):
			_expect(not card_rects[first_index].intersects(card_rects[second_index]), "Upgrade cards do not overlap")
	_expect(cards[0].has_focus(), "First upgrade card receives initial focus")

func _capture_screenshot() -> void:
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("Screenshot image is empty")
		return
	var save_error := image.save_png(SCREENSHOT_PATH)
	if save_error != OK:
		_failures.append("Failed to save screenshot: %s" % save_error)
	else:
		print("Saved upgrade UI preview: %s (%sx%s)" % [SCREENSHOT_PATH, image.get_width(), image.get_height()])

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)

func _finish(battle_scene: Node) -> void:
	get_tree().paused = false
	if battle_scene != null:
		battle_scene.queue_free()
	if _failures.is_empty():
		print("Upgrade choice UI runtime validation passed.")
		get_tree().quit(0)
	else:
		push_error("Upgrade choice UI runtime validation failed: %s" % "; ".join(_failures))
		get_tree().quit(1)

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
