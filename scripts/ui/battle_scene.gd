extends Node2D

const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/damage_number.tscn")
const BOSS_UNLOCK_LEVEL := 8
const BOSS_APPROACH_DISTANCE := 1400.0
const BOSS_ARENA_MAX_ENTRANCE_X := 6600.0
const BOSS_ARENA_GAP := 400.0

const REGION_DATA := {
	&"village_gate": {"title": "守夜村口", "message": "守住村口，向右清剿裂隙杂兵。", "wave_index": 0},
	&"broken_bridge": {"title": "断桥巷道", "message": "断桥巷道：远程与飞行威胁正在靠近。", "wave_index": 1},
	&"rift_invasion": {"title": "裂隙侵蚀区", "message": "裂隙侵蚀加剧：精英怪物已混入队列。", "wave_index": 2},
	&"colossus_courtyard": {"title": "巨像前庭", "message": "巨像前庭：保持推进，寻找裂隙巨像。", "wave_index": 4}
}

@onready var effect_root: Node2D = $World/EffectRoot
@onready var camera: Camera2D = $CameraRig/Camera2D
@onready var experience_manager: Node = $Managers/ExperienceManager
@onready var wave_manager: Node = $Managers/WaveManager
@onready var level_up_dimmer: ColorRect = %LevelUpDimmer
@onready var level_up_panel: PanelContainer = %LevelUpPanel
@onready var upgrade_title: Label = %UpgradeTitle
@onready var upgrade_subtitle: Label = %UpgradeSubtitle
@onready var upgrade_buttons: Array[Button] = [%UpgradeButton1, %UpgradeButton2, %UpgradeButton3]
@onready var player: Node = $World/EntityRoot/Player
@onready var battle_hud: BattleHud = $CanvasLayer/BattleHUD
@onready var boss_entrance: Area2D = $World/BossEntrance
@onready var boss: Node = $World/EntityRoot/RiftColossus

var _battle_completed := false
var _boss_encounter_started := false
var _boss_entrance_armed := false
var _battle_elapsed_seconds := 0.0
var _battle_kill_count := 0
var _battle_combo_count := 0
var _battle_max_combo := 0
var _combo_timeout := 0.0
var _battle_damage_dealt := 0.0
var _battle_damage_received := 0.0
var _skill_cast_counts: Dictionary = {}
var _visited_regions: Dictionary = {}

func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.BATTLE and not get_tree().paused:
		_battle_elapsed_seconds += delta
		_combo_timeout = maxf(_combo_timeout - delta, 0.0)
		if _combo_timeout <= 0.0:
			_battle_combo_count = 0
	if battle_hud != null:
		battle_hud.set_run_stats(_battle_elapsed_seconds, _battle_kill_count, _battle_combo_count)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_phase6_progression()
	_setup_player_death_listener()
	_setup_phase10_completion()
	_configure_mobile_upgrade_ui()
	call_deferred("_enter_region", &"village_gate")
	EventBus.battle_started.emit()

func _configure_mobile_upgrade_ui() -> void:
	if battle_hud != null and battle_hud.is_mobile_layout():
		var input_hint := level_up_panel.get_node_or_null("InnerFrame/Content/Footer/InputHint") as Label
		if input_hint != null:
			input_hint.text = "Tap an upgrade card to continue"
func _unhandled_input(event: InputEvent) -> void:
	if level_up_panel == null or not level_up_panel.visible:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var selected_index: int = -1
	match key_event.keycode:
		KEY_1:
			selected_index = 0
		KEY_2:
			selected_index = 1
		KEY_3:
			selected_index = 2
		_:
			return
	if selected_index >= upgrade_buttons.size():
		return
	var button: Button = upgrade_buttons[selected_index]
	if not button.visible or button.disabled:
		return
	_on_upgrade_button_pressed(selected_index)
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _setup_phase6_progression() -> void:
	_set_level_up_overlay_visible(false)
	if level_up_panel != null:
		level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	for index in upgrade_buttons.size():
		upgrade_buttons[index].pressed.connect(_on_upgrade_button_pressed.bind(index))
	if experience_manager != null:
		experience_manager.level_up_choices_ready.connect(_on_level_up_choices_ready)
		experience_manager.level_up_finished.connect(_on_level_up_finished)
		experience_manager.experience_changed.connect(_on_experience_changed_for_boss)
		_on_experience_changed_for_boss(experience_manager.current_experience, experience_manager._required_for_next_level(), experience_manager.level)
	if wave_manager != null and wave_manager.has_signal("enemy_spawned"):
		wave_manager.enemy_spawned.connect(_connect_enemy_for_experience)
	for child in $World/EntityRoot.get_children():
		_connect_enemy_for_experience(child)

func _setup_phase10_completion() -> void:
	if boss != null and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	if boss != null:
		_connect_target_damage(boss)

	if boss_entrance != null:
		boss_entrance.set_deferred("monitoring", false)

func _on_experience_changed_for_boss(_current: int, _required: int, level: int) -> void:
	if level < BOSS_UNLOCK_LEVEL or _boss_entrance_armed or _boss_encounter_started:
		return
	_boss_entrance_armed = true
	_position_boss_gate()
	if _player_has_reached_boss_gate():
		_start_boss_encounter()
		return
	if boss_entrance != null:
		boss_entrance.set_deferred("monitoring", true)
	if battle_hud != null:
		battle_hud.show_announcement("裂隙感应开启：继续向右推进，寻找巨像。", 2.4)

func _position_boss_gate() -> void:
	if player == null:
		return
	var entrance_x: float = minf(float(player.global_position.x) + BOSS_APPROACH_DISTANCE, BOSS_ARENA_MAX_ENTRANCE_X)
	if boss_entrance != null:
		boss_entrance.global_position = Vector2(entrance_x, boss_entrance.global_position.y)
	if boss != null:
		boss.global_position = Vector2(entrance_x + BOSS_ARENA_GAP, boss.global_position.y)

func _player_has_reached_boss_gate() -> bool:
	return player != null and boss_entrance != null and player.global_position.x >= boss_entrance.global_position.x

func _on_region_gate_body_entered(body: Node2D, region_id: StringName) -> void:
	if body == player:
		_enter_region(region_id)

func _enter_region(region_id: StringName) -> void:
	if _visited_regions.has(region_id):
		return
	var region: Dictionary = REGION_DATA.get(region_id, {})
	if region.is_empty():
		return
	_visited_regions[region_id] = true
	if wave_manager != null and wave_manager.has_method("set_stage_wave_index"):
		wave_manager.set_stage_wave_index(int(region["wave_index"]))
	if battle_hud != null:
		battle_hud.show_announcement("%s · %s" % [region["title"], region["message"]], 2.3)

func _on_boss_entrance_body_entered(body: Node2D) -> void:
	if body == player and _boss_entrance_armed:
		_start_boss_encounter()

func _start_boss_encounter() -> void:
	if _boss_encounter_started:
		return
	_boss_encounter_started = true
	if boss_entrance != null:
		boss_entrance.set_deferred("monitoring", false)
	if wave_manager != null:
		wave_manager.stop_waves()
		if wave_manager.has_method("clear_active_enemies"):
			wave_manager.clear_active_enemies()
	if battle_hud != null:
		battle_hud.show_announcement("裂隙巨像即将苏醒", 1.5)
	if boss != null and boss.has_method("activate_boss"):
		boss.activate_boss(1.5)
func _on_boss_defeated(_boss: Node) -> void:
	if _battle_completed:
		return
	_battle_completed = true
	if wave_manager != null and wave_manager.has_method("stop_waves"):
		wave_manager.stop_waves()
	_store_result_stats(true)
	if battle_hud != null:
		battle_hud.show_victory()
	GameManager.finish_battle(true)

func _setup_player_death_listener() -> void:
	if player == null:
		return
	var health: Node = player.get_node_or_null("HealthComponent")
	if health == null:
		return
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	else:
		health.depleted.connect(_on_player_depleted)
	if health.has_signal("damaged"):
		health.damaged.connect(_on_player_damaged)
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager != null and skill_manager.has_signal("skill_cast"):
		skill_manager.skill_cast.connect(_on_skill_cast)

func _on_player_died(_player: Node) -> void:
	_show_defeat()

func _on_player_depleted(_context: Variant) -> void:
	_show_defeat()

func _show_defeat() -> void:
	_store_result_stats(false)
	if battle_hud != null:
		battle_hud.show_defeat()
	GameManager.finish_battle(false)

func _connect_enemy_for_experience(enemy: Node) -> void:
	if enemy == null or not enemy.has_signal("enemy_died"):
		return
	var callback := Callable(self, "_on_enemy_died_for_experience")
	if not enemy.enemy_died.is_connected(callback):
		enemy.enemy_died.connect(callback)
	_connect_target_damage(enemy)

func _connect_target_damage(target: Node) -> void:
	if target == null:
		return
	var health: Node = target.get_node_or_null("HealthComponent")
	if health == null or not health.has_signal("damaged"):
		return
	var callback := Callable(self, "_on_target_damaged")
	if not health.damaged.is_connected(callback):
		health.damaged.connect(callback)

func _on_target_damaged(amount: float, _context: Variant) -> void:
	_battle_damage_dealt += maxf(amount, 0.0)
	_battle_combo_count += 1
	_battle_max_combo = maxi(_battle_max_combo, _battle_combo_count)
	_combo_timeout = 2.4

func _on_player_damaged(amount: float, _context: Variant) -> void:
	_battle_damage_received += maxf(amount, 0.0)

func _on_skill_cast(_skill_id: StringName, skill_data: Resource) -> void:
	if skill_data == null:
		return
	var skill_name: String = str(skill_data.get("display_name"))
	if skill_name.is_empty():
		skill_name = "未知技能"
	_skill_cast_counts[skill_name] = int(_skill_cast_counts.get(skill_name, 0)) + 1

func _store_result_stats(boss_defeated: bool) -> void:
	var most_used_skill := "未使用"
	var highest_cast_count := 0
	for skill_name_key in _skill_cast_counts:
		var cast_count: int = int(_skill_cast_counts[skill_name_key])
		if cast_count > highest_cast_count:
			highest_cast_count = cast_count
			most_used_skill = str(skill_name_key)
	GameManager.set_battle_result_stats(_battle_elapsed_seconds, _battle_kill_count, boss_defeated, _battle_max_combo, _battle_damage_dealt, _battle_damage_received, most_used_skill)

func _on_enemy_died_for_experience(enemy: Node) -> void:
	_battle_kill_count += 1
	if battle_hud != null:
		battle_hud.set_run_stats(_battle_elapsed_seconds, _battle_kill_count)
	if experience_manager == null or not experience_manager.has_method("spawn_experience_orb"):
		return
	var value := 5
	if enemy.has_method("get_experience_value"):
		value = int(enemy.get_experience_value())
	else:
		var enemy_data: Resource = enemy.get("enemy_data")
		if enemy_data != null:
			value = int(enemy_data.get("experience_value"))
	experience_manager.spawn_experience_orb(value, enemy.global_position + Vector2(0, -28))

func _on_level_up_choices_ready(options: Array[Resource], pending_count: int) -> void:
	if level_up_panel == null:
		return
	_set_level_up_overlay_visible(true)
	if upgrade_title != null:
		upgrade_title.text = "等级提升 · 选择一项强化"
	if upgrade_subtitle != null:
		if pending_count > 1:
			upgrade_subtitle.text = "从三项能力中选择一项 · 本轮后仍有 %d 次待选择" % (pending_count - 1)
		else:
			upgrade_subtitle.text = "从三项能力中选择一项，继续守夜"
	for index in upgrade_buttons.size():
		var button := upgrade_buttons[index]
		if index < options.size():
			var upgrade := options[index]
			button.visible = true
			button.disabled = false
			if button.has_method("present_upgrade"):
				button.call("present_upgrade", upgrade, _get_upgrade_stack(upgrade), _get_upgrade_max(upgrade), index + 1)
			else:
				button.text = "[%s] %s" % [index + 1, upgrade.get("display_name")]
		else:
			button.visible = false
			button.disabled = true
	for button in upgrade_buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			break

func _on_upgrade_button_pressed(index: int) -> void:
	_set_level_up_overlay_visible(false)
	if experience_manager != null and experience_manager.has_method("choose_upgrade"):
		experience_manager.choose_upgrade(index)

func _on_level_up_finished(_level: int) -> void:
	_set_level_up_overlay_visible(false)

func _set_level_up_overlay_visible(is_visible: bool) -> void:
	if level_up_dimmer != null:
		level_up_dimmer.visible = is_visible
	if level_up_panel != null:
		level_up_panel.visible = is_visible
func _get_upgrade_stack(upgrade: Resource) -> int:
	var manager := $Managers/UpgradeManager
	if manager != null and manager.has_method("get_stack_count"):
		return int(manager.get_stack_count(upgrade))
	return 0
func _get_upgrade_max(upgrade: Resource) -> int:
	var manager := $Managers/UpgradeManager
	if manager != null and manager.has_method("get_max_progress"):
		return int(manager.get_max_progress(upgrade))
	return int(upgrade.get("max_stacks"))

func spawn_damage_number(amount: float, world_position: Vector2) -> void:
	var number := DAMAGE_NUMBER_SCENE.instantiate()
	effect_root.add_child(number)
	number.setup(amount, world_position)

func request_hit_feedback(combo_index: int) -> void:
	var shake_strength := 3.0 + float(combo_index) * 1.5
	if camera != null:
		camera.request_shake(shake_strength, 0.08)
	_hit_pause(0.035 + float(combo_index) * 0.012)
func request_player_hit_feedback(_world_position: Vector2) -> void:
	if camera != null:
		camera.request_shake(7.0, 0.13)
	_hit_pause(0.05)

func request_perfect_dodge_feedback(world_position: Vector2) -> void:
	spawn_damage_number(8.0, world_position + Vector2(-18, -92))
	if camera != null:
		camera.request_shake(5.0, 0.10)
	_slow_motion(0.18, 0.35)

func _slow_motion(duration: float, scale: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _hit_pause(duration: float) -> void:
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false
