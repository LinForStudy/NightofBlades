class_name SkillData
extends Resource

@export var skill_id := StringName("skill")
@export var display_name := "Skill"
@export_multiline var description := ""
@export var skill_scene: PackedScene
@export var base_cooldown := 5.0
@export var cast_time := 0.0
@export var recovery_time := 0.0
@export var base_damage := 10.0
@export var duration := 0.2
@export var range := 160.0
@export var max_level := 5
@export var tags: Array[StringName] = []