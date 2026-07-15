class_name UltimateData
extends Resource

@export var ultimate_id := StringName("skyfall_slash")
@export var display_name := "Skyfall Slash"
@export_multiline var description := ""
@export var effect_scene: PackedScene
@export var energy_cost := 100.0
@export var base_damage := 200.0
@export var duration := 0.35
@export var range := 150.0
@export var tags: Array[StringName] = []