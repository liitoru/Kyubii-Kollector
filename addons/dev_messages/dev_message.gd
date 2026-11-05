# KCDT - Kyubii Collector Development Tools
@tool
@icon("res://addons/dev_messages/icons/dev_message.svg")
class_name DevMessage
extends Node3D
const Presets := preload("res://addons/dev_messages/dev_presets.gd")
## A floating icon that opens into a note panel (title, body, input hints).
## Look and behaviour come from the DEVSETTINGS node (DevSettings).
## In the editor, click the icon or panel in the 3D viewport to select it.

@export var title: String = "Dev Note"
@export_multiline var body: String = "Write your message here."
## Used by DevSettings.hidden_categories to filter notes.
@export var category: String = "General"

@export_group("Input Hints")
## Rows under the text: a glyph (stick, button, key, mouse...) + description.
@export var hints: Array[DevHint] = []

@export_group("Look")
## Visual preset = a color + an icon. DEFAULT follows the DEVSETTINGS colors.
@export var preset: Presets.Preset = Presets.Preset.DEFAULT
## Tick to give THIS note its own color (panel + icon badge) with `color`.
@export var override_color: bool = false
@export var color: Color = Color("#2196F3")
## This note's own icon (.svg / .png). Beats the preset icon.
@export var custom_icon: Texture2D
## Tint the custom icon with the note's color.
@export var tint_custom_icon: bool = false
@export var icon_size: float = 0.2

@export_group("Behaviour")
## Keep the panel open while editing so you can read it in the viewport.
@export var open_in_editor: bool = true
@export var start_open: bool = false
## Face the camera.
@export var billboard: bool = true

@export_group("Panel overrides")
## Off = width and outline come from DEVSETTINGS.
@export var override_panel: bool = false
@export var panel_width: float = 0.9
@export var panel_outline: bool = true
@export var panel_outline_color: Color = Color.WHITE
@export var panel_outline_width: float = 0.012

const PIXEL := 0.002
const PAD := 0.05
const GAP := 0.03
const ROW_GAP := 0.02
const GLYPH_GAP := 0.03
const GLYPH_PITCH := 0.015
const ICON_GAP := 0.12
const Z := 0.003

var _rig: Node3D
var _icon: Sprite3D
var _panel: Node3D
var _bg: MeshInstance3D
var _quad: QuadMesh
var _outline_mi: MeshInstance3D
var _outline_quad: QuadMesh
var _title_lbl: Label3D
var _body_lbl: Label3D
var _rows: Array = []
var _base_w: float = 0.9
var _glyph_size: float = 0.08
var _outline_w: float = 0.0
var _icon_extent: Vector2 = Vector2(0.2, 0.2)
var _state_hash: int = 0
var _layout_wait: int = 0
var _manual_open: bool = false
var _proximity_open: bool = false
var _last_pick_key: Array = []


func _ready() -> void:
	_manual_open = start_open


## Open/close this note (call from a VR pointer, interaction ray, etc).
func toggle() -> void:
	_manual_open = not _manual_open


func set_open(value: bool) -> void:
	_manual_open = value


## Rectangles used by the editor gizmo so the message can be clicked.
func get_pick_data() -> Dictionary:
	if _rig == null or not is_instance_valid(_rig) or _quad == null:
		return {}
	return {
		"xform": _rig.transform,
		"icon_size": _icon_extent,
		"panel_visible": _panel.visible,
		"panel_pos": Vector2(_panel.position.x, _panel.position.y),
		"panel_size": _quad.size + Vector2.ONE * _outline_w * 2.0,
	}


func _process(_delta: float) -> void:
	var s := DevSettings.find(self)
	var res := _resolve_all(s)
	var h := _compute_hash(s, res)
	if h != _state_hash or _rig == null or not is_instance_valid(_rig):
		_state_hash = h
		_rebuild(s, res)

	var active := _is_active(s)
	_rig.visible = active
	var cam := DevSettings.get_camera(self)

	if active:
		if billboard and cam:
			var dir := cam.global_position - _rig.global_position
			if dir.length_squared() > 0.0001:
				var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
				_rig.global_basis = Basis.looking_at(-dir, up)
		elif not billboard:
			_rig.transform.basis = Basis.IDENTITY

		if _layout_wait > 0:
			_panel.visible = true  # labels must be visible to be measured
			_layout_wait -= 1
			if _layout_wait == 0:
				_layout()
		else:
			_panel.visible = _is_open(s, cam)
	else:
		_panel.visible = false

	_update_pick()


func _update_pick() -> void:
	if not Engine.is_editor_hint():
		return
	var key := [_rig.transform, _panel.visible, _quad.size, _panel.position, _icon_extent]
	if key != _last_pick_key:
		_last_pick_key = key
		update_gizmos()


func _is_active(s: DevSettings) -> bool:
	if s:
		return s.is_message_visible(category)
	return Engine.is_editor_hint() or OS.is_debug_build()


func _is_open(s: DevSettings, cam: Camera3D) -> bool:
	if Engine.is_editor_hint():
		return open_in_editor
	if _manual_open or s == null:
		return true
	if s.all_open:
		return true
	match s.reveal_mode:
		DevSettings.RevealMode.ALWAYS_OPEN:
			return true
		DevSettings.RevealMode.PROXIMITY:
			if cam == null:
				return false
			var limit := s.reveal_distance * (1.2 if _proximity_open else 1.0)
			_proximity_open = cam.global_position.distance_to(global_position) < limit
			return _proximity_open
	return false


## Glyph entries for every hint, for the device the player is using right now.
func _resolve_all(s: DevSettings) -> Array:
	var dev: int = s.get_device() if s else DevInput.Device.KEYBOARD
	var sty: int = s.get_pad_style() if s else DevInput.PadStyle.XBOX
	var out: Array = []
	for hnt in hints:
		if hnt:
			out.append(DevInput.resolve_hint(hnt, dev, sty))
		else:
			out.append([])
	return out


func _compute_hash(s: DevSettings, res: Array) -> int:
	var hh: Array = []
	for i in hints.size():
		var row: Array = [hints[i].description if hints[i] else ""]
		for e in res[i]:
			row.append([e["glyph"], e["text"],
				(e["icon"] as Texture2D).get_instance_id() if e["icon"] else 0])
		hh.append(row)
	return hash([title, body, preset, override_color, color, override_panel,
		panel_width, panel_outline, panel_outline_color, panel_outline_width,
		icon_size, tint_custom_icon,
		custom_icon.get_instance_id() if custom_icon else 0,
		hh, s.style_hash() if s else 0])


func _style(s: DevSettings) -> Dictionary:
	# Color + icon come from the node itself first, DEVSETTINGS is only the fallback.
	var panel: Color
	var icon: Color
	if override_color:
		panel = color
		icon = color
	elif preset != Presets.Preset.DEFAULT:
		panel = Presets.color_of(preset)
		icon = panel
	elif s:
		panel = s.panel_color
		icon = s.icon_color
	else:
		panel = Presets.color_of(Presets.Preset.DEFAULT)
		icon = panel

	var own := override_panel or s == null
	return {
		"panel": panel, "icon": icon,
		"text": s.text_color if s else Color.WHITE,
		"on_top": s.always_on_top if s else false,
		"title_size": s.title_size if s else 40,
		"body_size": s.body_size if s else 28,
		"glyph": s.glyph_size if s else 0.08,
		"desc_size": s.hint_text_size if s else 26,
		"default_icon": s.default_icon if s else null,
		"width": panel_width if own else s.panel_width,
		"outline": panel_outline if own else s.outline_enabled,
		"outline_color": panel_outline_color if own else s.outline_color,
		"outline_w": panel_outline_width if own else s.outline_width,
	}


func _rebuild(s: DevSettings, res: Array) -> void:
	# Free EVERY internal child (also leftovers from a script reload / old
	# addon version), otherwise old and new panels draw on top of each other.
	var normal := get_children(false)
	for c in get_children(true):
		if not normal.has(c):
			remove_child(c)
			c.free()
	_rig = null
	var st := _style(s)
	var on_top: bool = st["on_top"]
	_base_w = st["width"]
	_glyph_size = st["glyph"]
	_outline_w = float(st["outline_w"]) if st["outline"] else 0.0

	_rig = Node3D.new()
	add_child(_rig, false, Node.INTERNAL_MODE_FRONT)

	# --- Icon: own icon > preset icon > settings default icon > envelope ---
	var itex: Texture2D = custom_icon
	var used_custom := itex != null
	if itex == null and preset != Presets.Preset.DEFAULT:
		itex = Presets.icon_of(preset, st["icon"])
	if itex == null:
		itex = st["default_icon"] as Texture2D
		used_custom = itex != null
	if itex == null:
		itex = Presets.icon_of(Presets.Preset.DEFAULT, st["icon"])
	_icon = _make_sprite(itex, icon_size, on_top, 1)
	if tint_custom_icon and used_custom:
		_icon.modulate = st["icon"]
	_icon_extent = Vector2(itex.get_width(), itex.get_height()) \
		/ maxf(maxf(itex.get_width(), itex.get_height()), 1.0) * icon_size
	_rig.add_child(_icon)

	# --- Panel ---
	_panel = Node3D.new()
	_rig.add_child(_panel)

	_outline_quad = QuadMesh.new()
	_outline_quad.size = Vector2(_base_w, 0.3)
	_outline_quad.material = _flat_material(st["outline_color"], on_top, -1)
	_outline_mi = MeshInstance3D.new()
	_outline_mi.mesh = _outline_quad
	_outline_mi.position = Vector3(0, 0, -0.002)
	_outline_mi.visible = st["outline"]
	_panel.add_child(_outline_mi)

	_quad = QuadMesh.new()
	_quad.size = Vector2(_base_w, 0.3)
	_quad.material = _flat_material(st["panel"], on_top, 0)
	_bg = MeshInstance3D.new()
	_bg.mesh = _quad
	_panel.add_child(_bg)

	var inner_w := _base_w - PAD * 2.0
	_title_lbl = _make_label(title, st["title_size"], st["text"], inner_w, on_top)
	_body_lbl = _make_label(body, st["body_size"], st["text"], inner_w, on_top)
	_panel.add_child(_title_lbl)
	_panel.add_child(_body_lbl)

	# --- Input hint rows (one or more glyphs + description) ---
	_rows.clear()
	for i in hints.size():
		var hnt := hints[i]
		if hnt == null:
			continue
		var glyphs: Array = []
		var gw := 0.0
		for e in res[i]:
			var gl: int = e["glyph"]
			var tex: Texture2D
			if gl == DevHint.Glyph.CUSTOM:
				tex = e["icon"]
			else:
				tex = DevGlyphs.get_texture(gl)
			var ew := _glyph_size
			var spr: Sprite3D = null
			if tex:
				ew = _glyph_size * float(tex.get_width()) / maxf(tex.get_height(), 1.0)
				spr = _make_sprite(tex, _glyph_size, on_top, 1, true)
				_panel.add_child(spr)
			var ov: Label3D = null
			var ov_text := DevGlyphs.overlay_text(gl, e["text"])
			if ov_text != "":
				var px := PIXEL * 0.5
				var f := DevGlyphs.overlay_factor(gl, ov_text)
				var fs := int(clampf(_glyph_size * f / px, 1.0, 127.0))
				ov = _make_label(ov_text, fs, DevGlyphs.overlay_color(gl), 0.0,
					on_top, 2, px, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
				_panel.add_child(ov)
			glyphs.append({"sprite": spr, "overlay": ov, "w": ew})
			gw += ew
			if glyphs.size() > 1:
				gw += GLYPH_PITCH
		var desc_w := maxf(inner_w - gw - GLYPH_GAP, 0.1)
		var desc := _make_label(hnt.description, st["desc_size"], st["text"], desc_w,
			on_top, 1, PIXEL, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
		_panel.add_child(desc)
		_rows.append({"glyphs": glyphs, "gw": gw, "desc": desc})

	_layout_wait = 3  # let Label3D build its text mesh, then measure
	_layout()


func _flat_material(color: Color, on_top: bool, prio: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = on_top
	mat.render_priority = prio
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _make_sprite(tex: Texture2D, size_m: float, on_top: bool, prio: int,
		by_height: bool = false) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	var ref_px: float = tex.get_height() if by_height else maxf(tex.get_width(), tex.get_height())
	sp.pixel_size = size_m / maxf(ref_px, 1.0)
	sp.shaded = false
	sp.double_sided = true
	sp.no_depth_test = on_top
	sp.render_priority = prio
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sp


func _make_label(text: String, size: int, color: Color, width_m: float, on_top: bool,
		prio: int = 1, pixel: float = PIXEL,
		halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		valign: VerticalAlignment = VERTICAL_ALIGNMENT_TOP) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = true
	l.horizontal_alignment = halign
	l.vertical_alignment = valign
	if width_m > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width_m / pixel
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.no_depth_test = on_top
	l.render_priority = prio
	return l


func _layout() -> void:
	if _title_lbl == null or not is_instance_valid(_title_lbl):
		return
	var w := _base_w
	var th := _title_lbl.get_aabb().size.y
	var has_body := body.strip_edges() != ""
	_body_lbl.visible = has_body
	var bh := _body_lbl.get_aabb().size.y if has_body else 0.0

	var heights: Array[float] = []
	var rows_h := 0.0
	for r in _rows:
		var dh: float = (r["desc"] as Label3D).get_aabb().size.y
		var rh := maxf(_glyph_size, dh)
		heights.append(rh)
		rows_h += rh
	if _rows.size() > 1:
		rows_h += ROW_GAP * (_rows.size() - 1)

	var h := PAD * 2.0 + th
	if has_body:
		h += GAP + bh
	if _rows.size() > 0:
		h += GAP + rows_h

	_quad.size = Vector2(w, h)
	_outline_quad.size = Vector2(w + _outline_w * 2.0, h + _outline_w * 2.0)
	_panel.position = Vector3(ICON_GAP + _outline_w + w * 0.5, 0.0, 0.0)

	var cur := h * 0.5 - PAD
	_title_lbl.position = Vector3(0.0, cur, Z)
	cur -= th
	if has_body:
		cur -= GAP
		_body_lbl.position = Vector3(0.0, cur, Z)
		cur -= bh
	if _rows.size() > 0:
		cur -= GAP
	var left := -w * 0.5 + PAD
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var rh: float = heights[i]
		var cy := cur - rh * 0.5
		var x := left
		for g in r["glyphs"]:
			var gwid: float = g["w"]
			if g["sprite"]:
				(g["sprite"] as Sprite3D).position = Vector3(x + gwid * 0.5, cy, Z)
			if g["overlay"]:
				(g["overlay"] as Label3D).position = Vector3(x + gwid * 0.5, cy, Z + 0.002)
			x += gwid + GLYPH_PITCH
		(r["desc"] as Label3D).position = Vector3(left + float(r["gw"]) + GLYPH_GAP, cy, Z)
		cur -= rh + ROW_GAP
