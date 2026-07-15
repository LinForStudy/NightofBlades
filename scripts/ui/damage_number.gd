class_name DamageNumber
extends Label

@export var float_speed := 42.0
@export var lifetime := 0.55

var _timer := 0.0

func setup(amount: float, world_position: Vector2) -> void:
	text = str(int(round(amount)))
	global_position = world_position
	_timer = lifetime

func _process(delta: float) -> void:
	_timer -= delta
	position.y -= float_speed * delta
	modulate.a = clampf(_timer / lifetime, 0.0, 1.0)
	if _timer <= 0.0:
		queue_free()