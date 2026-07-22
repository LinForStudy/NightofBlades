class_name EnemyWarningVisual
extends Node2D

@export var radius := 90.0
@export var fill_color := Color(0.72, 0.08, 0.18, 0.13)
@export var ring_color := Color(1.0, 0.22, 0.22, 0.86)
@export var pulse_speed := 7.0
@export_range(12, 64, 4) var segments := 32

var _elapsed := 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()

func _draw() -> void:
	var pulse := (sin(_elapsed * pulse_speed) + 1.0) * 0.5
	var inner_color := fill_color
	inner_color.a *= 0.72 + pulse * 0.28
	var outline_color := ring_color.lightened(pulse * 0.12)
	outline_color.a *= 0.78 + pulse * 0.22
	var current_radius := radius - pulse * 3.0
	draw_circle(Vector2.ZERO, current_radius, inner_color, true, -1.0, false)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, segments, outline_color, 3.0, false)
	var tick_length := 8.0 + pulse * 3.0
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for direction in directions:
		var tick_start := direction * (current_radius - tick_length)
		var tick_end := direction * (current_radius + 2.0)
		draw_line(tick_start, tick_end, outline_color, 3.0, false)
