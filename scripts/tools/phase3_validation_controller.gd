extends Node

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

var _dodge_count := 0
var _perfect_count := 0
var _energy_after_perfect := 0.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await _wait_physics_frames(2)
	var battle_error := get_tree().change_scene_to_file(BATTLE_SCENE)
	if battle_error != OK:
		push_error("Failed to load battle scene: %s" % battle_error)
		get_tree().quit(1)
		return

	await _wait_physics_frames(8)
	var player := _get_player()
	var hazard := _get_hazard()
	if player == null or hazard == null:
		push_error("Phase 3 validation missing player or dodge test hazard.")
		get_tree().quit(1)
		return

	player.global_position = Vector2(690, 570)
	player.facing_direction = 1
	if player.has_signal("dodge_started"):
		player.dodge_started.connect(func(): _dodge_count += 1)
	if player.has_signal("perfect_dodge"):
		player.perfect_dodge.connect(_on_perfect_dodge)
	if player.has_signal("ultimate_energy_changed"):
		player.ultimate_energy_changed.connect(func(current: float, _maximum: float): _energy_after_perfect = current)
	await _wait_physics_frames(4)

	var start_x := player.global_position.x
	_press_dodge()
	await _wait_physics_frames(3)
	hazard.global_position = player.global_position + Vector2(8, 0)
	hazard.trigger(0.12)
	await _wait_physics_frames(20)

	if player.global_position.x <= start_x + 40.0:
		push_error("Player did not move far enough during dodge. start=%s now=%s" % [start_x, player.global_position.x])
		get_tree().quit(1)
		return
	if _perfect_count != 1:
		push_error("Perfect dodge should trigger exactly once, got %s" % _perfect_count)
		get_tree().quit(1)
		return
	if _energy_after_perfect < 8.0:
		push_error("Perfect dodge did not increase ultimate energy. energy=%s" % _energy_after_perfect)
		get_tree().quit(1)
		return

	_press_dodge()
	await _wait_physics_frames(4)
	if _dodge_count != 1:
		push_error("Dodge cooldown allowed repeated dodge too early. count=%s" % _dodge_count)
		get_tree().quit(1)
		return

	get_tree().quit(0)

func _press_dodge() -> void:
	Input.action_press("dodge")
	Input.action_release("dodge")

func _on_perfect_dodge(_context: Variant) -> void:
	_perfect_count += 1

func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _get_player() -> Node:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("World/EntityRoot/Player")

func _get_hazard() -> Node:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("World/EntityRoot/DodgeTestHazard")