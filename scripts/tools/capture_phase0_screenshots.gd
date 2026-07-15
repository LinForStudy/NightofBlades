extends Node

const CONTROLLER_SCRIPT := preload("res://scripts/tools/phase0_capture_controller.gd")

func _ready() -> void:
	var controller := Node.new()
	controller.name = "Phase0CaptureController"
	controller.set_script(CONTROLLER_SCRIPT)
	get_tree().root.add_child.call_deferred(controller)