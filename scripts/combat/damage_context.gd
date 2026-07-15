class_name DamageContext
extends RefCounted

static func create(source_node: Node, damage: float, knockback_vector: Vector2, position: Vector2, attack_tags: Array = []) -> Dictionary:
	return {
		"source": source_node,
		"target": null,
		"base_damage": damage,
		"final_damage": damage,
		"damage_type": StringName("physical"),
		"tags": attack_tags,
		"is_critical": false,
		"knockback": knockback_vector,
		"hit_position": position,
		"hitstun": 0.0
	}