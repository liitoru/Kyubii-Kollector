extends CharacterBody3D

##Movement
const MAX_SPEED := 2.0
const GROUND_ACCEL := 30.0
const GROUND_FRICTION := 38.0
const AIR_ACCEL := 10.0
const AIR_FRICTION := 1.5
const TURN_SHARPNESS := 12.0

##Jumping and gravity
const MAX_JUMPS := 2
const JUMP_VELOCITY := 3.5
const DOUBLE_JUMP_VELOCITY := 6.0
const JUMP_CUT := 0.45
const FALL_GRAVITY_MULT := 1.6

const SNAP_FALL_GRAVITY_MULT := 2.2
const TERMINAL_VELOCITY := -25.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12

## Stuff for combos
const COMBO_TIMES := [0.28, 0.28, 0.45]   # duration of each hit
const COMBO_NAMES := ["Paw swipe 1", "Paw swipe 2", "Tail swipe"]
const COMBO_LUNGE := 1.5                  # small step forward on each hit
const ATTACK_FRICTION := 8.0              # how fast the lunge fades


const AIR_SPIN_TIME := 0.5
const BOUNCE_VELOCITY := 5.0              # launch when the spin hits an enemy
const SPIN_SPEED := TAU * 3.0             # placeholder until anim exists

## AIRDASHING
const DASH_SPEED := 7.0
const DASH_TIME := 0.18
const DASH_EXIT_SPEED := 2.5              # speed kept after the dash ends

const ENEMY_GROUP := "enemy"

##Camera stuff
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

# What the character is doing right now
enum State { NORMAL, GROUND_COMBO, AIR_SPIN, AIR_DASH }
# LIFE IS PAIN
# Transformations. TODO: add transformations here (each one can change mesh, stats, moves)
enum Form { BASE }

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

var state: State = State.NORMAL
var state_timer := 0.0
var combo_step := 0
var combo_queued := false
var air_dash_used := false
var snappy_fall := false
var dash_dir := Vector3.FORWARD
var is_invincible := false   # TODO: hook up to the damage system (true during airdash = air dodge)
var hit_targets: Array = []  # enemies already hit by the current swing
var spin_angle := 0.0
var main_base_yaw := 0.0
var form: Form = Form.BASE

@onready var debuglabel: Label3D = $DEBUGLABEL

@onready var camera_arm: SpringArm3D = $CameraArm
@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var Model: Node3D = $CharacterPivot
@onready var main_character: Node3D = $CharacterPivot/MainCharacter
@onready var character_anim_tree: AnimationTree = $CharacterPivot/MainCharacter/CharacterAnimTree
@onready var positon_ray_cast: RayCast3D = $CharacterPivot/PositonRayCast
# TODO: add an Area3D named AttackHitbox under CharacterPivot (in front of the character).
# Until it exists attacks still play but won't hit anything.
@onready var attack_hitbox: Area3D = get_node_or_null("CharacterPivot/AttackHitbox") as Area3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_arm.top_level = true
	camera_arm.add_excluded_object(self)
	cam_y = global_position.y + CAM_HEIGHT
	main_base_yaw = main_character.rotation.y

	if attack_hitbox:
		attack_hitbox.monitoring = false

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
	if grounded:
		# Landing refills everything
		air_dash_used = false
		snappy_fall = false

	_tick_state(grounded, delta)
	_handle_actions(grounded)
	_apply_gravity(grounded, delta)
	_handle_jump(grounded, delta)
	var h_vel := _handle_horizontal_movement(grounded, delta)
	_update_facing(h_vel, delta)
	_update_animation(h_vel, grounded, delta)

	move_and_slide()

	var target_normal := get_floor_normal() if is_on_floor() else Vector3.UP
	align_with_surface(target_normal, delta)
	update_look_target(delta)

	_process_hits()
	_update_spin_visual(delta)
	_update_debug(is_on_floor())



func _pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


# Movement input in world space (relative to the camera yaw)
func _input_direction() -> Vector3:
	var input_dir := Input.get_vector("IN_Left", "IN_Right", "IN_Forward", "IN_Backward")
	var yaw_basis := Basis(Vector3.UP, camera_arm.rotation.y)
	return yaw_basis * Vector3(input_dir.x, 0, input_dir.y)


func _facing_vector() -> Vector3:
	return Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

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


func _handle_actions(grounded: bool) -> void:
	var attack := _pressed("IN_Attack")
	var dash := _pressed("IN_Dash")

	if _pressed("IN_Transform") and state == State.NORMAL:
		_cycle_form()

	match state:
		State.NORMAL:
			if attack:
				if grounded:
					_start_combo_step(0)
				else:
					_start_air_spin()
			elif dash and not grounded and not air_dash_used:
				_start_air_dash()
		State.GROUND_COMBO:
			# Press again during a hit to chain into the next one
			if attack:
				combo_queued = true
		State.AIR_SPIN:
			# Can dash out of the spin
			if dash and not air_dash_used:
				_start_air_dash()


# Ends or advances timed states
func _tick_state(grounded: bool, delta: float) -> void:
	if state == State.NORMAL:
		return
	state_timer -= delta

	match state:
		State.GROUND_COMBO:
			if not grounded:
				_set_state(State.NORMAL)  # walked off a ledge mid-combo
			elif state_timer <= 0.0:
				if combo_queued and combo_step < COMBO_TIMES.size() - 1:
					_start_combo_step(combo_step + 1)
				else:
					_set_state(State.NORMAL)
		State.AIR_SPIN:
			if grounded or state_timer <= 0.0:
				_set_state(State.NORMAL)
		State.AIR_DASH:
			if grounded or state_timer <= 0.0:
				_end_air_dash()


func _set_state(new_state: State, duration := 0.0) -> void:
	state = new_state
	state_timer = duration
	hit_targets.clear()
	is_invincible = new_state == State.AIR_DASH
	if attack_hitbox:
		attack_hitbox.set_deferred("monitoring", new_state == State.GROUND_COMBO or new_state == State.AIR_SPIN)


func _start_combo_step(step: int) -> void:
	combo_step = step
	combo_queued = false
	_set_state(State.GROUND_COMBO, COMBO_TIMES[step])

	# Face the stick direction (if any) and step into the hit
	var dir := _input_direction()
	if dir.length() > 0.01:
		facing_yaw = atan2(-dir.x, -dir.z)
	var f := _facing_vector()
	velocity.x = f.x * COMBO_LUNGE
	velocity.z = f.z * COMBO_LUNGE
	# TODO: play the matching attack animation (paw 1, paw 2, tail swipe) on the anim tree


func _start_air_spin() -> void:
	velocity.y = minf(velocity.y, 0.0)
	snappy_fall = true
	spin_angle = 0.0
	_set_state(State.AIR_SPIN, AIR_SPIN_TIME)
	# TODO: play spin animation (the code spins the model for now)


func _bounce_off_enemy() -> void:
	velocity.y = BOUNCE_VELOCITY
	jumps_used = 1          # refund the double jump
	air_dash_used = false   # refund the airdash
	snappy_fall = false
	_set_state(State.NORMAL)


func _start_air_dash() -> void:
	var dir := _input_direction()
	dash_dir = dir.normalized() if dir.length() > 0.01 else _facing_vector()
	air_dash_used = true
	velocity.y = 0.0
	_set_state(State.AIR_DASH, DASH_TIME)
	# TODO: dash animation / trail effect


func _end_air_dash() -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	if h.length() > DASH_EXIT_SPEED:
		h = h.normalized() * DASH_EXIT_SPEED
	velocity.x = h.x
	velocity.z = h.z
	snappy_fall = true
	_set_state(State.NORMAL)


# Checks the attack hitbox for enemies (group "enemy")
func _process_hits() -> void:
	if attack_hitbox == null:
		return
	if state != State.GROUND_COMBO and state != State.AIR_SPIN:
		return

	var targets: Array = []
	targets.append_array(attack_hitbox.get_overlapping_bodies())
	targets.append_array(attack_hitbox.get_overlapping_areas())

	for t in targets:
		if not t.is_in_group(ENEMY_GROUP) or t in hit_targets:
			continue
		hit_targets.append(t)
		if t.has_method("take_hit"):
			t.take_hit(1, global_position)  # TODO: per-move damage / knockback values
		if state == State.AIR_SPIN:
			_bounce_off_enemy()
			break


# Placeholder visual spin for the air attack
#TODO: REALLY ADD THE ANIMATION!!
func _update_spin_visual(delta: float) -> void:
	if state == State.AIR_SPIN:
		spin_angle += SPIN_SPEED * delta
		main_character.rotation.y = main_base_yaw + spin_angle
	elif spin_angle != 0.0:
		spin_angle = 0.0
		main_character.rotation.y = main_base_yaw


func _cycle_form() -> void:
	var next := (int(form) + 1) % Form.size()
	_apply_form(next as Form)


func _apply_form(new_form: Form) -> void:
	form = new_form
	# TODO: swap mesh/skeleton, change stats and unlock form-specific moves



func _apply_gravity(grounded: bool, delta: float) -> void:
	if grounded:
		return
	if state == State.AIR_DASH:
		return  # dash is flat, no gravity
	var g := get_gravity() * delta
	if snappy_fall:
		g *= SNAP_FALL_GRAVITY_MULT
	elif velocity.y < 0.0:
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

	if jump_buffer_timer > 0.0 and state != State.AIR_DASH:
		if coyote_timer > 0.0:
			_do_jump(JUMP_VELOCITY)
			jumps_used = 1
		elif jumps_used < MAX_JUMPS:
			_do_jump(DOUBLE_JUMP_VELOCITY)
			jumps_used += 1
			snappy_fall = true  

	if Input.is_action_just_released("ui_accept") and velocity.y > 0.0:
		velocity.y *= JUMP_CUT


func _do_jump(jump_velocity: float) -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	# Jumping cancels attacks
	if state == State.GROUND_COMBO or state == State.AIR_SPIN:
		_set_state(State.NORMAL)


func _handle_horizontal_movement(grounded: bool, delta: float) -> Vector3:
	# Airdash overrides movement completely
	if state == State.AIR_DASH:
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		return Vector3(velocity.x, 0, velocity.z)

	var direction := _input_direction()
	var attacking_on_ground := state == State.GROUND_COMBO

	# No steering during ground attacks, just the lunge fading out
	if attacking_on_ground:
		direction = Vector3.ZERO

	var h_vel := Vector3(velocity.x, 0, velocity.z)
	var target_vel := direction * MAX_SPEED

	var rate: float
	if attacking_on_ground:
		rate = ATTACK_FRICTION
	elif direction.length() > 0.01:
		rate = GROUND_ACCEL if grounded else AIR_ACCEL
	else:
		rate = GROUND_FRICTION if grounded else AIR_FRICTION

	h_vel = h_vel.move_toward(target_vel, rate * delta)
	velocity.x = h_vel.x
	velocity.z = h_vel.z
	return h_vel


func _update_facing(h_vel: Vector3, delta: float) -> void:
	if state == State.GROUND_COMBO:
		return  # keep the direction the hit started in
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


# Debug

func _update_debug(grounded: bool) -> void:
	var what: String = State.keys()[state]
	if state == State.GROUND_COMBO:
		what = COMBO_NAMES[combo_step]
	debuglabel.text = "%s\n%s | %s\njumps %d/%d | dash %s" % [
		Form.keys()[form],
		what,
		"grounded" if grounded else "air",
		jumps_used, MAX_JUMPS,
		"used" if air_dash_used else "ready",
	]



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
