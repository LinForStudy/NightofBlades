extends Node

func _ready() -> void:
	call_deferred("_enter_main_menu")

func _enter_main_menu() -> void:
	GameManager.go_to_main_menu()