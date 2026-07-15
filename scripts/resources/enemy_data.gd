class_name EnemyData
extends Resource

@export var enemy_id := StringName("enemy")
@export var display_name := "Enemy"
@export var max_health := 30.0
@export var move_speed := 60.0
@export var base_damage := 8.0
@export var attack_range := 56.0
@export var preferred_range := 160.0
@export var attack_interval := 1.3
@export var aim_time := 0.25
@export var experience_value := 6
@export var tags: Array[StringName] = []