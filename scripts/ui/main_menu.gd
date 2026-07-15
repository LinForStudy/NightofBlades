extends Control

@onready var start_button: Button = %StartButton
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var character_select_panel: PanelContainer = %CharacterSelectPanel
@onready var enter_battle_button: Button = %EnterBattleButton
@onready var character_back_button: Button = %CharacterBackButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	enter_battle_button.pressed.connect(_on_enter_battle_pressed)
	character_back_button.pressed.connect(_show_main_menu)
	quit_button.pressed.connect(_on_quit_pressed)
	character_select_panel.visible = false
	start_button.grab_focus()

func _on_start_pressed() -> void:
	menu_panel.visible = false
	character_select_panel.visible = true
	enter_battle_button.grab_focus()

func _on_enter_battle_pressed() -> void:
	GameManager.start_new_game()

func _show_main_menu() -> void:
	character_select_panel.visible = false
	menu_panel.visible = true
	start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if character_select_panel.visible and event.is_action_pressed(&"ui_cancel"):
		_show_main_menu()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
func _on_quit_pressed() -> void:
	get_tree().quit()