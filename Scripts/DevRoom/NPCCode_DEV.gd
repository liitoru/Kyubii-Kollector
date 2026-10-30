extends Node3D
@export var InteractionArea : Area3D
@export var LookAtModifier : LookAtModifier3D
@export var face_mesh : Node3D
const BLINK_SHAPE := "Blink"
const BLINK_MIN_WAIT := 2.0
const BLINK_MAX_WAIT := 5.0
const BLINK_CLOSE_TIME := 0.06
const BLINK_OPEN_TIME := 0.10
const DOUBLE_BLINK_CHANCE := 0.15
var blink_index := -1

func _ready() -> void:
	if InteractionArea and LookAtModifier:
		InteractionArea.body_entered.connect(func(Body : Node3D):
			if Body.is_in_group("Player"):
				LookAtModifier.target_node = Body.get_path()
		)
		InteractionArea.body_exited.connect(func(Body):
			if Body.is_in_group("Player"):
				LookAtModifier.target_node = ""
		)
	if face_mesh:
		blink_index = face_mesh.find_blend_shape_by_name(BLINK_SHAPE)
	if blink_index >= 0:
		_blink_loop()

func _blink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(BLINK_MIN_WAIT, BLINK_MAX_WAIT)).timeout
		await _blink()
		if randf() < DOUBLE_BLINK_CHANCE:
			await get_tree().create_timer(0.12).timeout
			await _blink()
func _blink() -> void:
	var tween := create_tween()
	tween.tween_method(_set_blink, 0.0, 1.0, BLINK_CLOSE_TIME)
	tween.tween_method(_set_blink, 1.0, 0.0, BLINK_OPEN_TIME)
	await tween.finished

func _set_blink(value: float) -> void:
	face_mesh.set_blend_shape_value(blink_index, value)
