class_name BladeStorm
extends SkillEffect

@onready var hitbox: HitboxComponent = $Hitbox

var _life := 0.0
var _tick_timer := 0.0

func _execute() -> void:
	if caster == null or skill_data == null:
		finish()
		return
	var range_scale := get_stat(&"range_multiplier")
	scale = Vector2(range_scale, range_scale)
	_life = maxf(float(skill_data.get("duration")) * get_stat(&"duration_multiplier"), 0.2)
	_tick_timer = 0.0
	global_position = caster.global_position + Vector2(0, -28.0)

func _physics_process(delta: float) -> void:
	if caster == null or not is_instance_valid(caster):
		finish()
		return
	global_position = caster.global_position + Vector2(0, -28.0)
	rotation += delta * 8.0
	_life -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 0.12 if has_effect_tag(&"blade_barrage") else 0.2
		hitbox.activate(caster, float(skill_data.get("base_damage")) * get_stat(&"damage_multiplier"), 150.0, get_facing_direction(), 0.08, get_effect_tags())
		if has_effect_tag(&"pull"):
			_pull_enemies()
	if _life <= 0.0:
		finish()

func _pull_enemies() -> void:
	for hurtbox in hitbox.get_overlapping_areas():
		if hurtbox == null or StringName(str(hurtbox.get("faction"))) != &"enemy":
			continue
		var enemy := hurtbox.owner as CharacterBody2D
		if enemy != null:
			enemy.velocity.x = move_toward(enemy.velocity.x, global_position.direction_to(enemy.global_position).x * -100.0, 120.0)