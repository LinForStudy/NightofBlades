extends Node

const CONTROLLER_SCRIPT := preload("res://scripts/tools/battle_hud_runtime_validation.gd")

func _ready() -> void:
	var controller := Node.new()
	controller.name = "BattleHudRuntimeValidationController"
	controller.set_script(CONTROLLER_SCRIPT)
	get_tree().root.add_child.call_deferred(controller)