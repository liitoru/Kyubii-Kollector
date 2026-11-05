# KCDT - Kyubii Collector Development Tools
@tool
extends EditorPlugin

const Presets := preload("res://addons/dev_messages/dev_presets.gd")
const SettingsScript := preload("res://addons/dev_messages/dev_settings.gd")
const MessageScript := preload("res://addons/dev_messages/dev_message.gd")
const LabelScript := preload("res://addons/dev_messages/dev_label.gd")

const MENU_NAME := "Dev Messages"
var _menu: PopupMenu
var _preset_menu: PopupMenu
var _gizmo_plugin: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_preset_menu = PopupMenu.new()
	for p in Presets.Preset.values():
		_preset_menu.add_item(Presets.name_of(p), p)
	_preset_menu.id_pressed.connect(func(id: int) -> void: _add(0, id))

	_menu = PopupMenu.new()
	_menu.add_item("Add Dev Message", 0)
	_menu.add_submenu_node_item("Add Dev Message (preset)", _preset_menu)
	_menu.add_item("Add Dev Label", 1)
	_menu.add_item("Add DEVSETTINGS node", 2)
	_menu.id_pressed.connect(func(id: int) -> void: _add(id, Presets.Preset.DEFAULT))
	add_tool_submenu_item(MENU_NAME, _menu)

	_gizmo_plugin = preload("res://addons/dev_messages/dev_gizmo_plugin.gd").new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _gizmo_plugin:
		remove_node_3d_gizmo_plugin(_gizmo_plugin)


## kind: 0 = DevMessage, 1 = DevLabel, 2 = DEVSETTINGS only.
func _add(kind: int, preset: int) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("Dev Messages: open a scene first.")
		return

	var ur := get_undo_redo()
	ur.create_action("Add Dev Messages node")

	var settings: Node = _find_settings(root)
	if settings == null:
		settings = SettingsScript.new()
		settings.name = "DEVSETTINGS"
		_queue_add(ur, root, settings, root)

	var node: Node3D = null
	if kind == 0:
		var m = MessageScript.new()
		m.name = "DevMessage"
		m.preset = preset
		node = m
	elif kind == 1:
		node = LabelScript.new()
		node.name = "DevLabel"

	if node:
		var parent: Node = root
		var sel := EditorInterface.get_selection().get_selected_nodes()
		if sel.size() > 0 and sel[0] is Node3D:
			parent = sel[0]
		_queue_add(ur, parent, node, root)

	ur.commit_action()

	var pick: Node = node if node else settings
	if node:
		node.global_position = _spot_in_front_of_camera(node.get_parent())
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(pick)


func _queue_add(ur: EditorUndoRedoManager, parent: Node, node: Node, owner_root: Node) -> void:
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(node, "set_owner", owner_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)


func _find_settings(root: Node) -> Node:
	var found := root.find_children("*", "DevSettings", true, true)
	return found[0] if found.size() > 0 else null


func _spot_in_front_of_camera(parent: Node) -> Vector3:
	var vp := EditorInterface.get_editor_viewport_3d(0)
	if vp and vp.get_camera_3d():
		var cam := vp.get_camera_3d()
		return cam.global_position - cam.global_basis.z * 3.0
	return (parent as Node3D).global_position if parent is Node3D else Vector3.ZERO
