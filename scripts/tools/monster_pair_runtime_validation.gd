extends Node

const BOMBER_SCENE := preload("res://scenes/enemies/bomber.tscn")
const FLYING_EYE_SCENE := preload("res://scenes/enemies/flying_eye.tscn")
const HEALTH_SCRIPT := preload("res://scripts/combat/health_component.gd")
const HURTBOX_SCRIPT := preload("res://scripts/combat/hurtbox_component.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemies/enemy_controller.gd")
const FLYING_PROJECTILE_PATH := "res://scenes/enemies/flying_eye_projectile.tscn"

var _world: Node2D
var _entity_root: Node2D
var _projectile_root: Node2D
var _player: Node2D
var _player_health: HealthComponent
var _bomber_deaths := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_build_test_world()
	await get_tree().physics_frame
	await get_tree().physics_frame

	var bomber_valid: bool = await _validate_bomber()
	if not bomber_valid:
		return
	var flying_eye_valid: bool = await _validate_flying_eye()
	if not flying_eye_valid:
		return

	print("Bomber/FlyingEye focused runtime smoke passed.")
	get_tree().quit(0)

func _build_test_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_entity_root = Node2D.new()
	_entity_root.name = "EntityRoot"
	_world.add_child(_entity_root)

	_projectile_root = Node2D.new()
	_projectile_root.name = "ProjectileRoot"
	_world.add_child(_projectile_root)

	_player = Node2D.new()
	_player.name = "PlayerTarget"
	_player.position = Vector2(480.0, 360.0)
	_player.add_to_group("player")
	_entity_root.add_child(_player)

	_player_health = HEALTH_SCRIPT.new()
	_player_health.name = "HealthComponent"
	_player_health.max_health = 200.0
	_player.add_child(_player_health)

	var hurtbox := HURTBOX_SCRIPT.new() as HurtboxComponent
	hurtbox.name = "Hurtbox"
	hurtbox.position = Vector2(0.0, -22.0)
	hurtbox.faction = &"player"
	hurtbox.health_path = NodePath("../HealthComponent")
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	_player.add_child(hurtbox)

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	shape_node.shape = shape
	hurtbox.add_child(shape_node)

func _validate_bomber() -> bool:
	var bomber := BOMBER_SCENE.instantiate() as EnemyController
	if bomber == null:
		return _fail("Bomber scene did not instantiate as CharacterBody2D.")
	bomber.name = "BomberUnderTest"
	bomber.gravity = 0.0
	bomber.global_position = _player.global_position - Vector2(64.0, 48.0)
	bomber.enemy_died.connect(func(_enemy: Node) -> void: _bomber_deaths += 1)
	_entity_root.add_child(bomber)
	await get_tree().physics_frame

	var attack_shape_node := bomber.get_node_or_null("AttackHitbox/CollisionShape2D") as CollisionShape2D
	if attack_shape_node == null or not attack_shape_node.shape is CircleShape2D:
		return _fail("Bomber explosion hitbox must use CircleShape2D.")
	var explosion_shape := attack_shape_node.shape as CircleShape2D
	if explosion_shape.radius < 89.0:
		return _fail("Bomber explosion radius is smaller than the 90px combat contract.")

	var reached_windup: bool = await _wait_for_state(bomber, ENEMY_SCRIPT.EnemyState.WINDUP, 0.25)
	if not reached_windup:
		return _fail("Bomber did not enter WINDUP near the player.")
	var warning := bomber.get_node_or_null("Warning") as CanvasItem
	if warning == null or not warning.visible:
		return _fail("Bomber WINDUP warning is not visible.")

	var health_before := float(_player_health.get("current_health"))
	var died: bool = await _wait_for_state(bomber, ENEMY_SCRIPT.EnemyState.DEAD, 1.5)
	await get_tree().physics_frame
	var health_after := float(_player_health.get("current_health"))
	if not died or bomber.visible or _bomber_deaths != 1:
		return _fail("Bomber explosion did not complete one clean death transition.")
	if health_after >= health_before:
		return _fail("Bomber circular explosion did not damage the diagonal target inside 90px.")

	bomber.queue_free()
	await get_tree().process_frame
	_player_health.call("reset_health")
	return true

func _validate_flying_eye() -> bool:
	var flying := FLYING_EYE_SCENE.instantiate() as EnemyController
	if flying == null:
		return _fail("FlyingEye scene did not instantiate as CharacterBody2D.")
	flying.name = "FlyingEyeUnderTest"
	flying.global_position = _player.global_position + Vector2(120.0, -92.0)
	_entity_root.add_child(flying)
	await get_tree().physics_frame

	var configured_projectile: PackedScene = flying.get("projectile_scene") as PackedScene
	if configured_projectile == null or configured_projectile.resource_path != FLYING_PROJECTILE_PATH:
		return _fail("FlyingEye is not configured with its custom projectile scene.")

	var reached_aim: bool = await _wait_for_state(flying, ENEMY_SCRIPT.EnemyState.AIM, 0.35)
	if not reached_aim:
		return _fail("FlyingEye did not enter AIM inside attack range.")
	var warning := flying.get_node_or_null("Warning") as CanvasItem
	if warning == null or not warning.visible:
		return _fail("FlyingEye AIM warning is not visible.")

	var projectile: Node = await _wait_for_projectile(0.75)
	if projectile == null:
		return _fail("FlyingEye AIM did not spawn a projectile under World/ProjectileRoot.")
	if projectile.scene_file_path != FLYING_PROJECTILE_PATH:
		return _fail("FlyingEye spawned the wrong projectile scene: %s" % projectile.scene_file_path)
	if int(projectile.get("animation_frames")) < 4:
		return _fail("FlyingEye projectile animation is not configured for four frames.")

	var flying_health := flying.get_node_or_null("HealthComponent")
	if flying_health == null:
		return _fail("FlyingEye is missing HealthComponent.")
	flying_health.call("apply_damage", {
		"final_damage": 1.0,
		"knockback": Vector2(160.0, -20.0),
		"hit_position": flying.global_position,
		"source": _player,
		"tags": [StringName("attack_light")]
	})
	if int(flying.get("current_state")) != ENEMY_SCRIPT.EnemyState.RETREAT:
		return _fail("Player melee damage did not put FlyingEye into RETREAT.")
	await get_tree().physics_frame
	if flying.velocity.length_squared() <= 1.0:
		return _fail("FlyingEye RETREAT did not apply recoil velocity.")

	flying.queue_free()
	return true

func _wait_for_state(enemy: Node, expected_state: int, timeout_seconds: float) -> bool:
	var remaining := timeout_seconds
	while remaining > 0.0:
		if int(enemy.get("current_state")) == expected_state:
			return true
		await get_tree().physics_frame
		remaining -= 1.0 / 60.0
	return int(enemy.get("current_state")) == expected_state

func _wait_for_projectile(timeout_seconds: float) -> Node:
	var remaining := timeout_seconds
	while remaining > 0.0:
		if _projectile_root.get_child_count() > 0:
			return _projectile_root.get_child(0)
		await get_tree().physics_frame
		remaining -= 1.0 / 60.0
	return null

func _fail(message: String) -> bool:
	push_error(message)
	get_tree().quit(1)
	return false
