class_name DodgeTestHazard
extends Node2D

signal avoided

@onready var hitbox: Area2D = %HazardHitbox
@onready var warning: ColorRect = %Warning

func _ready() -> void:
	if hitbox.has_signal("hit_avoided"):
		hitbox.hit_avoided.connect(_on_hit_avoided)
	warning.visible = false

func trigger(duration: float = 0.12) -> void:
	warning.visible = true
	hitbox.activate(self, 15.0, 120.0, -1, duration, [StringName("dodge_test")])
	await get_tree().create_timer(duration, false, true).timeout
	warning.visible = false

func _on_hit_avoided(_hurtbox: Area2D, _context: Variant) -> void:
	avoided.emit()