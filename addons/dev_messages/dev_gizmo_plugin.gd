# KCDT - Kyubii Collector Development Tools
@tool
extends EditorNode3DGizmoPlugin
## Makes DevMessage nodes clickable in the 3D editor viewport (and draws a
## thin frame around the icon/panel). Click to select, then use the normal
## Move tool (W) to drag it around.


func _init() -> void:
	create_material("frame", Color(0.13, 0.59, 0.95, 0.9), false, true)


func _get_gizmo_name() -> String:
	return "DevMessage"


func _has_gizmo(node: Node3D) -> bool:
	return node is DevMessage


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d() as DevMessage
	if node == null:
		return
	var d := node.get_pick_data()
	if d.is_empty():
		return
	var xf: Transform3D = d["xform"]
	var lines := PackedVector3Array()
	var faces := PackedVector3Array()
	_add_rect(Vector2.ZERO, d["icon_size"], xf, lines, faces)
	if d["panel_visible"]:
		_add_rect(d["panel_pos"], d["panel_size"], xf, lines, faces)
	gizmo.add_lines(lines, get_material("frame", gizmo))
	var tm := TriangleMesh.new()
	tm.create_from_faces(faces)
	gizmo.add_collision_triangles(tm)


func _add_rect(c: Vector2, size: Vector2, xf: Transform3D,
		lines: PackedVector3Array, faces: PackedVector3Array) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var p: Array[Vector3] = [
		xf * Vector3(c.x - hx, c.y - hy, 0.0),
		xf * Vector3(c.x + hx, c.y - hy, 0.0),
		xf * Vector3(c.x + hx, c.y + hy, 0.0),
		xf * Vector3(c.x - hx, c.y + hy, 0.0),
	]
	lines.append_array([p[0], p[1], p[1], p[2], p[2], p[3], p[3], p[0]])
	faces.append_array([p[0], p[1], p[2], p[0], p[2], p[3]])
