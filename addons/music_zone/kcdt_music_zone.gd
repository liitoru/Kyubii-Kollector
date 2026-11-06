@tool
@icon("icon.svg")
class_name KCDTMusicZone
extends Area3D
## KCDT Music Zone (by KCDT - Kyubii Collector Development Tools)
##
## An Area3D that crossfades background music when the player walks into it.
## It creates a real CollisionShape3D child for itself, so you resize and edit
## it with the normal editor tools. Tracks live under a "MusicManager" node,
## which is created automatically (if CanCreate is on) when none exists yet.

signal music_started(zone: KCDTMusicZone)
signal music_stopped(zone: KCDTMusicZone)
## Emitted when a counted loop (LoopCount > 0) has played all its repeats.
signal loops_finished(zone: KCDTMusicZone)

enum LoopOption { DEFAULT, FORCE_LOOP, NO_LOOP }
enum ExitAction { NOTHING, FADE_OUT_MUSIC }
enum AfterLoopsAction { PLAY_TO_END, FADE_OUT }

const SilentDb : float = -80.0
const MainTrackName : String = "MainTrack"
const ManagerName : String = "MusicManager"
const ManagerGroup : String = "MusicManager"

@export_group("Zone")
## Master switch. When off the zone never reacts to the player.
@export var Enabled : bool = true
## Whether the zone reacts to the player touching it.
@export var Touchable : bool = true
## Only bodies in this group trigger the zone. Empty = Project Settings default.
@export var PlayerGroup : StringName = &""
## After the first successful trigger the zone turns itself off.
@export var OneShot : bool = false
## Seconds to wait after touching before the music starts.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:s") var StartDelay : float = 0.0

@export_group("Collision")
## Adds a real CollisionShape3D child (4x4x4 box) if the zone doesn't have one.
## Select that child to resize it, change its shape, debug color and so on.
@export var AutoCreateShape : bool = true

@export_group("Music")
@export var Music : AudioStream
## Name of the audio bus the music is played on. Empty = Project Settings default.
@export var BusName : StringName = &""
## Volume the track fades up to.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var TargetVolume : float = 0.0
@export_range(0.5, 2.0, 0.01) var PitchScale : float = 1.0
## Where in the track playback starts, in seconds.
@export_range(0.0, 600.0, 0.1, "or_greater", "suffix:s") var StartPosition : float = 0.0
## If the same track is already playing, restart it instead of leaving it alone.
@export var RestartIfSame : bool = false

@export_group("Loop")
## DEFAULT keeps the stream's own loop setting. FORCE_LOOP unlocks the loop
## points below. NO_LOOP plays the track once.
@export var LoopMode : LoopOption = LoopOption.DEFAULT:
	set(value):
		LoopMode = value
		notify_property_list_changed()
		update_configuration_warnings()
## Where the loop jumps back to, in seconds. Everything before it plays once
## as an intro.
@export_range(0.0, 3600.0, 0.01, "or_greater", "suffix:s") var LoopStart : float = 0.0:
	set(value):
		LoopStart = value
		update_configuration_warnings()
## Where the loop ends, in seconds. 0 = the end of the track.
## Sample-accurate for WAV; OGG and MP3 jump within a frame or so of the point.
@export_range(0.0, 3600.0, 0.01, "or_greater", "suffix:s") var LoopEnd : float = 0.0:
	set(value):
		LoopEnd = value
		update_configuration_warnings()
## How many times the looped part repeats. 0 = forever. A counted loop is
## handled in script for every format, so WAV loses its sample accuracy.
@export_range(0, 999, 1, "or_greater") var LoopCount : int = 0:
	set(value):
		LoopCount = value
		notify_property_list_changed()
## What happens once a counted loop has finished repeating.
@export var AfterLoops : AfterLoopsAction = AfterLoopsAction.PLAY_TO_END

@export_group("Fade")
## Fade in / fade out duration in seconds. Negative = Project Settings default.
@export_range(-1.0, 60.0, 0.05, "or_greater", "suffix:s") var TweenSpeed : float = -1.0
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
	if AutoCreateShape:
		_EnsureShape.call_deferred()
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
	if not AutoCreateShape and not _HasShape():
		warnings.append("Turn on AutoCreateShape or add a CollisionShape3D child so the zone can detect the player.")
	if LoopMode == LoopOption.FORCE_LOOP and LoopEnd > 0.0 and LoopEnd <= LoopStart:
		warnings.append("LoopEnd must be greater than LoopStart (or 0 for the end of the track).")
	return warnings


## Loop settings only show when they apply.
func _validate_property(Property : Dictionary) -> void:
	var hide := false
	match Property.name:
		"LoopStart", "LoopEnd", "LoopCount":
			hide = LoopMode != LoopOption.FORCE_LOOP
		"AfterLoops":
			hide = LoopMode != LoopOption.FORCE_LOOP or LoopCount == 0
	if hide:
		Property.usage &= ~PROPERTY_USAGE_EDITOR


# --- Collision shape --------------------------------------------------------

func _HasShape() -> bool:
	for child in get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			return true
	return false


## Adds a normal CollisionShape3D child when the zone has none.
func _EnsureShape() -> void:
	if not is_inside_tree() or _HasShape():
		return
	var shape_node := KCDTMusicZoneShape.new() # a CollisionShape3D, starts as a 4x4x4 box
	shape_node.name = "CollisionShape3D"
	add_child(shape_node)
	if Engine.is_editor_hint():
		# Give it an owner so it shows in the scene tree and is saved with the scene.
		var scene_root := get_tree().edited_scene_root
		if scene_root != null and (scene_root == self or owner == scene_root):
			shape_node.owner = scene_root
		update_configuration_warnings()


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
	FadeOut(main, FadeTime if FadeTime >= 0.0 else _GetFadeTime())
	music_stopped.emit(self)


# --- Internals --------------------------------------------------------------

## Reads a value from Project Settings > kcdt/music_zone (set by the plugin).
func _Setting(Key : String, Fallback : Variant) -> Variant:
	return ProjectSettings.get_setting("kcdt/music_zone/" + Key, Fallback)


func _GetPlayerGroup() -> StringName:
	return PlayerGroup if PlayerGroup != &"" else StringName(_Setting("player_group", "Player"))


func _GetBusName() -> StringName:
	return BusName if BusName != &"" else StringName(_Setting("music_bus", "Music"))


func _GetFadeTime() -> float:
	return TweenSpeed if TweenSpeed >= 0.0 else float(_Setting("fade_time", 2.0))


func _ResolveBus() -> void:
	MusicBus = AudioServer.get_bus_index(_GetBusName())
	if MusicBus == -1:
		push_warning("KCDTMusicZone: audio bus '%s' doesn't exist, falling back to Master." % _GetBusName())


func _Log(Message : String) -> void:
	if DebugPrint or bool(_Setting("debug_print", false)):
		print("[KCDTMusicZone:%s] %s" % [name, Message])


func _OnBodyEntered(Body : Node3D) -> void:
	if not Enabled or not Touchable or not Body.is_in_group(_GetPlayerGroup()):
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
	if not Enabled or OnExit == ExitAction.NOTHING or not Body.is_in_group(_GetPlayerGroup()):
		return
	var manager := get_tree().get_first_node_in_group(ManagerGroup)
	if manager == null:
		return
	var main := manager.get_node_or_null(MainTrackName) as AudioStreamPlayer
	if main == null or not IsSameTrack(main):
		return # another zone's music is playing, leave it alone
	main.name = "OldTrack"
	FadeOut(main, ExitFadeSpeed if ExitFadeSpeed >= 0.0 else _GetFadeTime())
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


# --- Looping ----------------------------------------------------------------

## Returns the stream to play, with loop settings applied to a copy so the
## original resource is never modified.
func _PrepareStream() -> AudioStream:
	if Music == null or LoopMode == LoopOption.DEFAULT:
		return Music
	var copy := Music.duplicate() as AudioStream
	# A counted loop is done in script (see LoopWatcher), so native looping is off.
	var native_loop := LoopMode == LoopOption.FORCE_LOOP and LoopCount == 0
	if copy is AudioStreamOggVorbis:
		var ogg := copy as AudioStreamOggVorbis
		ogg.loop = native_loop
		ogg.loop_offset = LoopStart if native_loop else 0.0
	elif copy is AudioStreamMP3:
		var mp3 := copy as AudioStreamMP3
		mp3.loop = native_loop
		mp3.loop_offset = LoopStart if native_loop else 0.0
	elif copy is AudioStreamWAV:
		var wav := copy as AudioStreamWAV
		if native_loop:
			var end_time := LoopEnd if LoopEnd > LoopStart else wav.get_length()
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = int(LoopStart * wav.mix_rate)
			wav.loop_end = int(end_time * wav.mix_rate)
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return copy


## Adds a LoopWatcher when the loop can't be done natively: a loop end on
## OGG/MP3, or any counted loop.
func _AddLoopWatcher(Player : AudioStreamPlayer) -> void:
	if LoopMode != LoopOption.FORCE_LOOP or Player.stream == null:
		return
	var counted := LoopCount > 0
	var needs_end := LoopEnd > LoopStart and not (Player.stream is AudioStreamWAV)
	if not counted and not needs_end:
		return
	var end_time := LoopEnd if LoopEnd > LoopStart else Player.stream.get_length()
	if end_time <= LoopStart:
		return
	var watcher := LoopWatcher.new()
	watcher.name = "LoopWatcher"
	watcher.LoopStart = LoopStart
	watcher.LoopEnd = end_time
	watcher.LoopCount = LoopCount
	watcher.OnFinished = _OnLoopsFinished.bind(Player)
	Player.add_child(watcher)


func _OnLoopsFinished(Player : AudioStreamPlayer) -> void:
	_Log("loops finished")
	loops_finished.emit(self)
	if AfterLoops == AfterLoopsAction.FADE_OUT and is_instance_valid(Player):
		Player.name = "OldTrack"
		FadeOut(Player)
		music_stopped.emit(self)


## Loops an AudioStreamPlayer between two points. Lives under the player, so
## it goes away with the track. Used for loop ends on OGG/MP3 and counted loops.
class LoopWatcher extends Node:
	var LoopStart : float = 0.0
	var LoopEnd : float = 0.0
	## 0 = forever.
	var LoopCount : int = 0
	var OnFinished : Callable

	var _Player : AudioStreamPlayer
	var _Jumps : int = 0
	var _Cooldown : float = 0.0

	func _ready() -> void:
		_Player = get_parent() as AudioStreamPlayer
		set_process(_Player != null and LoopEnd > LoopStart)

	func _process(Delta : float) -> void:
		if _Cooldown > 0.0:
			_Cooldown -= Delta
			return
		if not _Player.playing:
			return
		var pos := _Player.get_playback_position() + AudioServer.get_time_since_last_mix()
		if pos < LoopEnd:
			return
		if LoopCount > 0 and _Jumps >= LoopCount:
			set_process(false)
			if OnFinished.is_valid():
				OnFinished.call()
			return
		_Jumps += 1
		# Keep the overshoot so the loop doesn't drift a little each pass.
		_Player.seek(minf(LoopStart + (pos - LoopEnd), LoopEnd))
		_Cooldown = 0.05


# --- Tracks and fading ------------------------------------------------------

func CreateTrack(Manager : Node, TrackName : String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = TrackName
	player.stream = _PrepareStream()
	# Remember the original resource so IsSameTrack still works on loop copies.
	player.set_meta("kcdt_source", Music)
	player.volume_db = SilentDb
	player.pitch_scale = PitchScale
	if MusicBus != -1:
		player.bus = _GetBusName()
	Manager.add_child(player)
	player.play(StartPosition)
	_AddLoopWatcher(player)
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
	tween.tween_property(Player, "volume_db", TargetVolume, _GetFadeTime()) \
		.set_trans(FadeTransition).set_ease(FadeEase)


func FadeOut(Player : AudioStreamPlayer, Duration : float = -1.0) -> void:
	_KillTween(Player)
	if Duration < 0.0:
		Duration = _GetFadeTime()
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
	FadeOut(main, OldTrackFadeSpeed if OldTrackFadeSpeed >= 0.0 else _GetFadeTime())
	FadeIn(CreateTrack(manager, MainTrackName))
	music_started.emit(self)
