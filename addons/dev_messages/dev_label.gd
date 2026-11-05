# KCDT - Kyubii Collector Development Tools
@tool
@icon("res://addons/dev_messages/icons/dev_label.svg")
class_name DevLabel
extends Label3D
const Presets := preload("res://addons/dev_messages/dev_presets.gd")
## A quick floating text note. Each label has its own color (preset or custom);
## DEVSETTINGS only decides if labels are shown and gives the fallback color.
## Note: this node controls its own "visible" flag (it only hides itself
## when DEVSETTINGS says so, and restores itself afterwards).

@export var category: String = "General"
## Preset color (DEFAULT = DEVSETTINGS label color).
@export var preset: Presets.Preset = Presets.Preset.DEFAULT
## Tick to use `color` for this label only.
@export var override_color: bool = false
@export var color: Color = Color("#FFD54F")

var _style_key: int = 0
var _hidden_by_us: bool = false


func _init() -> void:
	text = "Dev note"
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	font_size = 48
	pixel_size = 0.004
	outline_size = 12


func _process(_delta: float) -> void:
	var s := DevSettings.find(self)
	var active: bool
	if s:
		active = s.is_label_visible(category)
	else:
		active = Engine.is_editor_hint() or OS.is_debug_build()

	if not active and visible:
		visible = false
		_hidden_by_us = true
	elif active and _hidden_by_us:
		visible = true
		_hidden_by_us = false

	var key := hash([override_color, color, preset, s.style_hash() if s else 0])
	if key == _style_key:
		return
	_style_key = key
	if override_color:
		modulate = color
	elif preset != Presets.Preset.DEFAULT:
		modulate = Presets.color_of(preset)
	elif s:
		modulate = s.label_color
	if s:
		outline_modulate = s.label_outline_color
		no_depth_test = s.always_on_top
