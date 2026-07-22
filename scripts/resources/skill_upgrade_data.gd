class_name SkillUpgradeData
extends Resource

@export var upgrade_id := StringName("skill_upgrade")
@export var skill_id := StringName("skill")
@export var target_level := 2
@export var branch_id := StringName("")
@export var display_name := "技能强化"
@export_multiline var description := ""
@export var rarity := StringName("rare")
@export var weight := 8
@export var modifiers: Dictionary = {}
@export var tags: Array[StringName] = []