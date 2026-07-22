class_name BattleHud
extends Control

const MobileControls := preload("res://scripts/ui/mobile_controls.gd")

@export var force_mobile_controls := false

@export var player_path: NodePath
@export var boss_path: NodePath
@export var experience_manager_path: NodePath

@onready var hp_bar: ProgressBar = %HealthBar
@onready var hp_text: Label = %HealthText
@onready var level_label: Label = %LevelLabel
@onready var exp_bar: ProgressBar = %ExperienceBar
@onready var boss_panel: PanelContainer = %BossStatusPanel
@onready var boss_name: Label = %BossNameLabel
@onready var phase_label: Label = %PhaseLabel
@onready var boss_bar: ProgressBar = %BossHealthBar
@onready var boss_value: Label = %BossValueLabel
@onready var poise_bar: ProgressBar = %PoiseBar
@onready var poise_text: Label = %PoiseText
@onready var debug_overlay: PanelContainer = %DebugOverlay
@onready var announcement_label: Label = %AnnouncementLabel
@onready var defeat_panel: PanelContainer = %DefeatPanel
@onready var victory_panel: PanelContainer = %VictoryPanel
@onready var defeat_stats_label: Label = %DefeatStatsLabel
@onready var victory_stats_label: Label = %VictoryStatsLabel
@onready var defeat_restart_button: Button = %DefeatRestartButton
@onready var defeat_menu_button: Button = %DefeatMenuButton
@onready var victory_restart_button: Button = %VictoryRestartButton
@onready var victory_menu_button: Button = %VictoryMenuButton
@onready var pause_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var pause_menu_button: Button = %PauseMenuButton
@onready var ultimate_bar: ProgressBar = %UltimateEnergyBar
@onready var ultimate_text: Label = %UltimateText
@onready var skill_bar: PanelContainer = %SkillBar
@onready var low_health_frame: Panel = %LowHealthFrame
@onready var ultimate_icon: TextureRect = %UltimateIconTexture

var _mobile_controls
var _is_mobile_layout := false

var _player: Node
var _boss: Node
var _experience_manager: Node
var _skill_manager: Node
var _run_time := 0.0
var _kill_count := 0
var _skill_ids: Array[StringName] = []
var _announcement_time := 0.0
var _boss_is_presented := false
var _ultimate_ready := false
var _health_ratio := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_overlay.visible = false
	defeat_panel.visible = false
	victory_panel.visible = false
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	skill_bar.modulate = Color.WHITE
	defeat_restart_button.pressed.connect(_restart_battle)
	defeat_menu_button.pressed.connect(_return_to_menu)
	victory_restart_button.pressed.connect(_restart_battle)
	victory_menu_button.pressed.connect(_return_to_menu)
	resume_button.pressed.connect(_resume_battle)
	restart_button.pressed.connect(_restart_battle)
	pause_menu_button.pressed.connect(_return_to_menu)
	_is_mobile_layout = force_mobile_controls or OS.has_feature("mobile")
	if _is_mobile_layout:
		_setup_mobile_controls()
	announcement_label.visible = false
	_player = get_node_or_null(player_path)
	_boss = get_node_or_null(boss_path)
	_experience_manager = get_node_or_null(experience_manager_path)
	_bind_player()
	_bind_experience()
	_bind_boss()

func is_mobile_layout() -> bool:
	return _is_mobile_layout

func _setup_mobile_controls() -> void:
	_mobile_controls = MobileControls.new()
	_mobile_controls.name = "MobileControls"
	_mobile_controls.pause_requested.connect(_toggle_pause_from_touch)
	add_child(_mobile_controls)

func _toggle_pause_from_touch() -> void:
	if pause_panel.visible:
		_resume_battle()
	elif not defeat_panel.visible and not victory_panel.visible:
		_pause_battle()
func _unhandled_input(event: InputEvent) -> void:
	if (defeat_panel.visible or victory_panel.visible) and event.is_action_pressed(&"ui_cancel"):
		_return_to_menu()
		_mark_input_handled()
		return
	if victory_panel.visible and event.is_action_pressed(&"ui_accept"):
		_restart_battle()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"pause"):
		if pause_panel.visible:
			_resume_battle()
		elif not defeat_panel.visible and not victory_panel.visible:
			_pause_battle()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"debug_toggle"):
		debug_overlay.visible = not debug_overlay.visible
		_mark_input_handled()

func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _process(delta: float) -> void:
	%TimerLabel.text = "时间 %02d:%02d" % [int(_run_time) / 60, int(_run_time) % 60]
	if _announcement_time > 0.0:
		_announcement_time -= delta
		if _announcement_time <= 0.0:
			announcement_label.visible = false
	_update_boss_visibility()
	_update_ultimate_ready_glow()
	_update_low_health_pulse()
	if debug_overlay.visible:
		_refresh_debug()

func _pause_battle() -> void:
	pause_panel.visible = true
	GameManager.set_paused(true)

func _resume_battle() -> void:
	pause_panel.visible = false
	GameManager.set_paused(false)

func _restart_battle() -> void:
	GameManager.restart_battle()

func _return_to_menu() -> void:
	GameManager.go_to_main_menu()

func set_run_stats(elapsed_seconds: float, kill_count: int, combo_count: int = 0) -> void:
	_run_time = maxf(elapsed_seconds, 0.0)
	_kill_count = maxi(kill_count, 0)
	%TimerLabel.text = "时间 %02d:%02d" % [int(_run_time) / 60, int(_run_time) % 60]
	%KillLabel.text = "击杀 %s" % _kill_count
	%ComboLabel.text = "连击 %s" % maxi(combo_count, 0)

func show_defeat() -> void:
	defeat_panel.visible = true
	skill_bar.modulate = Color(0.62, 0.62, 0.68, 0.78)
	_refresh_result_stats(defeat_stats_label)
	show_announcement("守夜人倒下了", 2.0)

func show_victory() -> void:
	victory_panel.visible = true
	_refresh_result_stats(victory_stats_label)
	show_announcement("裂隙稳定，战斗胜利", 2.0)

func _refresh_result_stats(stats_label: Label) -> void:
	var elapsed_seconds: int = int(GameManager.last_battle_duration_seconds)
	var minutes: int = elapsed_seconds / 60
	var seconds: int = elapsed_seconds % 60
	var boss_result: String = "已击败 Boss" if GameManager.last_battle_boss_defeated else "未击败 Boss"
	stats_label.text = "本局 %02d:%02d  击杀 %d  连击 %d\n伤害 %.0f  受伤 %.0f\n常用 %s  结晶 +%d\n%s" % [minutes, seconds, GameManager.last_battle_kill_count, GameManager.last_battle_max_combo, GameManager.last_battle_damage_dealt, GameManager.last_battle_damage_received, GameManager.last_battle_most_used_skill, GameManager.last_battle_crystal_reward, boss_result]

func show_announcement(message: String, duration := 1.6) -> void:
	announcement_label.text = message
	announcement_label.visible = true
	_announcement_time = duration

func _bind_player() -> void:
	if _player == null:
		return
	var health := _player.get_node_or_null("HealthComponent")
	if health != null:
		health.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(health.current_health, health.max_health)
	if _player.has_signal("ultimate_energy_changed"):
		_player.ultimate_energy_changed.connect(_on_ultimate_energy_changed)
		_on_ultimate_energy_changed(float(_player.ultimate_energy), float(_player.ultimate_energy_max))
	_skill_manager = _player.get_node_or_null("SkillManager")
	if _skill_manager != null:
		_skill_manager.skill_cooldown_changed.connect(_on_skill_cooldown_changed)
		if _skill_manager.has_signal("skill_upgrade_applied"):
			_skill_manager.skill_upgrade_applied.connect(_on_skill_upgrade_applied)
		_refresh_skill_slots()

func _bind_experience() -> void:
	if _experience_manager == null:
		return
	_experience_manager.experience_changed.connect(_on_experience_changed)
	_on_experience_changed(_experience_manager.current_experience, _experience_manager._required_for_next_level(), _experience_manager.level)

func _bind_boss() -> void:
	if _boss == null:
		boss_panel.visible = false
		return
	boss_panel.visible = false
	_boss.boss_health_changed.connect(_on_boss_health_changed)
	_boss.boss_poise_changed.connect(_on_boss_poise_changed)
	_boss.boss_phase_changed.connect(_on_boss_phase_changed)
	if _boss.has_signal("boss_announcement"):
		_boss.boss_announcement.connect(show_announcement)
	if _boss.has_signal("boss_defeated"):
		_boss.boss_defeated.connect(_on_boss_defeated)
	_on_boss_health_changed(_boss.health.current_health, _boss.health.max_health)
	_on_boss_poise_changed(_boss.current_poise, _boss.max_poise)
	_on_boss_phase_changed(_boss.phase)

func _update_boss_visibility() -> void:
	if _boss == null or not is_instance_valid(_boss) or _player == null:
		return
	var is_boss_active: bool = bool(_boss.get("is_activated"))
	var should_show: bool = is_boss_active and _player.global_position.distance_to(_boss.global_position) <= 860.0
	if should_show == _boss_is_presented:
		return
	_boss_is_presented = should_show
	boss_panel.visible = should_show
	if should_show:
		show_announcement("裂隙巨像进入战区", 1.4)

func _on_player_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	_health_ratio = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	hp_text.text = "生命 %s / %s" % [ceili(current), ceili(maximum)]

func _on_experience_changed(current: int, required: int, level: int) -> void:
	level_label.text = "等级.%s" % level
	exp_bar.max_value = required
	exp_bar.value = current
	%ExperienceText.text = "%s / %s" % [current, required]

func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_value.text = "%s / %s" % [ceili(current), ceili(maximum)]

func _on_boss_poise_changed(current: float, maximum: float) -> void:
	poise_bar.max_value = maximum
	poise_bar.value = current
	poise_text.text = "韧性 %s / %s" % [ceili(current), ceili(maximum)]

func _on_boss_phase_changed(phase: int) -> void:
	phase_label.text = "阶段 %s" % phase

func _on_boss_defeated(_boss_node: Node) -> void:
	boss_panel.visible = false
	show_announcement("裂隙巨像已退散", 2.2)

func _refresh_skill_slots() -> void:
	if _skill_manager == null:
		return
	_skill_ids.clear()
	for index in 3:
		var data: Resource = _skill_manager.get_skill_data(index)
		var slot := get_node_or_null("SkillBar/Slots/SkillSlot%s" % (index + 1))
		if slot == null:
			_skill_ids.append(StringName())
			continue
		slot.visible = true
		if data == null:
			_skill_ids.append(StringName())
			_set_skill_slot_unavailable(slot)
			continue
		var skill_id := StringName(str(data.get("skill_id")))
		_skill_ids.append(skill_id)
		slot.modulate = Color.WHITE
		slot.tooltip_text = str(data.get("display_name"))
		slot.get_node("Content/Level").text = "%s" % _skill_manager.get_skill_level(skill_id)
		var bar: ProgressBar = slot.get_node("Content/Cooldown")
		bar.max_value = float(data.get("base_cooldown"))
		bar.value = float(data.get("base_cooldown"))
		_set_skill_slot_cooldown_visual(slot, 0.0, float(data.get("base_cooldown")))

func _set_skill_slot_unavailable(slot: Control) -> void:
	slot.modulate = Color(0.52, 0.52, 0.58, 1.0)
	slot.tooltip_text = ""
	slot.get_node("Content/Level").text = "-"
	var mask: ColorRect = slot.get_node("Content/CooldownMask")
	mask.visible = true
	mask.position = Vector2(8.0, 10.0)
	mask.size = Vector2(48.0, 48.0)
	slot.get_node("Content/CooldownText").text = ""
	slot.get_node("Content/ReadyFrame").visible = false
	slot.get_node("Content/IconTexture").modulate = Color(0.46, 0.46, 0.5, 1.0)

func _on_skill_upgrade_applied(_upgrade: Resource, _level: int, _branch: StringName) -> void:
	_refresh_skill_slots()

func _on_skill_cooldown_changed(skill_id: StringName, remaining: float, total: float) -> void:
	var index := _skill_ids.find(skill_id)
	if index < 0:
		return
	var slot := get_node_or_null("SkillBar/Slots/SkillSlot%s" % (index + 1))
	if slot == null:
		return
	var bar: ProgressBar = slot.get_node("Content/Cooldown")
	bar.max_value = total
	bar.value = maxf(total - remaining, 0.0)
	_set_skill_slot_cooldown_visual(slot, remaining, total)

func _set_skill_slot_cooldown_visual(slot: Control, remaining: float, total: float) -> void:
	var is_ready := remaining <= 0.02
	var fraction := clampf(remaining / maxf(total, 0.001), 0.0, 1.0)
	var mask: ColorRect = slot.get_node("Content/CooldownMask")
	var cooldown_text: Label = slot.get_node("Content/CooldownText")
	var ready_frame: Control = slot.get_node("Content/ReadyFrame")
	var icon_texture: TextureRect = slot.get_node("Content/IconTexture")
	mask.visible = not is_ready
	mask.position = Vector2(8.0, 10.0 + 48.0 * (1.0 - fraction))
	mask.size = Vector2(48.0, 48.0 * fraction)
	cooldown_text.text = "" if is_ready else ("%ds" % ceili(remaining) if remaining > 1.0 else "%.1fs" % remaining)
	ready_frame.visible = is_ready
	icon_texture.modulate = Color.WHITE if is_ready else Color(0.42, 0.42, 0.48, 1.0)

func _on_ultimate_energy_changed(current: float, maximum: float) -> void:
	ultimate_bar.max_value = maximum
	ultimate_bar.value = current
	ultimate_text.text = "%s%%" % ceili(current / maxf(maximum, 1.0) * 100.0)
	_ultimate_ready = current >= maximum
	ultimate_icon.modulate = Color.WHITE if _ultimate_ready else Color(0.45, 0.42, 0.5, 1.0)
	var ready_glow: Control = get_node_or_null("SkillBar/Slots/UltimateSlot/Content/ReadyGlow")
	if ready_glow != null:
		ready_glow.visible = _ultimate_ready

func _update_low_health_pulse() -> void:
	var should_pulse := _health_ratio > 0.0 and _health_ratio < 0.3
	low_health_frame.visible = should_pulse
	if should_pulse:
		low_health_frame.modulate.a = 0.58 + sin(Time.get_ticks_msec() * 0.004) * 0.22

func _update_ultimate_ready_glow() -> void:
	if not _ultimate_ready:
		return
	var ready_glow: Control = get_node_or_null("SkillBar/Slots/UltimateSlot/Content/ReadyGlow")
	if ready_glow != null:
		ready_glow.modulate.a = 0.68 + sin(Time.get_ticks_msec() * 0.004) * 0.16

func _refresh_debug() -> void:
	var state := "none" if _player == null else str(_player.get_state_name())
	var hp := "-" if _player == null else "%s" % _player.health.current_health
	var boss_state := "none" if _boss == null or not is_instance_valid(_boss) else "%s / P%s" % [_boss.BossState.keys()[_boss.state], _boss.phase]
	var enemy_count: int = maxi(get_tree().get_nodes_in_group(&"enemy").size(), 0)
	%DebugText.text = "玩家状态: %s\n内部生命: %s\nBoss: %s\n敌人: %s\nFPS: %s\n对象池: %s" % [state, hp, boss_state, enemy_count, Engine.get_frames_per_second(), ObjectPoolManager._pools.size()]
