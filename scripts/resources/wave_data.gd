class_name WaveData
extends Resource

@export var wave_id := StringName("wave")
@export var start_time := 0.0
@export var end_time := 120.0
@export var spawn_interval := 1.5
@export var max_alive := 8
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: Array[int] = []
@export var elite_chance := 0.0
@export var health_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var special_event := StringName("")