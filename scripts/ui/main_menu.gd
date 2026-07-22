extends Control

@onready var start_button: Button = %StartButton
@onready var growth_button: Button = %GrowthButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var character_select_panel: PanelContainer = %CharacterSelectPanel
@onready var growth_panel: PanelContainer = %GrowthPanel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var enter_battle_button: Button = %EnterBattleButton
@onready var character_back_button: Button = %CharacterBackButton
@onready var growth_back_button: Button = %GrowthBackButton
@onready var settings_back_button: Button = %SettingsBackButton
@onready var vitality_button: Button = %VitalityButton
@onready var combat_training_button: Button = %CombatTrainingButton
@onready var blade_storm_button: Button = %BladeStormButton
@onready var crystal_label: Label = %CrystalLabel
@onready var statistics_label: Label = %StatisticsLabel
@onready var volume_label: Label = %VolumeLabel
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var quit_button: Button = %QuitButton

var _syncing_settings := false

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	growth_button.pressed.connect(_show_growth)
	settings_button.pressed.connect(_show_settings)
	enter_battle_button.pressed.connect(_on_enter_battle_pressed)
	character_back_button.pressed.connect(_show_main_menu)
	growth_back_button.pressed.connect(_show_main_menu)
	settings_back_button.pressed.connect(_show_main_menu)
	vitality_button.pressed.connect(_on_talent_pressed.bind(&"vitality"))
	combat_training_button.pressed.connect(_on_talent_pressed.bind(&"combat_training"))
	blade_storm_button.pressed.connect(_on_blade_storm_pressed)
	master_volume_slider.value_changed.connect(_on_volume_changed)
	master_volume_slider.drag_ended.connect(_on_volume_drag_ended)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	quit_button.pressed.connect(_on_quit_pressed)
	ProgressionManager.progression_changed.connect(_refresh_growth)
	character_select_panel.visible = false
	growth_panel.visible = false
	settings_panel.visible = false
	_refresh_growth()
	_refresh_settings()
	start_button.grab_focus()

func _on_start_pressed() -> void:
	_hide_all_panels()
	character_select_panel.visible = true
	enter_battle_button.grab_focus()

func _on_enter_battle_pressed() -> void:
	GameManager.start_new_game()

func _show_growth() -> void:
	_hide_all_panels()
	growth_panel.visible = true
	_refresh_growth()
	vitality_button.grab_focus()

func _show_settings() -> void:
	_hide_all_panels()
	settings_panel.visible = true
	_refresh_settings()
	master_volume_slider.grab_focus()

func _show_main_menu() -> void:
	character_select_panel.visible = false
	growth_panel.visible = false
	settings_panel.visible = false
	menu_panel.visible = true
	start_button.grab_focus()

func _hide_all_panels() -> void:
	menu_panel.visible = false
	character_select_panel.visible = false
	growth_panel.visible = false
	settings_panel.visible = false

func _refresh_growth() -> void:
	if not is_node_ready():
		return
	var crystals := ProgressionManager.get_crystals()
	crystal_label.text = "裂隙结晶：%d" % crystals
	_refresh_talent_button(vitality_button, &"vitality", "坚守：最大生命 +10")
	_refresh_talent_button(combat_training_button, &"combat_training", "锋锐：攻击伤害 +6%")
	if ProgressionManager.is_skill_unlocked(&"blade_storm"):
		blade_storm_button.text = "旋刃风暴：已解锁"
		blade_storm_button.disabled = true
	else:
		blade_storm_button.text = "解锁旋刃风暴  ·  90 结晶"
		blade_storm_button.disabled = crystals < 90
	var statistics := ProgressionManager.get_statistics()
	statistics_label.text = "出战 %d  ·  胜利 %d  ·  击杀 %d\n最高连击 %d  ·  累计结晶 %d" % [
		int(statistics.get("runs_played", 0)),
		int(statistics.get("victories", 0)),
		int(statistics.get("total_kills", 0)),
		int(statistics.get("best_combo", 0)),
		int(statistics.get("total_crystals_earned", 0))
	]

func _refresh_talent_button(button: Button, talent_id: StringName, description: String) -> void:
	var definition: Dictionary = ProgressionManager.TALENT_DEFINITIONS[String(talent_id)]
	var level := ProgressionManager.get_talent_level(talent_id)
	var max_level := int(definition["max_level"])
	button.text = "%s  Lv.%d/%d  ·  %d 结晶" % [description, level, max_level, int(definition["cost"])]
	button.disabled = level >= max_level or ProgressionManager.get_crystals() < int(definition["cost"])

func _on_talent_pressed(talent_id: StringName) -> void:
	ProgressionManager.purchase_talent(talent_id)

func _on_blade_storm_pressed() -> void:
	ProgressionManager.unlock_skill(&"blade_storm")

func _refresh_settings() -> void:
	if not is_node_ready():
		return
	_syncing_settings = true
	master_volume_slider.value = ProgressionManager.get_master_volume_db()
	fullscreen_check.button_pressed = ProgressionManager.is_fullscreen()
	volume_label.text = "主音量：%d dB" % int(master_volume_slider.value)
	_syncing_settings = false

func _on_volume_changed(value: float) -> void:
	volume_label.text = "主音量：%d dB" % int(value)

func _on_volume_drag_ended(_value_changed: bool) -> void:
	if not _syncing_settings:
		ProgressionManager.set_master_volume_db(master_volume_slider.value)

func _on_fullscreen_toggled(value: bool) -> void:
	if not _syncing_settings:
		ProgressionManager.set_fullscreen(value)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and (character_select_panel.visible or growth_panel.visible or settings_panel.visible):
		_show_main_menu()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _on_quit_pressed() -> void:
	get_tree().quit()
