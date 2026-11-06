@tool
@icon("icon.svg")
class_name KCDTMusicZoneShape
extends CollisionShape3D
## The collision shape used by KCDTMusicZone. It's a normal CollisionShape3D
## (same handles, debug color, disabled toggle...) that starts out as a
## 4x4x4 box so a new zone is usable straight away.


func _enter_tree() -> void:
	if shape == null:
		var box := BoxShape3D.new()
		box.size = Vector3(4.0, 4.0, 4.0)
		shape = box


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not (get_parent() is KCDTMusicZone):
		warnings.append("KCDTMusicZoneShape is meant to be a child of a KCDTMusicZone.")
	return warnings
