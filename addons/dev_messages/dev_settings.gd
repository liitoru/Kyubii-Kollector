# KCDT - Kyubii Collector Development Tools
@tool
@icon("res://addons/dev_messages/icons/dev_settings.svg")
class_name DevSettings
extends Node
## Put ONE of these (named DEVSETTINGS) in a scene. Every DevMessage and
## DevLabel in the scene reads its look and behaviour from here.

enum RevealMode { ALWAYS_OPEN, PROXIMITY, TOGGLE }
enum DeviceChoice { AUTO, KEYBOARD, GAMEPAD }
enum PreviewDevice { KEYBOARD, GAMEPAD }
enum StyleChoice { AUTO, XBOX, PLAYSTATION, NINTENDO }

@export_group("Visibility")
@export var messages_enabled: bool = true
@export var labels_enabled: bool = true
## Show notes inside the editor viewport.
@export var show_in_editor: bool = true
## Hide everything in non-debug (release) exports.
@export var hide_in_release_builds: bool = true
## Categories listed here are hidden (e.g. "Audio", "Level Design").
@export var hidden_categories: PackedStringArray = PackedStringArray()

@export_group("Reveal (in game)")
## ALWAYS_OPEN: panels always shown. PROXIMITY: open when camera is near.
## TOGGLE: only open via toggle key / DevMessage.toggle().
@export var reveal_mode: RevealMode = RevealMode.PROXIMITY
@export var reveal_distance: float = 3.0
## Press to open/close ALL messages at runtime (any mode). KEY_NONE disables.
@export var toggle_key: Key = KEY_F1

@export_group("Message Style (fallback)")
## Used only by DevMessages that keep preset DEFAULT and no color override.
## Every DevMessage can have its own preset / color / icon.
@export var panel_color: Color = Color("#2196F3")
@export var text_color: Color = Color.WHITE
@export var icon_color: Color = Color("#2196F3")
@export var panel_width: float = 0.9
@export var title_size: int = 40
@export var body_size: int = 28
## Draw notes through walls/geometry.
@export var always_on_top: bool = false

@export_group("Outline")
## Border around the panel, to separate it from the scene behind it.
@export var outline_enabled: bool = true
@export var outline_color: Color = Color.WHITE
@export var outline_width: float = 0.012

@export_group("Icon")
## Project-wide icon for every message (drop any .svg/.png). Empty = envelope.
## A message's own custom_icon overrides this.
@export var default_icon: Texture2D

@export_group("Input Hints")
## Size in meters of the stick/button/key glyphs.
@export var glyph_size: float = 0.08
@export var hint_text_size: int = 26
## AUTO: glyphs follow the last input the player used (keyboard/mouse or gamepad).
@export var input_device: DeviceChoice = DeviceChoice.AUTO
## What AUTO shows inside the editor, so you can preview both.
@export var editor_preview_device: PreviewDevice = PreviewDevice.KEYBOARD
## AUTO detects PlayStation / Nintendo / Xbox from the controller's name.
@export var gamepad_style: StyleChoice = StyleChoice.AUTO

@export_group("Label Style (fallback)")
@export var label_color: Color = Color("#FFD54F")
@export var label_outline_color: Color = Color.BLACK

var all_open: bool = false
var _last_device: int = DevInput.Device.KEYBOARD
var _auto_style: int = DevInput.PadStyle.XBOX


static func find(node: Node) -> DevSettings:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("dev_settings") as DevSettings


static func get_camera(node: Node) -> Camera3D:
	if Engine.is_editor_hint():
		if Engine.has_singleton("EditorInterface"):
			var ei = Engine.get_singleton("EditorInterface")
			var vp = ei.get_editor_viewport_3d(0)
			if vp:
				return vp.get_camera_3d()
		return null
	return node.get_viewport().get_camera_3d()


func _enter_tree() -> void:
	add_to_group("dev_settings")


func _exit_tree() -> void:
	remove_from_group("dev_settings")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var pads := Input.get_connected_joypads()
	if pads.size() > 0:
		_auto_style = _detect_style(pads[0])
	Input.joy_connection_changed.connect(
		func(device: int, connected: bool) -> void:
			if connected:
				_auto_style = _detect_style(device))


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey or (event is InputEventMouseButton and event.pressed):
		_last_device = DevInput.Device.KEYBOARD
	elif event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_last_device = DevInput.Device.GAMEPAD
		_auto_style = _detect_style(event.device)


func _detect_style(device: int) -> int:
	var n := Input.get_joy_name(device).to_lower()
	for k in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if n.contains(k):
			return DevInput.PadStyle.PLAYSTATION
	for k in ["nintendo", "switch", "joy-con", "pro controller"]:
		if n.contains(k):
			return DevInput.PadStyle.NINTENDO
	return DevInput.PadStyle.XBOX


## Which device's glyphs to show right now (DevInput.Device).
func get_device() -> int:
	match input_device:
		DeviceChoice.KEYBOARD:
			return DevInput.Device.KEYBOARD
		DeviceChoice.GAMEPAD:
			return DevInput.Device.GAMEPAD
	if Engine.is_editor_hint():
		return DevInput.Device.GAMEPAD if editor_preview_device == PreviewDevice.GAMEPAD \
			else DevInput.Device.KEYBOARD
	return _last_device


## Which gamepad glyph style to show (DevInput.PadStyle).
func get_pad_style() -> int:
	match gamepad_style:
		StyleChoice.XBOX:
			return DevInput.PadStyle.XBOX
		StyleChoice.PLAYSTATION:
			return DevInput.PadStyle.PLAYSTATION
		StyleChoice.NINTENDO:
			return DevInput.PadStyle.NINTENDO
	return _auto_style


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or toggle_key == KEY_NONE:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		all_open = not all_open


func _base_active() -> bool:
	if Engine.is_editor_hint():
		return show_in_editor
	if hide_in_release_builds and not OS.is_debug_build():
		return false
	return true


func is_message_visible(category: String) -> bool:
	return messages_enabled and _base_active() and not hidden_categories.has(category)


func is_label_visible(category: String) -> bool:
	return labels_enabled and _base_active() and not hidden_categories.has(category)


func style_hash() -> int:
	return hash([panel_color, text_color, icon_color, panel_width, title_size,
		body_size, always_on_top, label_color, label_outline_color,
		outline_enabled, outline_color, outline_width, glyph_size, hint_text_size,
		default_icon.get_instance_id() if default_icon else 0])


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if is_inside_tree() and get_tree().get_nodes_in_group("dev_settings").size() > 1:
		w.append("More than one DevSettings node is in the scene. Only the first one is used.")
	return w
