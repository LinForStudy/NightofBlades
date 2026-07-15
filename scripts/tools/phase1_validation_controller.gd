extends Node

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

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
	if player == null:
		push_error("Phase 1 validation could not find Player.")
		get_tree().quit(1)
		return

	var start_position := player.global_position
	Input.action_press("move_right")
	await _wait_physics_frames(24)
	Input.action_release("move_right")
	if player.global_position.x <= start_position.x + 30.0:
		push_error("Player did not move right far enough. start=%s now=%s" % [start_position, player.global_position])
		get_tree().quit(1)
		return

	var jump_start_position := player.global_position
	var grounded_before_jump := player.is_on_floor()
	Input.action_press("jump")
	await _wait_physics_frames(2)
	Input.action_release("jump")
	await _wait_physics_frames(10)
	if grounded_before_jump and player.global_position.y >= jump_start_position.y - 20.0:
		push_error("Player did not jump upward enough. start=%s now=%s" % [jump_start_position, player.global_position])
		get_tree().quit(1)
		return

	await _wait_physics_frames(70)
	if not player.is_on_floor():
		push_error("Player did not land after jump validation.")
		get_tree().quit(1)
		return

	var camera := get_tree().current_scene.get_node_or_null("CameraRig/Camera2D")
	if camera == null:
		push_error("BattleScene is missing CameraRig/Camera2D.")
		get_tree().quit(1)
		return

	get_tree().quit(0)

func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _get_player() -> CharacterBody2D:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("World/EntityRoot/Player") as CharacterBody2D