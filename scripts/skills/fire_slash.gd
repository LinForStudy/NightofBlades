class_name FireSlash
extends SkillEffect

@onready var hitbox: HitboxComponent = $Hitbox

var _direction := 1
var _life := 0.0
var _exploding := false

func _execute() -> void:
	if caster == null or skill_data == null:
		finish()
		return
	_direction = get_facing_direction()
	global_position = caster.global_position + Vector2(36.0 * float(_direction), -32.0)
	var range_scale := get_stat(&"range_multiplier")
	scale = Vector2(float(_direction) * range_scale, range_scale)
	_life = maxf(float(skill_data.get("duration")) * get_stat(&"duration_multiplier"), 0.2)
	var damage := float(skill_data.get("base_damage")) * get_stat(&"damage_multiplier")
	hitbox.activate(caster, damage, 220.0 * range_scale, _direction, _life, get_effect_tags())

func _physics_process(delta: float) -> void:
	global_position.x += float(_direction) * 360.0 * get_stat(&"range_multiplier") * delta
	_life -= delta
	if _life > 0.0:
		return
	if has_effect_tag(&"explosive") and not _exploding:
		_exploding = true
		_life = 0.10
		scale *= 1.5
		hitbox.activate(caster, float(skill_data.get("base_damage")) * get_stat(&"damage_multiplier"), 320.0, _direction, _life, get_effect_tags())
		return
	finish()