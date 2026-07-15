class_name LightningDash
extends SkillEffect

@onready var hitbox: HitboxComponent = $Hitbox

var _life := 0.0

func _execute() -> void:
	if caster == null or skill_data == null:
		finish()
		return
	var direction := Vector2(float(get_facing_direction()), 0.0)
	var distance := float(skill_data.get("range")) * get_stat(&"range_multiplier")
	global_position = caster.global_position + Vector2(direction.x * distance * 0.5, -30.0)
	scale = Vector2(direction.x * get_stat(&"range_multiplier"), get_stat(&"range_multiplier"))
	_life = maxf(float(skill_data.get("duration")) * get_stat(&"duration_multiplier"), 0.15)
	var damage := float(skill_data.get("base_damage")) * get_stat(&"damage_multiplier")
	if has_effect_tag(&"afterimage"):
		_life += 0.45
	hitbox.activate(caster, damage, 260.0, int(direction.x), _life, get_effect_tags())
	if caster.has_method("perform_skill_dash"):
		caster.perform_skill_dash(direction, distance, minf(_life, 0.22))

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		finish()