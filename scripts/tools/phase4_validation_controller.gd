extends Node

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

var _dead_count := 0

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

	var root := scene.get_node_or_null("World/EntityRoot")
	var projectile_root := scene.get_node_or_null("World/ProjectileRoot")
	if root == null or projectile_root == null:
		push_error("BattleScene missing enemy or projectile roots.")
		get_tree().quit(1)
		return

	var player := root.get_node_or_null("Player")
	if player == null or not player.is_in_group("player"):
		push_error("Player is missing or not in player group.")
		get_tree().quit(1)
		return

	var enemies := [
		root.get_node_or_null("RiftGrunt"),
		root.get_node_or_null("Archer"),
		root.get_node_or_null("Bomber"),
		root.get_node_or_null("FlyingEye")
	]

	for enemy in enemies:
		if enemy == null:
			push_error("Phase 4 validation missing an enemy instance.")
			get_tree().quit(1)
			return
		if not enemy.has_signal("enemy_died"):
			push_error("Enemy is missing enemy_died signal: %s" % enemy.name)
			get_tree().quit(1)
			return
		if enemy.get("enemy_data") == null:
			push_error("Enemy is missing enemy_data: %s" % enemy.name)
			get_tree().quit(1)
			return
		if enemy.get_node_or_null("HealthComponent") == null or enemy.get_node_or_null("Hurtbox") == null:
			push_error("Enemy is missing HealthComponent or Hurtbox: %s" % enemy.name)
			get_tree().quit(1)
			return
		enemy.enemy_died.connect(func(_enemy: Node): _dead_count += 1)

	var bomber := root.get_node_or_null("Bomber")
	var health := bomber.get_node_or_null("HealthComponent")
	health.apply_damage({"final_damage": 999.0, "knockback": Vector2.ZERO, "hit_position": bomber.global_position, "source": self})
	await get_tree().process_frame

	if bomber.visible or _dead_count < 1:
		push_error("Enemy death did not disable the enemy or emit enemy_died.")
		get_tree().quit(1)
		return

	get_tree().quit(0)