class_name HealthComponent
extends Node

signal damaged(amount: float, context: Variant)
signal health_changed(current: float, maximum: float)
signal depleted(context: Variant)

@export var max_health := 100.0

var current_health := 100.0

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func apply_damage(context: Variant) -> void:
	if current_health <= 0.0:
		return

	var amount := maxf(float(context.get("final_damage", 0.0)), 1.0)
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount, context)
	health_changed.emit(current_health, max_health)
	if is_zero_approx(current_health):
		depleted.emit(context)

func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)