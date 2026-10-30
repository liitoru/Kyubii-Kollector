extends CharacterBody3D

const MAX_SPEED := 2.0
const GROUND_ACCEL := 30.0
const GROUND_FRICTION := 38.0
const AIR_ACCEL := 10.0
const AIR_FRICTION := 1.5
const TURN_SHARPNESS := 12.0

const MAX_JUMPS := 2
const JUMP_VELOCITY := 3.5
const DOUBLE_JUMP_VELOCITY := 6.0
const JUMP_CUT := 0.45
const FALL_GRAVITY_MULT := 1.6
const TERMINAL_VELOCITY := -25.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12


const ALIGN_SPEED := 10.0
const WALK_BLEND_SPEED := 6.0
const AIR_BLEND_SPEED := 8.0


const CAM_HEIGHT := 0.5
const CAM_Y_SMOOTH := 10.0
const PITCH_MIN := -80.0
const PITCH_MAX := 60.0

const LOOK_SMOOTH := 8.0
const LOOK_FRONT_ANGLE := 80.0
const LOOK_HEIGHT := 1.5

const BLINK_SHAPE := "Blink"
const BLINK_MIN_WAIT := 2.0
const BLINK_MAX_WAIT := 5.0
const BLINK_CLOSE_TIME := 0.06
const BLINK_OPEN_TIME := 0.10
const DOUBLE_BLINK_CHANCE := 0.15

@export var face_mesh: MeshInstance3D

var Sensitivity := 0.003
var facing_yaw := 0.0
var ground_offset := -0.04

var jumps_used := 0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0

var DampedAnimF := 0.0
var DampedWalking := 0.0

var cam_y := 0.0
var look_dir := Vector3.FORWARD

var blink_index := -1

@onready var camera_arm: SpringArm3D = $CameraArm
@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var Model: Node3D = $CharacterPivot
@onready var main_character: Node3D = $CharacterPivot/MainCharacter
@onready var character_anim_tree: AnimationTree = $CharacterPivot/MainCharacter/CharacterAnimTree
@onready var positon_ray_cast: RayCast3D = $CharacterPivot/PositonRayCast


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_arm.top_level = true
	camera_arm.add_excluded_object(self)
	cam_y = global_position.y + CAM_HEIGHT

	if face_mesh:
		blink_index = face_mesh.find_blend_shape_by_name(BLINK_SHAPE)
	if blink_index >= 0:
		_blink_loop()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)


func _physics_process(delta: float) -> void:
	_update_camera_position(delta)
	_snap_character_to_ground()

	var grounded := is_on_floor()

	_apply_gravity(grounded, delta)
	_handle_jump(grounded, delta)
	var h_vel := _handle_horizontal_movement(grounded, delta)
	_update_facing(h_vel, delta)
	_update_animation(h_vel, grounded, delta)

	move_and_slide()

	var target_normal := get_floor_normal() if is_on_floor() else Vector3.UP
	align_with_surface(target_normal, delta)
	update_look_target(delta)


func _rotate_camera(relative: Vector2) -> void:
	camera_arm.rotation.y -= relative.x * Sensitivity
	camera_arm.rotation.x -= relative.y * Sensitivity
	camera_arm.rotation.x = clampf(camera_arm.rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func _update_camera_position(delta: float) -> void:
	var target_y := global_position.y + CAM_HEIGHT
	cam_y = lerpf(cam_y, target_y, 1.0 - exp(-CAM_Y_SMOOTH * delta))
	camera_arm.global_position = Vector3(global_position.x, cam_y, global_position.z)


func _snap_character_to_ground() -> void:
	if positon_ray_cast.is_colliding():
		var hit_y: float = positon_ray_cast.get_collision_point().y
		main_character.global_position.y = hit_y + ground_offset


func _apply_gravity(grounded: bool, delta: float) -> void:
	if grounded:
		return
	var g := get_gravity() * delta
	if velocity.y < 0.0:
		g *= FALL_GRAVITY_MULT
	velocity += g
	velocity.y = maxf(velocity.y, TERMINAL_VELOCITY)


func _handle_jump(grounded: bool, delta: float) -> void:

	coyote_timer = COYOTE_TIME if grounded else coyote_timer - delta
	jump_buffer_timer -= delta
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER

	if grounded and velocity.y <= 0.0:
		jumps_used = 0
	elif not grounded and coyote_timer <= 0.0:
		jumps_used = maxi(jumps_used, 1)

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			_do_jump(JUMP_VELOCITY)
			jumps_used = 1
		elif jumps_used < MAX_JUMPS:
			_do_jump(DOUBLE_JUMP_VELOCITY)
			jumps_used += 1

	if Input.is_action_just_released("ui_accept") and velocity.y > 0.0:
		velocity.y *= JUMP_CUT


func _do_jump(jump_velocity: float) -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _handle_horizontal_movement(grounded: bool, delta: float) -> Vector3:
	var input_dir := Input.get_vector("IN_Left", "IN_Right", "IN_Forward", "IN_Backward")
	var yaw_basis := Basis(Vector3.UP, camera_arm.rotation.y)
	var direction := yaw_basis * Vector3(input_dir.x, 0, input_dir.y)

	var h_vel := Vector3(velocity.x, 0, velocity.z)
	var target_vel := direction * MAX_SPEED

	var rate: float
	if direction.length() > 0.01:
		rate = GROUND_ACCEL if grounded else AIR_ACCEL
	else:
		rate = GROUND_FRICTION if grounded else AIR_FRICTION

	h_vel = h_vel.move_toward(target_vel, rate * delta)
	velocity.x = h_vel.x
	velocity.z = h_vel.z
	return h_vel


func _update_facing(h_vel: Vector3, delta: float) -> void:
	if h_vel.length() > 0.5:
		var target_yaw := atan2(-h_vel.x, -h_vel.z)
		facing_yaw = lerp_angle(facing_yaw, target_yaw, 1.0 - exp(-TURN_SHARPNESS * delta))


func align_with_surface(normal: Vector3, delta: float) -> void:
	var up := normal.normalized()
	var target_basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, facing_yaw)
	var current_q := Model.global_transform.basis.get_rotation_quaternion()
	var target_q := target_basis.get_rotation_quaternion()
	var new_q := current_q.slerp(target_q, clampf(ALIGN_SPEED * delta, 0.0, 1.0))
	Model.global_transform.basis = Basis(new_q)


func _update_animation(h_vel: Vector3, grounded: bool, delta: float) -> void:
	var walk_target := clampf(h_vel.length() / MAX_SPEED, 0.0, 1.0)
	DampedWalking = move_toward(DampedWalking, walk_target, WALK_BLEND_SPEED * delta)
	DampedAnimF = move_toward(DampedAnimF, 1.0 if grounded else -1.0, AIR_BLEND_SPEED * delta)
	character_anim_tree.set("parameters/Movement/blend_position", Vector2(DampedWalking, DampedAnimF))


func update_look_target(delta: float) -> void:
	var head_pos := global_position + Vector3(0, LOOK_HEIGHT, 0)
	var facing := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))

	var to_cam := camera.global_position - head_pos
	var flat := Vector3(to_cam.x, 0, to_cam.z)
	var cam_in_front := flat.length() > 0.01 \
		and rad_to_deg(facing.angle_to(flat.normalized())) < LOOK_FRONT_ANGLE

	var desired_dir: Vector3
	if cam_in_front:
		desired_dir = to_cam.normalized()
	else:
		desired_dir = -camera.global_basis.z

	var t := 1.0 - exp(-LOOK_SMOOTH * delta)
	var blended := look_dir.lerp(desired_dir, t)
	look_dir = blended.normalized() if blended.length() > 0.001 else desired_dir


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
