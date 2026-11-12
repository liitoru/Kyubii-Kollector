extends Area3D
##OLD CODE UNUSED SINCE PLUGIN IS IN FOR THIS
@export var CanCreate : bool = true
@export var Music : AudioStream
@export var WorldRoot : NodePath
@export var Touchable : bool = true
@export var TweenSpeed : float = 2
@export var TargetVolume : float = 0.0

const SilentDb : float = -80.0

var MusicBus : int = -1


func _ready() -> void:
	MusicBus = AudioServer.get_bus_index("Music")
	if MusicBus == -1:
		push_warning("HEY THE CHANNEL ISNT THE MUSIC ONE!")
	CheckIfAME()
	self.body_entered.connect(func(Body : Node3D):
		if Touchable and Body.is_in_group("Player"):
			TweenMusic()
	)


func CheckIfAME() -> void:
	var root : Node
	if WorldRoot:
		root = get_node_or_null(WorldRoot)
	else:
		root = self.get_parent()
	if root == null:
		push_warning("WorldRoot path is invalid!")
		return
	if root.has_node("MusicManager") or get_tree().get_first_node_in_group("MusicManager"):
		return
	if root.has_meta("music_manager_pending"):
		return
	push_warning("Couldn't find MusicManager, creating one if possible!")
	if not CanCreate:
		return
	root.set_meta("music_manager_pending", true)
	var mus_manager := Node.new()
	mus_manager.name = "MusicManager"
	mus_manager.add_to_group("MusicManager")
	root.add_child.call_deferred(mus_manager)
	await get_tree().process_frame
	root.remove_meta("music_manager_pending")


func GetManager() -> Node:
	for i in 10:
		var manager := get_tree().get_first_node_in_group("MusicManager")
		if manager:
			return manager
		await get_tree().process_frame
	return null


func CreateTrack(Manager : Node, TrackName : String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = TrackName
	player.stream = Music
	player.volume_db = SilentDb
	if MusicBus != -1:
		player.bus = "Music"
	Manager.add_child(player)
	player.play()
	return player


func FadeIn(Player : AudioStreamPlayer) -> void:
	var tween := Player.create_tween()
	tween.tween_property(Player, "volume_db", TargetVolume, TweenSpeed).set_trans(Tween.TRANS_SINE)


func FadeOut(Player : AudioStreamPlayer) -> void:
	var tween := Player.create_tween()
	tween.tween_property(Player, "volume_db", SilentDb, TweenSpeed).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(Player.queue_free)


func IsSameTrack(Player : AudioStreamPlayer) -> bool:
	if Player.stream == null or Music == null:
		return false
	if Player.stream == Music:
		return true
	return Player.stream.resource_path != "" and Player.stream.resource_path == Music.resource_path


func TweenMusic() -> void:
	if Music == null:
		return
	var manager := await GetManager()
	if manager == null:
		push_warning("No MusicManager yet!")
		return
	var main := manager.get_node_or_null("MainTrack") as AudioStreamPlayer
	if main == null:
		FadeIn(CreateTrack(manager, "MainTrack"))
		return
	if IsSameTrack(main):
		if not main.playing:
			main.volume_db = SilentDb
			main.play()
			FadeIn(main)
		return
	main.name = "OldTrack"
	FadeOut(main)
	FadeIn(CreateTrack(manager, "MainTrack"))
