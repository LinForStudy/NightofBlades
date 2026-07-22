class_name EquipmentPickupPrompt
extends Node2D

@export var display_name := ""
@export var icon_texture: Texture2D
@export var quality_color := Color(0.48, 0.3, 0.68, 1.0)

@onready var icon_frame: PanelContainer = %IconFrame
@onready var icon: TextureRect = %EquipmentIcon
@onready var name_label: Label = %EquipmentName
@onready var pickup_prompt: PanelContainer = %PickupPrompt

func _ready() -> void:
	_apply_display()
	set_pickup_active(false)

func set_item_display(item_name: String, item_icon: Texture2D, item_quality_color: Color) -> void:
	display_name = item_name
	icon_texture = item_icon
	quality_color = item_quality_color
	if is_node_ready():
		_apply_display()

func set_pickup_active(is_active: bool) -> void:
	name_label.visible = is_active
	pickup_prompt.visible = is_active

func _apply_display() -> void:
	name_label.text = display_name
	if icon_texture != null:
		icon.texture = icon_texture
	var frame_style := icon_frame.get_theme_stylebox("panel")
	if frame_style is StyleBoxFlat:
		var quality_style := frame_style.duplicate() as StyleBoxFlat
		quality_style.border_color = quality_color
		icon_frame.add_theme_stylebox_override("panel", quality_style)