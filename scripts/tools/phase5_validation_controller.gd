extends Node

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

var _spawned_count := 0
var _recycled_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(BATTLE_SCENE)
	if err != OK:
		push_error("Failed to load battle scene: %s" % err)
		get_tree().quit(1)
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene == null:
		push_error("BattleScene did not become current_scene.")
		get_tree().quit(1)
		return

	var manager: Node = scene.get_node_or_null("Managers/WaveManager")
	if manager == null:
		push_error("BattleScene is missing Managers/WaveManager.")
		get_tree().quit(1)
		return
	if not manager.has_method("force_spawn_once") or not manager.has_method("get_alive_count"):
		push_error("WaveManager is missing smoke-test methods.")
		get_tree().quit(1)
		return
	if manager.has_signal("enemy_spawned"):
		manager.enemy_spawned.connect(func(_enemy: Node): _spawned_count += 1)
	if manager.has_signal("enemy_recycled"):
		manager.enemy_recycled.connect(func(_enemy: Node): _recycled_count += 1)

	manager.stop_waves()
	var enemy: Node = manager.force_spawn_once() as Node
	if enemy != null and not enemy.is_node_ready():
		await enemy.ready
	await get_tree().process_frame
	if enemy == null or _spawned_count < 1 or manager.get_alive_count() < 1:
		push_error("WaveManager did not spawn an enemy on demand.")
		get_tree().quit(1)
		return

	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health == null:
		push_error("Spawned enemy is missing HealthComponent.")
		get_tree().quit(1)
		return
	health.apply_damage({"final_damage": 999.0, "knockback": Vector2.ZERO, "hit_position": enemy.global_position, "source": self})
	await get_tree().process_frame

	var current_health: Variant = health.get("current_health")
	var enemy_visible: bool = enemy.visible if is_instance_valid(enemy) else false
	var enemy_parent: Node = enemy.get_parent() if is_instance_valid(enemy) else null
	var alive_count: int = manager.get_alive_count()
	if _recycled_count < 1 or enemy_parent != null:
		push_error("WaveManager did not recycle spawned enemy. alive=%s recycled=%s visible=%s parent=%s health=%s" % [alive_count, _recycled_count, enemy_visible, enemy_parent, current_health])
		get_tree().quit(1)
		return

	get_tree().quit(0)