# KCDT - Kyubii Collector Development Tools
@tool
class_name DevInput
extends RefCounted
## Turns an InputMap action into the glyph(s) for the device the player is
## currently using (keyboard/mouse or gamepad), in Xbox / PlayStation / Nintendo style.

enum Device { KEYBOARD, GAMEPAD }
enum PadStyle { XBOX, PLAYSTATION, NINTENDO }

static var _cache: Dictionary = {}
static var _stamp: int = -1


static func _e(glyph: int, text: String = "", icon: Texture2D = null) -> Dictionary:
	return {"glyph": glyph, "text": text, "icon": icon}


## Returns an Array of entries {glyph:int, text:String, icon:Texture2D}.
static func resolve_hint(hint: DevHint, device: int, style: int) -> Array:
	if hint.action == &"":
		var g: int = hint.glyph
		var t := ""
		if g == DevHint.Glyph.KEY or g == DevHint.Glyph.KEY_WIDE \
				or g == DevHint.Glyph.PILL or g == DevHint.Glyph.ROUND:
			t = hint.key_text
		if g == DevHint.Glyph.KEY and t.length() > 2:
			g = DevHint.Glyph.KEY_WIDE
		return [_e(g, t, hint.custom_icon)]

	var names: Array = [String(hint.action)]
	for a in hint.extra_actions:
		names.append(a)
	var out: Array = []
	for a in names:
		var e := _entry_for_action(String(a), device, style)
		var dup := false
		for o in out:
			if o["glyph"] == e["glyph"] and o["text"] == e["text"]:
				dup = true
				break
		if not dup:
			out.append(e)
	return out


@warning_ignore("integer_division")
static func _entry_for_action(action: String, device: int, style: int) -> Dictionary:
	var st := Engine.get_process_frames() / 60
	if st != _stamp:
		_stamp = st
		_cache.clear()
	var ck := "%s|%d|%d" % [action, device, style]
	if _cache.has(ck):
		return _cache[ck]

	var result := _e(DevHint.Glyph.KEY, "?")
	for ev in _events(action):
		if device == Device.KEYBOARD:
			if ev is InputEventKey:
				result = _key_entry(ev)
				break
			if ev is InputEventMouseButton:
				result = _mouse_entry(ev)
				break
		else:
			if ev is InputEventJoypadButton:
				result = _joy_button_entry(ev.button_index, style)
				break
			if ev is InputEventJoypadMotion:
				result = _joy_axis_entry(ev.axis, style)
				break
	_cache[ck] = result
	return result


static func _events(action: String) -> Array:
	if InputMap.has_action(action):
		return InputMap.action_get_events(action)
	# In the editor the project's actions live in ProjectSettings.
	var key := "input/" + action
	if ProjectSettings.has_setting(key):
		var d = ProjectSettings.get_setting(key)
		if d is Dictionary and d.has("events"):
			return d["events"]
	return []


static func _short(t: String) -> String:
	match t:
		"Escape": return "Esc"
		"Control": return "Ctrl"
		"Backspace": return "Bksp"
		"Page Up": return "PgUp"
		"Page Down": return "PgDn"
		"Delete": return "Del"
		"Insert": return "Ins"
		"CapsLock", "Capslock": return "Caps"
	return t


static func _key_entry(ev: InputEventKey) -> Dictionary:
	var kc: int = ev.keycode
	if kc == 0 and ev.physical_keycode != 0:
		kc = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
	var t := _short(OS.get_keycode_string(kc))
	if t == "":
		t = "?"
	return _e(DevHint.Glyph.KEY if t.length() <= 2 else DevHint.Glyph.KEY_WIDE, t)


static func _mouse_entry(ev: InputEventMouseButton) -> Dictionary:
	match ev.button_index:
		MOUSE_BUTTON_LEFT: return _e(DevHint.Glyph.MOUSE_LEFT)
		MOUSE_BUTTON_RIGHT: return _e(DevHint.Glyph.MOUSE_RIGHT)
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			return _e(DevHint.Glyph.MOUSE_WHEEL)
	return _e(DevHint.Glyph.KEY_WIDE, "Mouse %d" % ev.button_index)


static func _face_entry(idx: int, style: int) -> Dictionary:
	match style:
		PadStyle.PLAYSTATION:
			var ps := [DevHint.Glyph.PS_CROSS, DevHint.Glyph.PS_CIRCLE,
				DevHint.Glyph.PS_SQUARE, DevHint.Glyph.PS_TRIANGLE]
			return _e(ps[idx])
		PadStyle.NINTENDO:
			var letters := ["B", "A", "Y", "X"]
			return _e(DevHint.Glyph.ROUND, letters[idx])
	var xb := [DevHint.Glyph.BUTTON_A, DevHint.Glyph.BUTTON_B,
		DevHint.Glyph.BUTTON_X, DevHint.Glyph.BUTTON_Y]
	return _e(xb[idx])


static func _joy_button_entry(idx: int, style: int) -> Dictionary:
	match idx:
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			return _face_entry(idx, style)
		JOY_BUTTON_BACK:
			return _e(DevHint.Glyph.PILL, ["View", "Create", "-"][style])
		JOY_BUTTON_START:
			return _e(DevHint.Glyph.PILL, ["Menu", "Options", "+"][style])
		JOY_BUTTON_GUIDE:
			return _e(DevHint.Glyph.PILL, "Guide")
		JOY_BUTTON_MISC1:
			return _e(DevHint.Glyph.PILL, "Share")
		JOY_BUTTON_LEFT_STICK:
			return _e(DevHint.Glyph.LEFT_STICK_CLICK)
		JOY_BUTTON_RIGHT_STICK:
			return _e(DevHint.Glyph.RIGHT_STICK_CLICK)
		JOY_BUTTON_LEFT_SHOULDER:
			return _e(DevHint.Glyph.LEFT_BUMPER, ["LB", "L1", "L"][style])
		JOY_BUTTON_RIGHT_SHOULDER:
			return _e(DevHint.Glyph.RIGHT_BUMPER, ["RB", "R1", "R"][style])
		JOY_BUTTON_DPAD_UP: return _e(DevHint.Glyph.DPAD_UP)
		JOY_BUTTON_DPAD_DOWN: return _e(DevHint.Glyph.DPAD_DOWN)
		JOY_BUTTON_DPAD_LEFT: return _e(DevHint.Glyph.DPAD_LEFT)
		JOY_BUTTON_DPAD_RIGHT: return _e(DevHint.Glyph.DPAD_RIGHT)
	return _e(DevHint.Glyph.PILL, "Btn %d" % idx)


static func _joy_axis_entry(axis: int, style: int) -> Dictionary:
	match axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return _e(DevHint.Glyph.LEFT_STICK)
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return _e(DevHint.Glyph.RIGHT_STICK)
		JOY_AXIS_TRIGGER_LEFT:
			return _e(DevHint.Glyph.LEFT_TRIGGER, ["LT", "L2", "ZL"][style])
		JOY_AXIS_TRIGGER_RIGHT:
			return _e(DevHint.Glyph.RIGHT_TRIGGER, ["RT", "R2", "ZR"][style])
	return _e(DevHint.Glyph.PILL, "Axis %d" % axis)
