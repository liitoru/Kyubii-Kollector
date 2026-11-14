extends MeshInstance3D

@export var shadow_size := 2.0
@export var max_alpha := 1.0
@export var fade_distance := 6.0
@export var min_scale := 0.5
@export var ground_lift := 0.02
@export_range(0.0, 1.0) var edge_start := 0.7
@export_range(0.0, 1.0) var edge_end := 0.8
@export var align_to_floor := true
@export var align_speed := 12.0
@export_range(1, 20) var shadow_layer := 20
@export var debug := false
@export var debug_interval := 0.5
@export var debug_preview := false ##a fucking whole test ui only to test if the fucking shadow worked
##atleast it works and such so poggers!!
@export var preview_size := 256
@export var cam_yaw_degrees := 0.0

@onready var player: Node3D = get_parent()
@onready var ray: RayCast3D = $"../FakeShadowRay"
@onready var sub_viewport: SubViewport = $"../SubViewport"
@onready var proj_cam: Camera3D = $"../SubViewport/Projected"

var mat: StandardMaterial3D
var smooth_normal := Vector3.UP
var debug_timer := 0.0
var cam_height := 1.0
var preview_label: Label


func _dbg(msg: String) -> void:
	if debug:
		print("[FakeShadow] ", msg)


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ray.enabled = true

	var src := get_active_material(0)
	_dbg("source material: %s" % [src])
	if src is StandardMaterial3D:
		mat = src.duplicate()
		_dbg("duplicated StandardMaterial3D")
	else:
		mat = StandardMaterial3D.new()
		_dbg("source was not StandardMaterial3D, created a new one")

	var plane := PlaneMesh.new()
	plane.size = Vector2(shadow_size, shadow_size)
	mesh = plane
	_dbg("plane mesh set, size %s" % [plane.size])

	var fox_root := player.get_node("CharacterPivot")
	var meshes := fox_root.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		m.set_layer_mask_value(shadow_layer, true)
		_dbg("layer %d enabled on %s (layers=%d)" % [shadow_layer, m.get_path(), m.layers])
	_dbg("fox meshes tagged: %d" % meshes.size())
	if meshes.is_empty():
		push_warning("[FakeShadow] no MeshInstance3D found under CharacterPivot")

	cam_height = proj_cam.position.y
	proj_cam.cull_mask = 1 << (shadow_layer - 1)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	proj_cam.environment = env
	_dbg("proj cam cull_mask=%d current=%s" % [proj_cam.cull_mask, proj_cam.current])

	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_dbg("viewport size=%s own_world_3d=%s transparent_bg=%s" % [sub_viewport.size, sub_viewport.own_world_3d, sub_viewport.transparent_bg])

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = sub_viewport.get_texture()
	mat.albedo_color = Color(0, 0, 0, max_alpha)
	material_override = mat
	_dbg("texture assigned: %s" % [mat.albedo_texture])
	_dbg("ray target=%s mask=%d enabled=%s" % [ray.target_position, ray.collision_mask, ray.enabled])

	if debug_preview:
		_build_preview()


func _build_preview() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	layer.add_child(box)

	var title := Label.new()
	title.text = "FakeShadow viewport preview"
	box.add_child(title)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(preview_size, preview_size)
	box.add_child(holder)

	var bg_a := ColorRect.new()
	bg_a.color = Color(0.85, 0.85, 0.85)
	bg_a.size = Vector2(preview_size, preview_size)
	holder.add_child(bg_a)

	var cells := 8
	var cell := preview_size / float(cells)
	for x in cells:
		for y in cells:
			if (x + y) % 2 == 0:
				continue
			var c := ColorRect.new()
			c.color = Color(0.55, 0.55, 0.55)
			c.position = Vector2(x * cell, y * cell)
			c.size = Vector2(cell, cell)
			holder.add_child(c)

	var tex_rect := TextureRect.new()
	tex_rect.texture = sub_viewport.get_texture()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.size = Vector2(preview_size, preview_size)
	holder.add_child(tex_rect)

	var border := ReferenceRect.new()
	border.border_color = Color.RED
	border.editor_only = false
	border.size = Vector2(preview_size, preview_size)
	holder.add_child(border)

	preview_label = Label.new()
	box.add_child(preview_label)


func _process(_delta: float) -> void:
	proj_cam.global_position = player.global_position + Vector3(0.0, cam_height, 0.0)
	proj_cam.global_rotation_degrees = Vector3(-90.0, cam_yaw_degrees, 0.0)
	if not debug_preview or preview_label == null:
		return
	var tex := sub_viewport.get_texture()
	preview_label.text = "tex: %s\nvp size: %s\nplane visible in tree: %s\nray colliding: %s\ncam pos: %s\ncam rot: %s\nplane pos: %s\nalpha: %.2f\ncam proj: %s size: %.2f far: %.1f" % [
		"ok" if tex != null else "NULL",
		sub_viewport.size,
		is_visible_in_tree(),
		ray.is_colliding(),
		proj_cam.global_position,
		proj_cam.global_rotation_degrees,
		global_position,
		mat.albedo_color.a,
		proj_cam.projection,
		proj_cam.size,
		proj_cam.far,
	]


func _physics_process(delta: float) -> void:
	debug_timer += delta
	var do_print := debug and debug_timer >= debug_interval
	if do_print:
		debug_timer = 0.0

	if not ray.is_colliding():
		visible = false
		if do_print:
			_dbg("ray NOT colliding, hidden (ray global pos=%s)" % [ray.global_position])
		return
	visible = true

	var p := player.global_position
	var hit := ray.get_collision_point()
	var ground_y := hit.y

	var target_normal := Vector3.UP
	if align_to_floor:
		target_normal = ray.get_collision_normal()

	var w := 1.0 - exp(-align_speed * delta)

	smooth_normal = smooth_normal.lerp(target_normal, w).normalized()

	var up := smooth_normal
	var right := up.cross(Vector3.BACK).normalized()
	if right.length() < 0.001:
		right = Vector3.RIGHT
	var back := right.cross(up).normalized()

	var distance := maxf(p.y - ground_y, 0.0)
	var t := clampf(distance / fade_distance, 0.0, 1.0)
	var s := lerpf(1.0, min_scale, t)

	mat.albedo_color.a = max_alpha * (1.0 - t)

	global_transform = Transform3D(Basis(right, up, back).scaled(Vector3.ONE * s), Vector3(p.x, ground_y, p.z) + up * ground_lift)

	if do_print:
		_dbg("hit=%s normal=%s dist=%.2f t=%.2f scale=%.2f alpha=%.2f pos=%s" % [hit, target_normal, distance, t, s, mat.albedo_color.a, global_position])
