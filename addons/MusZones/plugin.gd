@tool
extends EditorPlugin
## KCDT Music Zone editor plugin.
## KCDTMusicZone registers itself through class_name, so it shows up in the
## "Create New Node" dialog as soon as the plugin is enabled.


func _enable_plugin() -> void:
	print("KCDT Music Zone enabled. Add a KCDTMusicZone node and give it a CollisionShape3D.")


func _disable_plugin() -> void:
	pass
