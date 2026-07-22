class_name UpgradeChoiceCard
extends Button

const FIRE_SLASH_ICON: Texture2D = preload("res://assets/ui/hud/icons/icon_skill_fire_slash.png")
const LIGHTNING_DASH_ICON: Texture2D = preload("res://assets/ui/hud/icons/icon_skill_lightning_dash.png")
const BLADE_STORM_ICON: Texture2D = preload("res://assets/ui/hud/icons/icon_skill_blade_storm.png")
const ULTIMATE_ICON: Texture2D = preload("res://assets/ui/hud/icons/icon_ultimate_rift_eye.png")
const RELIC_ICON: Texture2D = preload("res://assets/ui/hud/icons/icon_equipment_relic.png")

const ACTIVE_ACCENT := Color(0.82, 0.61, 0.24, 1.0)
const EVOLUTION_ACCENT := Color(0.34, 0.55, 0.75, 1.0)
const PASSIVE_ACCENT := Color(0.34, 0.68, 0.61, 1.0)
const ATTACK_ACCENT := Color(0.66, 0.34, 0.34, 1.0)
const RIFT_ACCENT := Color(0.60, 0.32, 0.72, 1.0)

@onready var category_label: Label = %CategoryLabel
@onready var shortcut_label: Label = %ShortcutLabel
@onready var icon_frame: PanelContainer = %IconFrame
@onready var icon_rect: TextureRect = %UpgradeIcon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var stat_change_label: Label = %StatChangeLabel
@onready var description_label: Label = %DescriptionLabel
@onready var shortcut_badge: PanelContainer = %ShortcutBadge

var _accent := ACTIVE_ACCENT

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(_on_mouse_entered)

func present_upgrade(upgrade: Resource, current_progress: int, max_progress: int, shortcut_index: int) -> void:
	if upgrade == null:
		visible = false
		disabled = true
		return
	visible = true
	disabled = false
	text = ""
	shortcut_label.text = "[%d]" % shortcut_index
	name_label.text = str(upgrade.get("display_name"))
	description_label.text = str(upgrade.get("description"))
	icon_rect.texture = _resolve_icon(upgrade)
	tooltip_text = "%s\n%s" % [name_label.text, description_label.text]
	if upgrade is SkillUpgradeData:
		_present_skill_upgrade(upgrade as SkillUpgradeData, current_progress)
	else:
		_present_passive_upgrade(upgrade, current_progress, max_progress)
	_apply_accent(_accent)

func _present_skill_upgrade(upgrade: SkillUpgradeData, current_progress: int) -> void:
	var has_branch := not String(upgrade.branch_id).is_empty()
	category_label.text = "技能进化" if has_branch else "主动强化"
	_accent = EVOLUTION_ACCENT if has_branch else ACTIVE_ACCENT
	level_label.text = "当前 Lv.%d  →  Lv.%d" % [current_progress, upgrade.target_level]
	stat_change_label.text = _format_skill_change(upgrade.modifiers)

func _present_passive_upgrade(upgrade: Resource, current_progress: int, max_progress: int) -> void:
	var primary_tag := _get_primary_tag(upgrade)
	match primary_tag:
		"attack":
			category_label.text = "攻击被动"
			_accent = ATTACK_ACCENT
		"action":
			category_label.text = "行动被动"
			_accent = EVOLUTION_ACCENT
		"ultimate":
			category_label.text = "裂隙被动"
			_accent = RIFT_ACCENT
		_:
			category_label.text = "生存被动"
			_accent = PASSIVE_ACCENT
	level_label.text = "当前 Lv.%d" % current_progress
	stat_change_label.text = "%s  ·  层数 %d → %d/%d" % [
		_format_passive_change(StringName(str(upgrade.get("effect_key"))), float(upgrade.get("effect_value"))),
		current_progress,
		mini(current_progress + 1, max_progress),
		max_progress,
	]

func _resolve_icon(upgrade: Resource) -> Texture2D:
	if upgrade is SkillUpgradeData:
		match StringName(str(upgrade.get("skill_id"))):
			&"fire_slash":
				return FIRE_SLASH_ICON
			&"lightning_dash":
				return LIGHTNING_DASH_ICON
			&"blade_storm":
				return BLADE_STORM_ICON
	var primary_tag := _get_primary_tag(upgrade)
	match primary_tag:
		"attack":
			return FIRE_SLASH_ICON
		"action":
			return LIGHTNING_DASH_ICON
		"ultimate":
			return ULTIMATE_ICON
	return RELIC_ICON

func _get_primary_tag(upgrade: Resource) -> String:
	var tags_variant: Variant = upgrade.get("tags")
	if tags_variant is Array:
		for tag in tags_variant:
			var tag_text := str(tag)
			if tag_text in ["attack", "action", "survival", "ultimate"]:
				return tag_text
	var effect_key := str(upgrade.get("effect_key"))
	if effect_key.contains("health"):
		return "survival"
	if effect_key.contains("ultimate"):
		return "ultimate"
	if effect_key.contains("move") or effect_key.contains("dodge") or effect_key.contains("window"):
		return "action"
	return "attack"

func _format_skill_change(modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	if modifiers.has("damage_bonus"):
		parts.append("伤害 +%d%%" % roundi(float(modifiers["damage_bonus"]) * 100.0))
	if modifiers.has("range_bonus"):
		parts.append("范围 +%d%%" % roundi(float(modifiers["range_bonus"]) * 100.0))
	if modifiers.has("duration_bonus"):
		parts.append("持续 +%d%%" % roundi(float(modifiers["duration_bonus"]) * 100.0))
	if modifiers.has("cooldown_reduction"):
		parts.append("冷却 -%d%%" % roundi(float(modifiers["cooldown_reduction"]) * 100.0))
	if modifiers.has("add_tags"):
		parts.append("获得进化效果")
	if parts.is_empty():
		return "获得新的技能效果"
	return "  ·  ".join(parts)

func _format_passive_change(effect_key: StringName, value: float) -> String:
	match effect_key:
		&"attack_damage_multiplier":
			return "攻击伤害 +%d%%" % roundi(value * 100.0)
		&"attack_speed_multiplier":
			return "攻击速度 +%d%%" % roundi(value * 100.0)
		&"critical_chance_bonus":
			return "暴击率 +%d%%" % roundi(value * 100.0)
		&"move_speed_bonus":
			return "移动速度 +%d" % roundi(value)
		&"max_health_bonus":
			return "最大生命 +%d" % roundi(value)
		&"dodge_cooldown_reduction":
			return "闪避冷却 -%.2f秒" % value
		&"perfect_dodge_window_bonus":
			return "完美闪避 +%.3f秒" % value
		&"ultimate_gain_multiplier":
			return "能量获取 +%d%%" % roundi(value * 100.0)
	return "效果 +%s" % value

func _apply_accent(accent: Color) -> void:
	category_label.add_theme_color_override("font_color", accent.lightened(0.20))
	stat_change_label.add_theme_color_override("font_color", accent.lightened(0.28))
	shortcut_label.add_theme_color_override("font_color", accent.lightened(0.30))
	_override_button_border(&"normal", accent.darkened(0.22), 2)
	_override_button_border(&"hover", accent.lightened(0.08), 2)
	_override_button_border(&"pressed", accent.lightened(0.16), 3)
	_override_button_border(&"focus", accent.lightened(0.18), 3)
	_override_panel_border(shortcut_badge, accent.darkened(0.02), 1)
	_override_panel_border(icon_frame, accent.darkened(0.08), 1)

func _override_button_border(style_name: StringName, color: Color, width: int) -> void:
	var source := get_theme_stylebox(style_name)
	if not source is StyleBoxFlat:
		return
	var style := source.duplicate() as StyleBoxFlat
	style.border_color = color
	_set_border_width(style, width)
	add_theme_stylebox_override(style_name, style)

func _override_panel_border(panel: PanelContainer, color: Color, width: int) -> void:
	var source := panel.get_theme_stylebox(&"panel")
	if not source is StyleBoxFlat:
		return
	var style := source.duplicate() as StyleBoxFlat
	style.border_color = color
	_set_border_width(style, width)
	panel.add_theme_stylebox_override(&"panel", style)

func _set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width

func _on_mouse_entered() -> void:
	if not disabled:
		grab_focus()
