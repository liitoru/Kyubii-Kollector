# KCDT - Kyubii Collector Development Tools
@tool
class_name DevGlyphs
extends RefCounted
## Procedurally generated (SVG) input glyphs. Letters/key text are drawn as
## Label3D overlays by DevMessage, since SVG text is not supported.

const HEAD := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
const HEAD_WIDE := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="128" viewBox="0 0 256 128">'
const DPAD_PATH := "M48 8 H80 V48 H120 V80 H80 V120 H48 V80 H8 V48 H48 Z"
static var _cache: Dictionary = {}


static func is_wide(glyph: int) -> bool:
	return glyph == DevHint.Glyph.KEY_WIDE or glyph == DevHint.Glyph.PILL


static func get_texture(glyph: int) -> Texture2D:
	if _cache.has(glyph):
		return _cache[glyph]
	var head := HEAD_WIDE if is_wide(glyph) else HEAD
	var tex := svg_to_texture(head + _body(glyph) + "</svg>")
	if tex:
		_cache[glyph] = tex
	return tex


static func svg_to_texture(svg: String) -> Texture2D:
	var img := Image.new()
	if img.load_svg_from_string(svg, 2.0) != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## `text` (if not empty) always wins; otherwise the glyph's built-in label.
static func overlay_text(glyph: int, text: String) -> String:
	if text != "":
		return text
	match glyph:
		DevHint.Glyph.LEFT_STICK: return "L"
		DevHint.Glyph.RIGHT_STICK: return "R"
		DevHint.Glyph.LEFT_STICK_CLICK: return "L3"
		DevHint.Glyph.RIGHT_STICK_CLICK: return "R3"
		DevHint.Glyph.BUTTON_A: return "A"
		DevHint.Glyph.BUTTON_B: return "B"
		DevHint.Glyph.BUTTON_X: return "X"
		DevHint.Glyph.BUTTON_Y: return "Y"
		DevHint.Glyph.LEFT_BUMPER: return "LB"
		DevHint.Glyph.RIGHT_BUMPER: return "RB"
		DevHint.Glyph.LEFT_TRIGGER: return "LT"
		DevHint.Glyph.RIGHT_TRIGGER: return "RT"
	return ""


static func overlay_color(glyph: int) -> Color:
	match glyph:
		DevHint.Glyph.BUTTON_A, DevHint.Glyph.BUTTON_B, DevHint.Glyph.BUTTON_X:
			return Color.WHITE
		DevHint.Glyph.BUTTON_Y:
			return Color("#222222")
	return Color("#1b2a3a")


## Overlay font height as a fraction of the glyph height.
static func overlay_factor(glyph: int, text: String) -> float:
	var n := text.length()
	match glyph:
		DevHint.Glyph.LEFT_STICK, DevHint.Glyph.RIGHT_STICK, \
		DevHint.Glyph.LEFT_STICK_CLICK, DevHint.Glyph.RIGHT_STICK_CLICK:
			return 0.30 if n <= 1 else 0.22
		DevHint.Glyph.KEY:
			return 0.5 if n <= 1 else 0.36
		DevHint.Glyph.KEY_WIDE:
			return 0.42 if n <= 4 else (0.34 if n <= 6 else 0.26)
		DevHint.Glyph.PILL:
			return 0.36 if n <= 4 else (0.3 if n <= 6 else 0.24)
		DevHint.Glyph.LEFT_BUMPER, DevHint.Glyph.RIGHT_BUMPER, \
		DevHint.Glyph.LEFT_TRIGGER, DevHint.Glyph.RIGHT_TRIGGER:
			return 0.32 if n <= 2 else 0.26
	return 0.55


static func _face(color: String) -> String:
	return '<circle cx="64" cy="64" r="58" fill="%s" stroke="#fff" stroke-width="6"/>' % color


static func _ps(symbol: String) -> String:
	return '<circle cx="64" cy="64" r="58" fill="#2b303b" stroke="#fff" stroke-width="6"/>' + symbol


static func _stick(arrows: bool) -> String:
	var s := '<circle cx="64" cy="64" r="44" fill="none" stroke="#fff" stroke-width="6"/>'
	s += '<circle cx="64" cy="64" r="26" fill="#fff"/>'
	if arrows:
		s += '<path d="M64 4 L76 18 L52 18 Z M64 124 L76 110 L52 110 Z M4 64 L18 52 L18 76 Z M124 64 L110 52 L110 76 Z" fill="#fff"/>'
	return s


static func _dpad(arm: String) -> String:
	var s := '<path d="%s" fill="#fff" fill-opacity="0.3" stroke="#fff" stroke-opacity="0.6" stroke-width="6" stroke-linejoin="round"/>' % DPAD_PATH
	if arm != "":
		s += '<path d="%s" fill="#fff"/>' % arm
	return s


static func _mouse(left: bool, right: bool, wheel: bool) -> String:
	var s := '<rect x="26" y="6" width="76" height="116" rx="38" fill="none" stroke="#fff" stroke-width="6"/>'
	s += '<path d="M26 54 H102 M64 6 V54" stroke="#fff" stroke-width="5"/>'
	if left:
		s += '<path d="M64 6 Q26 6 26 44 V54 H64 Z" fill="#fff"/>'
	if right:
		s += '<path d="M64 6 Q102 6 102 44 V54 H64 Z" fill="#fff"/>'
	if wheel:
		s += '<rect x="56" y="16" width="16" height="30" rx="8" fill="#fff"/>'
	return s


static func _body(glyph: int) -> String:
	match glyph:
		DevHint.Glyph.LEFT_STICK, DevHint.Glyph.RIGHT_STICK:
			return _stick(true)
		DevHint.Glyph.LEFT_STICK_CLICK, DevHint.Glyph.RIGHT_STICK_CLICK:
			return _stick(false)
		DevHint.Glyph.DPAD:
			return _dpad("")
		DevHint.Glyph.DPAD_UP: return _dpad("M48 8 H80 V56 H48 Z")
		DevHint.Glyph.DPAD_DOWN: return _dpad("M48 72 H80 V120 H48 Z")
		DevHint.Glyph.DPAD_LEFT: return _dpad("M8 48 H56 V80 H8 Z")
		DevHint.Glyph.DPAD_RIGHT: return _dpad("M72 48 H120 V80 H72 Z")
		DevHint.Glyph.BUTTON_A: return _face("#4CAF50")
		DevHint.Glyph.BUTTON_B: return _face("#F44336")
		DevHint.Glyph.BUTTON_X: return _face("#2196F3")
		DevHint.Glyph.BUTTON_Y: return _face("#FFC107")
		DevHint.Glyph.ROUND:
			return '<circle cx="64" cy="64" r="58" fill="#fff"/>'
		DevHint.Glyph.PS_CROSS:
			return _ps('<path d="M40 40 L88 88 M88 40 L40 88" stroke="#7CA6E5" stroke-width="10" stroke-linecap="round"/>')
		DevHint.Glyph.PS_CIRCLE:
			return _ps('<circle cx="64" cy="64" r="24" fill="none" stroke="#E8707E" stroke-width="9"/>')
		DevHint.Glyph.PS_SQUARE:
			return _ps('<rect x="40" y="40" width="48" height="48" fill="none" stroke="#D08CBF" stroke-width="9" stroke-linejoin="round"/>')
		DevHint.Glyph.PS_TRIANGLE:
			return _ps('<path d="M64 36 L92 86 H36 Z" fill="none" stroke="#5FC9A8" stroke-width="9" stroke-linejoin="round"/>')
		DevHint.Glyph.PILL:
			return '<rect x="8" y="24" width="240" height="80" rx="40" fill="#fff"/>'
		DevHint.Glyph.LEFT_BUMPER, DevHint.Glyph.RIGHT_BUMPER:
			return '<rect x="4" y="34" width="120" height="60" rx="26" fill="#fff"/>'
		DevHint.Glyph.LEFT_TRIGGER, DevHint.Glyph.RIGHT_TRIGGER:
			return '<path d="M30 14 H98 Q114 14 114 30 V70 Q114 114 64 114 Q14 114 14 70 V30 Q14 14 30 14 Z" fill="#fff"/>'
		DevHint.Glyph.VR_TRIGGER:
			return '<path d="M44 8 Q92 8 92 40 L92 120 H72 L72 52 Q72 34 44 34 Z" fill="#fff"/>'
		DevHint.Glyph.VR_GRIP:
			return '<ellipse cx="64" cy="64" rx="38" ry="58" fill="#fff"/><path d="M40 44 Q64 30 88 44 M40 64 Q64 50 88 64 M40 84 Q64 70 88 84" stroke="#8a97a6" stroke-width="5" fill="none" stroke-linecap="round"/>'
		DevHint.Glyph.MOUSE_LEFT: return _mouse(true, false, false)
		DevHint.Glyph.MOUSE_RIGHT: return _mouse(false, true, false)
		DevHint.Glyph.MOUSE_WHEEL: return _mouse(false, false, true)
		DevHint.Glyph.KEY:
			return '<rect x="6" y="14" width="116" height="100" rx="20" fill="#fff"/><rect x="16" y="24" width="96" height="76" rx="12" fill="none" stroke="#c5ccd4" stroke-width="4"/>'
		DevHint.Glyph.KEY_WIDE:
			return '<rect x="6" y="14" width="244" height="100" rx="20" fill="#fff"/><rect x="16" y="24" width="224" height="80" rx="12" fill="none" stroke="#c5ccd4" stroke-width="4"/>'
	return ""
