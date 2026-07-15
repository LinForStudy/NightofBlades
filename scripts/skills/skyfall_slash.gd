class_name SkyfallSlash
extends SkillEffect

@onready var hitbox: HitboxComponent = $Hitbox

var _life := 0.0

func _execute() -> void:
	if caster == null or skill_data == null:
		finish()
		return
	global_position = caster.global_position + Vector2(0, -24.0)
	_life = maxf(float(skill_data.get("duration")), 0.15)
	var range_scale := float(skill_data.get("range")) / 150.0
	scale = Vector2(range_scale, range_scale)
	caster.call("set_ultimate_invincible", true)
	hitbox.activate(caster, float(skill_data.get("base_damage")), 420.0, get_facing_direction(), _life, skill_data.get("tags"))

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		if caster != null:
			caster.call("set_ultimate_invincible", false)
		finish()