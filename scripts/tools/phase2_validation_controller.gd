extends Node

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

var _hit_count := 0

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
	var dummy := _get_dummy()
	if player == null or dummy == null:
		push_error("Phase 2 validation missing player or training dummy.")
		get_tree().quit(1)
		return

	player.global_position = Vector2(450, 570)
	dummy.global_position = Vector2(520, 570)
	if player.has_signal("attack_landed"):
		player.attack_landed.connect(_on_attack_landed)
	await _wait_physics_frames(4)

	var health := dummy.get_node_or_null("HealthComponent")
	if health == null:
		push_error("Training dummy is missing HealthComponent.")
		get_tree().quit(1)
		return
	var starting_health: float = health.current_health

	_attack_press()
	await _wait_physics_frames(10)
	_attack_press()
	await _wait_physics_frames(16)
	_attack_press()
	await _wait_physics_frames(42)

	if health.current_health >= starting_health:
		push_error("Training dummy did not take damage. start=%s now=%s" % [starting_health, health.current_health])
		get_tree().quit(1)
		return
	if _hit_count < 1:
		push_error("Player attack_landed signal did not fire.")
		get_tree().quit(1)
		return
	if get_tree().current_scene.get_node_or_null("World/EffectRoot") == null:
		push_error("BattleScene is missing EffectRoot for damage numbers.")
		get_tree().quit(1)
		return

	get_tree().quit(0)

func _attack_press() -> void:
	Input.action_press("attack")
	Input.action_release("attack")

func _on_attack_landed(_context: Variant) -> void:
	_hit_count += 1

func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _get_player() -> Node:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("World/EntityRoot/Player")

func _get_dummy() -> Node:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("World/EntityRoot/TrainingDummy")