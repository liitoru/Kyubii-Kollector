@tool
@icon("icon.svg")
class_name KCDTMusicZone
extends Area3D
## KCDT Music Zone (by KCDT - Kyubii Collector Development Tools)
##
## An Area3D that crossfades background music when the player walks into it.
## Tracks live under a "MusicManager" node, which is created automatically
## (if CanCreate is on) when none exists yet.

signal music_started(zone: KCDTMusicZone)
signal music_stopped(zone: KCDTMusicZone)

enum LoopOption { DEFAULT, FORCE_LOOP, NO_LOOP }
enum ExitAction { NOTHING, FADE_OUT_MUSIC }

const SilentDb : float = -80.0
const MainTrackName : String = "MainTrack"
const ManagerName : String = "MusicManager"
const ManagerGroup : String = "MusicManager"

@export_group("Zone")
## Master switch. When off the zone never reacts to the player.
@export var Enabled : bool = true
## Whether the zone reacts to the player touching it.
@export var Touchable : bool = true
## Only bodies in this group trigger the zone.
@export var PlayerGroup : StringName = &"Player"
## After the first successful trigger the zone turns itself off.
@export var OneShot : bool = false
## Seconds to wait after touching before the music starts.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:s") var StartDelay : float = 0.0

@export_group("Music")
@export var Music : AudioStream
## Name of the audio bus the music is played on.
@export var BusName : StringName = &"Music"
## Volume the track fades up to.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var TargetVolume : float = 0.0
@export_range(0.5, 2.0, 0.01) var PitchScale : float = 1.0
## Where in the track playback starts, in seconds.
@export_range(0.0, 600.0, 0.1, "or_greater", "suffix:s") var StartPosition : float = 0.0
## DEFAULT keeps the stream's own loop setting. Works for OGG, MP3 and WAV.
@export var LoopMode : LoopOption = LoopOption.DEFAULT
## If the same track is already playing, restart it instead of leaving it alone.
@export var RestartIfSame : bool = false

@export_group("Fade")
## Fade in / fade out duration in seconds.
@export_range(0.0, 60.0, 0.05, "or_greater", "suffix:s") var TweenSpeed : float = 2.0
## Fade-out duration for the track being replaced. Negative = use TweenSpeed.
@export_range(-1.0, 60.0, 0.05, "or_greater", "suffix:s") var OldTrackFadeSpeed : float = -1.0
@export var FadeTransition : Tween.TransitionType = Tween.TRANS_SINE
@export var FadeEase : Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Exit")
@export var OnExit : ExitAction = ExitAction.NOTHING
## Fade-out duration when leaving the zone. Negative = use TweenSpeed.
@export_range(-1.0, 60.0, 0.05, "or_greater", "suffix:s") var ExitFadeSpeed : float = -1.0

@export_group("Manager")
## Create a MusicManager node if none can be found.
@export var CanCreate : bool = true
## Node the MusicManager is created under. Empty = this zone's parent.
@export var WorldRoot : NodePath

@export_group("Debug")
@export var DebugPrint : bool = false

var MusicBus : int = -1
var _triggered : bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ResolveBus()
	CheckIfAME()
	body_entered.connect(_OnBodyEntered)
	body_exited.connect(_OnBodyExited)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if Music == null:
		warnings.append("No Music stream assigned - this zone won't play anything.")
	if not WorldRoot.is_empty() and get_node_or_null(WorldRoot) == null:
		warnings.append("WorldRoot path doesn't point to a valid node.")
	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			has_shape = true
			break
	if not has_shape:
		warnings.append("Add a CollisionShape3D child so the zone can detect the player.")
	return warnings


# --- Public API -------------------------------------------------------------

## Starts this zone's music, same as the player touching it.
func Play() -> void:
	await TweenMusic()


## Fades out whatever is on the main track.
func Stop(FadeTime : float = -1.0) -> void:
	var manager := await GetManager()
	if manager == null:
		return
	var main := manager.get_node_or_null(MainTrackName) as AudioStreamPlayer
	if main == null:
		return
	main.name = "OldTrack"
	FadeOut(main, FadeTime if FadeTime >= 0.0 else TweenSpeed)
	music_stopped.emit(self)


# --- Internals --------------------------------------------------------------

func _ResolveBus() -> void:
	MusicBus = AudioServer.get_bus_index(BusName)
	if MusicBus == -1:
		push_warning("KCDTMusicZone: audio bus '%s' doesn't exist, falling back to Master." % BusName)


func _Log(Message : String) -> void:
	if DebugPrint:
		print("[KCDTMusicZone:%s] %s" % [name, Message])


func _OnBodyEntered(Body : Node3D) -> void:
	if not Enabled or not Touchable or not Body.is_in_group(PlayerGroup):
		return
	if OneShot:
		if _triggered:
			return
		_triggered = true
		Touchable = false
	if StartDelay > 0.0:
		await get_tree().create_timer(StartDelay).timeout
		if not is_inside_tree():
			return
	TweenMusic()


func _OnBodyExited(Body : Node3D) -> void:
	if not Enabled or OnExit == ExitAction.NOTHING or not Body.is_in_group(PlayerGroup):
		return
	var manager := get_tree().get_first_node_in_group(ManagerGroup)
	if manager == null:
		return
	var main := manager.get_node_or_null(MainTrackName) as AudioStreamPlayer
	if main == null or not IsSameTrack(main):
		return # another zone's music is playing, leave it alone
	main.name = "OldTrack"
	FadeOut(main, ExitFadeSpeed if ExitFadeSpeed >= 0.0 else TweenSpeed)
	music_stopped.emit(self)


func CheckIfAME() -> void:
	var root : Node
	if not WorldRoot.is_empty():
		root = get_node_or_null(WorldRoot)
	else:
		root = get_parent()
	if root == null:
		push_warning("WorldRoot path is invalid!")
		return
	if root.has_node(ManagerName) or get_tree().get_first_node_in_group(ManagerGroup):
		return
	if root.has_meta("music_manager_pending"):
		return
	push_warning("Couldn't find MusicManager, creating one if possible!")
	if not CanCreate:
		return
	root.set_meta("music_manager_pending", true)
	var mus_manager := Node.new()
	mus_manager.name = ManagerName
	mus_manager.add_to_group(ManagerGroup)
	root.add_child.call_deferred(mus_manager)
	await get_tree().process_frame
	root.remove_meta("music_manager_pending")


func GetManager() -> Node:
	for i in 10:
		var manager := get_tree().get_first_node_in_group(ManagerGroup)
		if manager:
			return manager
		await get_tree().process_frame
	return null


func _PrepareStream() -> AudioStream:
	if Music == null or LoopMode == LoopOption.DEFAULT:
		return Music
	var copy := Music.duplicate() as AudioStream
	var enable := LoopMode == LoopOption.FORCE_LOOP
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = enable
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = enable
	elif copy is AudioStreamWAV:
		(copy as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enable else AudioStreamWAV.LOOP_DISABLED
	return copy


func CreateTrack(Manager : Node, TrackName : String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = TrackName
	player.stream = _PrepareStream()
	# Remember the original resource so IsSameTrack still works on loop copies.
	player.set_meta("kcdt_source", Music)
	player.volume_db = SilentDb
	player.pitch_scale = PitchScale
	if MusicBus != -1:
		player.bus = BusName
	Manager.add_child(player)
	player.play(StartPosition)
	return player


func _KillTween(Player : AudioStreamPlayer) -> void:
	if Player.has_meta("kcdt_tween"):
		var old : Tween = Player.get_meta("kcdt_tween")
		if old and old.is_valid():
			old.kill()


func FadeIn(Player : AudioStreamPlayer) -> void:
	_KillTween(Player)
	var tween := Player.create_tween()
	Player.set_meta("kcdt_tween", tween)
	tween.tween_property(Player, "volume_db", TargetVolume, TweenSpeed) \
		.set_trans(FadeTransition).set_ease(FadeEase)


func FadeOut(Player : AudioStreamPlayer, Duration : float = -1.0) -> void:
	_KillTween(Player)
	if Duration < 0.0:
		Duration = TweenSpeed
	var tween := Player.create_tween()
	Player.set_meta("kcdt_tween", tween)
	tween.tween_property(Player, "volume_db", SilentDb, Duration) \
		.set_trans(FadeTransition).set_ease(FadeEase)
	tween.tween_callback(Player.queue_free)


func IsSameTrack(Player : AudioStreamPlayer) -> bool:
	if Player.stream == null or Music == null:
		return false
	if Player.has_meta("kcdt_source") and Player.get_meta("kcdt_source") == Music:
		return true
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
	var main := manager.get_node_or_null(MainTrackName) as AudioStreamPlayer
	if main == null:
		_Log("starting track")
		FadeIn(CreateTrack(manager, MainTrackName))
		music_started.emit(self)
		return
	if IsSameTrack(main):
		if RestartIfSame or not main.playing:
			main.volume_db = SilentDb
			main.play(StartPosition)
			FadeIn(main)
			music_started.emit(self)
		return
	_Log("crossfading to new track")
	main.name = "OldTrack"
	FadeOut(main, OldTrackFadeSpeed if OldTrackFadeSpeed >= 0.0 else TweenSpeed)
	FadeIn(CreateTrack(manager, MainTrackName))
	music_started.emit(self)
