extends Node

signal game_state_changed(new_state: String)
signal scene_change_failed(scene_path: String, reason: String)

enum GameState { BOOTSTRAP, MAIN_MENU, BATTLE, PAUSED, RESULT }

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

var current_state: GameState = GameState.BOOTSTRAP
var previous_state: GameState = GameState.BOOTSTRAP
var last_battle_success := false
var last_battle_duration_seconds := 0.0
var last_battle_kill_count := 0
var last_battle_boss_defeated := false
var last_battle_max_combo := 0
var last_battle_damage_dealt := 0.0
var last_battle_damage_received := 0.0
var last_battle_most_used_skill := "未使用"
var last_battle_crystal_reward := 0

func start_new_game() -> void:
	_reset_runtime_state()
	_set_state(GameState.BATTLE)
	_change_scene(BATTLE_SCENE)

func restart_battle() -> void:
	_reset_runtime_state()
	_set_state(GameState.BATTLE)
	_change_scene(BATTLE_SCENE)

func go_to_main_menu() -> void:
	_reset_runtime_state()
	_set_state(GameState.MAIN_MENU)
	_change_scene(MAIN_MENU_SCENE)

func finish_battle(success: bool) -> void:
	if current_state == GameState.RESULT:
		return
	last_battle_success = success
	if last_battle_crystal_reward > 0:
		ProgressionManager.award_crystals(last_battle_crystal_reward)
	_set_state(GameState.RESULT)
	EventBus.battle_finished.emit(success)

func set_battle_result_stats(duration_seconds: float, kill_count: int, boss_defeated: bool, max_combo: int = 0, damage_dealt: float = 0.0, damage_received: float = 0.0, most_used_skill: String = "未使用") -> void:
	last_battle_duration_seconds = maxf(duration_seconds, 0.0)
	last_battle_kill_count = maxi(kill_count, 0)
	last_battle_boss_defeated = boss_defeated
	last_battle_max_combo = maxi(max_combo, 0)
	last_battle_damage_dealt = maxf(damage_dealt, 0.0)
	last_battle_damage_received = maxf(damage_received, 0.0)
	last_battle_most_used_skill = most_used_skill
	last_battle_crystal_reward = maxi(last_battle_kill_count + int(last_battle_damage_dealt / 100.0) + (60 if boss_defeated else 0), 0)

func set_paused(is_paused: bool) -> void:
	if is_paused:
		previous_state = current_state
		_set_state(GameState.PAUSED)
	else:
		_set_state(previous_state)
	get_tree().paused = is_paused

func toggle_pause() -> void:
	set_paused(not get_tree().paused)

func _reset_runtime_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	last_battle_duration_seconds = 0.0
	last_battle_kill_count = 0
	last_battle_boss_defeated = false
	last_battle_max_combo = 0
	last_battle_damage_dealt = 0.0
	last_battle_damage_received = 0.0
	last_battle_most_used_skill = "未使用"
	last_battle_crystal_reward = 0

func _change_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		var reason := "Scene path does not exist."
		push_error("GameManager scene change failed: %s (%s)" % [scene_path, reason])
		scene_change_failed.emit(scene_path, reason)
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		var reason := "change_scene_to_file returned error %s." % error
		push_error("GameManager scene change failed: %s (%s)" % [scene_path, reason])
		scene_change_failed.emit(scene_path, reason)

func _set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(GameState.keys()[new_state].to_lower())
