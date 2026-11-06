@tool
extends EditorPlugin
## KCDT Music Zone editor plugin.
## Adds a "kcdt/music_zone" section to Project Settings > General that holds
## the project-wide defaults every KCDTMusicZone falls back to.

const SettingsRoot : String = "kcdt/music_zone/"

const Defaults : Dictionary = {
	"player_group": {
		"value": "Player",
		"type": TYPE_STRING,
	},
	"music_bus": {
		"value": "Music",
		"type": TYPE_STRING,
	},
	"fade_time": {
		"value": 2.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,60,0.05,or_greater,suffix:s",
	},
	"debug_print": {
		"value": false,
		"type": TYPE_BOOL,
	},
}


func _enter_tree() -> void:
	for key : String in Defaults:
		var path := SettingsRoot + key
		var info : Dictionary = Defaults[key]
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, info["value"])
		ProjectSettings.set_initial_value(path, info["value"])
		ProjectSettings.set_as_basic(path, true)
		ProjectSettings.add_property_info({
			"name": path,
			"type": info["type"],
			"hint": info.get("hint", PROPERTY_HINT_NONE),
			"hint_string": info.get("hint_string", ""),
		})


func _enable_plugin() -> void:
	ProjectSettings.save()


func _disable_plugin() -> void:
	for key : String in Defaults:
		ProjectSettings.set_setting(SettingsRoot + key, null)
	ProjectSettings.save()
