extends Control

signal pause_requested

const ACTION_BUTTON_SIZE := Vector2(76.0, 64.0)
const TOUCH_BACKGROUND := Color(0.018, 0.028, 0.052, 0.80)
const TOUCH_BORDER := Color(0.42, 0.48, 0.61, 0.92)

var _pressed_actions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_movement_stick()
	_build_action_pad()
	_build_pause_button()

func _exit_tree() -> void:
	for action_variant in _pressed_actions.keys():
		Input.action_release(StringName(action_variant))
	_pressed_actions.clear()

func _build_movement_stick() -> void:
	var stick := TouchStick.new()
	stick.name = "MovementStick"
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 24.0
	stick.offset_top = -178.0
	stick.offset_right = 190.0
	stick.offset_bottom = -18.0
	stick.horizontal_changed.connect(_set_horizontal_movement)
	add_child(stick)

func _build_action_pad() -> void:
	var pad := Control.new()
	pad.name = "ActionPad"
	pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pad.offset_left = -344.0
	pad.offset_top = -164.0
	pad.offset_right = -18.0
	pad.offset_bottom = -18.0
	add_child(pad)
	_add_action_button(pad, "Skill1Button", "U", &"skill_1", Vector2(0.0, 0.0), Color(0.48, 0.20, 0.26, 1.0))
	_add_action_button(pad, "Skill2Button", "I", &"skill_2", Vector2(83.0, 0.0), Color(0.25, 0.38, 0.62, 1.0))
	_add_action_button(pad, "Skill3Button", "O", &"skill_3", Vector2(166.0, 0.0), Color(0.18, 0.49, 0.43, 1.0))
	_add_action_button(pad, "UltimateButton", "L", &"ultimate", Vector2(249.0, 0.0), Color(0.68, 0.50, 0.20, 1.0))
	_add_action_button(pad, "AttackButton", "ATK", &"attack", Vector2(42.0, 82.0), Color(0.54, 0.22, 0.30, 1.0))
	_add_action_button(pad, "DodgeButton", "DODGE", &"dodge", Vector2(125.0, 82.0), Color(0.31, 0.42, 0.66, 1.0))
	_add_action_button(pad, "JumpButton", "JUMP", &"jump", Vector2(208.0, 82.0), Color(0.42, 0.52, 0.70, 1.0))

func _build_pause_button() -> void:
	var pause_button := Button.new()
	pause_button.name = "TouchPauseButton"
	pause_button.text = "II"
	pause_button.tooltip_text = "Pause"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -76.0
	pause_button.offset_top = 18.0
	pause_button.offset_right = -20.0
	pause_button.offset_bottom = 66.0
	pause_button.add_theme_font_size_override("font_size", 24)
	pause_button.add_theme_stylebox_override("normal", _button_style(TOUCH_BORDER))
	pause_button.add_theme_stylebox_override("pressed", _button_style(TOUCH_BORDER.lightened(0.18), Color(0.10, 0.12, 0.18, 0.95)))
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause_button)

func _add_action_button(parent: Control, node_name: String, label: String, action: StringName, position: Vector2, accent: Color) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.tooltip_text = label
	button.focus_mode = Control.FOCUS_NONE
	button.position = position
	button.size = ACTION_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", _button_style(accent))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.12), Color(0.07, 0.09, 0.15, 0.94)))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.24), Color(0.12, 0.08, 0.16, 0.98)))
	button.button_down.connect(_press_action.bind(action))
	button.button_up.connect(_release_action.bind(action))
	parent.add_child(button)

func _button_style(border: Color, background := TOUCH_BACKGROUND) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.anti_aliasing = false
	return style

func _set_horizontal_movement(value: float) -> void:
	if value < -0.1:
		_press_action(&"move_left")
	else:
		_release_action(&"move_left")
	if value > 0.1:
		_press_action(&"move_right")
	else:
		_release_action(&"move_right")

func _press_action(action: StringName) -> void:
	if _pressed_actions.has(action):
		return
	_pressed_actions[action] = true
	_dispatch_action(action, true)

func _release_action(action: StringName) -> void:
	if not _pressed_actions.has(action):
		return
	_pressed_actions.erase(action)
	_dispatch_action(action, false)

func _dispatch_action(action: StringName, is_pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = is_pressed
	Input.parse_input_event(event)

class TouchStick extends Control:
	signal horizontal_changed(value: float)

	var _touch_id := -1
	var _horizontal := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _touch_id == -1:
				_touch_id = touch.index
				_update_horizontal(touch.position - global_position)
			elif not touch.pressed and touch.index == _touch_id:
				_touch_id = -1
				_update_horizontal(size * 0.5)
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _touch_id:
				_update_horizontal(drag.position - global_position)
		elif event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT:
				if mouse_button.pressed:
					_touch_id = 0
					_update_horizontal(mouse_button.position - global_position)
				elif _touch_id == 0:
					_touch_id = -1
					_update_horizontal(size * 0.5)
		elif event is InputEventMouseMotion and _touch_id == 0:
			var mouse_motion := event as InputEventMouseMotion
			_update_horizontal(mouse_motion.position - global_position)

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 62.0, Color(0.02, 0.035, 0.065, 0.66), true)
		draw_arc(center, 62.0, 0.0, TAU, 32, Color(0.42, 0.48, 0.61, 0.9), 2.0, true)
		draw_circle(center + Vector2(_horizontal * 34.0, 0.0), 25.0, Color(0.22, 0.30, 0.46, 0.84), true)
		draw_string(get_theme_default_font(), center + Vector2(-30.0, 6.0), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 15, Color(0.86, 0.90, 0.96, 0.86))

	func _update_horizontal(local_position: Vector2) -> void:
		var offset_x := local_position.x - size.x * 0.5
		var next_horizontal := 0.0
		if absf(offset_x) >= 20.0:
			next_horizontal = signf(offset_x)
		if is_equal_approx(next_horizontal, _horizontal):
			return
		_horizontal = next_horizontal
		horizontal_changed.emit(_horizontal)
		queue_redraw()