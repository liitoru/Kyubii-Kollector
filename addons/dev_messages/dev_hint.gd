# KCDT - Kyubii Collector Development Tools
@tool
@icon("res://addons/dev_messages/icons/dev_message.svg")
class_name DevHint
extends Resource
## One "input hint" row for a DevMessage.
## Set `action` to follow an InputMap action: the glyph then switches by itself
## between keyboard/mouse and gamepad (Xbox / PlayStation / Nintendo) depending
## on what the player last used. Leave `action` empty to pick a glyph by hand.

## Append-only: new entries go at the end so saved scenes keep working.
enum Glyph {
	LEFT_STICK, RIGHT_STICK, LEFT_STICK_CLICK, RIGHT_STICK_CLICK, DPAD,
	BUTTON_A, BUTTON_B, BUTTON_X, BUTTON_Y,
	LEFT_BUMPER, RIGHT_BUMPER, LEFT_TRIGGER, RIGHT_TRIGGER,
	VR_TRIGGER, VR_GRIP,
	MOUSE_LEFT, MOUSE_RIGHT, MOUSE_WHEEL,
	KEY, CUSTOM,
	PS_CROSS, PS_CIRCLE, PS_SQUARE, PS_TRIANGLE,
	PILL, ROUND, KEY_WIDE,
	DPAD_UP, DPAD_DOWN, DPAD_LEFT, DPAD_RIGHT,
}

## InputMap action to show (e.g. "jump", "move_forward"). Pick from the list or type it.
@export var action: StringName = &""
## More actions shown next to the first one on keyboard (e.g. move_left, move_back,
## move_right -> W A S D). On gamepad, identical glyphs are merged (one stick).
@export var extra_actions: PackedStringArray = PackedStringArray()
@export var description: String = "Move"

@export_group("Manual glyph (used when action is empty)")
@export var glyph: Glyph = Glyph.LEFT_STICK
## Text on the key / pill / round button.
@export var key_text: String = "E"
## Any texture/.svg (only used when glyph = CUSTOM).
@export var custom_icon: Texture2D


func _validate_property(property: Dictionary) -> void:
	if str(property["name"]) == "action":
		property["hint"] = PROPERTY_HINT_ENUM_SUGGESTION
		property["hint_string"] = ",".join(_project_actions())


static func _project_actions() -> PackedStringArray:
	var out := PackedStringArray()
	for p in ProjectSettings.get_property_list():
		var n: String = p["name"]
		if n.begins_with("input/"):
			out.append(n.trim_prefix("input/"))
	return out
