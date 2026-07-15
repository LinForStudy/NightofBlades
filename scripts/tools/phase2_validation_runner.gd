extends Node

const CONTROLLER_SCRIPT := preload("res://scripts/tools/phase2_validation_controller.gd")

func _ready() -> void:
	var controller := Node.new()
	controller.name = "Phase2ValidationController"
	controller.set_script(CONTROLLER_SCRIPT)
	get_tree().root.add_child.call_deferred(controller)