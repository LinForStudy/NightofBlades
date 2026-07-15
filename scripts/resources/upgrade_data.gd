class_name UpgradeData
extends Resource

@export var upgrade_id := StringName("upgrade")
@export var display_name := "Upgrade"
@export_multiline var description := ""
@export var rarity := StringName("common")
@export var max_stacks := 1
@export var weight := 10
@export var effect_key := StringName("attack_damage_multiplier")
@export var effect_value := 0.1
@export var tags: Array[StringName] = []