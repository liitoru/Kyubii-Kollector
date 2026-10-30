extends Node3D

@export var rotation_speed: float = 180.0
@export var bob_height: float = 0.05
@export var bob_speed: float = 2.0

@export var Ppawcoin: Node3D
@export var pawcoin: Node3D
@export var pawcoinLod1: Node3D
@export var pawcoinLod2: Node3D
@export var pawcoinLod3: Node3D

## Distance thresholds
@export var lod1_distance: float = 5.0
@export var lod2_distance: float = 10.0
@export var lod3_distance: float = 20.0

## Check intervals
@export var near_check_interval: float = 0.1
@export var medium_check_interval: float = 0.4
@export var far_check_interval: float = 1.0
@export var very_far_check_interval: float = 2.0

@export var PickupArea : Area3D

var start_y: float
var time_offset: float
var elapsed_time: float = 0.0
var lod_check_timer: float = 0.0

var lod_nodes: Array[Node3D] = []
var current_lod: int = -1

var PickedUp = false
func _ready() -> void:
	start_y = Ppawcoin.position.y
	time_offset = randf_range(0.0, TAU)

	lod_nodes = [
		pawcoin,
		pawcoinLod1,
		pawcoinLod2,
		pawcoinLod3
	]
	
	if PickupArea:
		PickupArea.body_entered.connect(func(Body):
			if Body.is_in_group("Player") and PickedUp == false:
				PickedUp = true
				var tween = create_tween()
				
				tween.tween_property(Ppawcoin, "scale", Vector3(0,0,0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
				#TODO ADD PICKUP CONNECTION AND ADD COIN TO PLAYER
				tween.tween_callback(self.queue_free)
			
			pass)
	
	for i in range(lod_nodes.size()):
		if not is_instance_valid(lod_nodes[i]):
			push_warning("Coin LOD %d is not assigned!" % i)

	_set_lod(0)


func _process(delta: float) -> void:
	elapsed_time += delta

	Ppawcoin.rotate_y(deg_to_rad(rotation_speed) * delta)

	Ppawcoin.position.y = start_y + sin(
		elapsed_time * bob_speed + time_offset
	) * bob_height

	lod_check_timer += delta

	var camera := get_viewport().get_camera_3d()

	if not is_instance_valid(camera):
		return

	var distance := camera.global_position.distance_to(
		global_position
	)

	var check_interval: float

	if distance < lod1_distance:
		check_interval = near_check_interval
	elif distance < lod2_distance:
		check_interval = medium_check_interval
	elif distance < lod3_distance:
		check_interval = far_check_interval
	else:
		check_interval = very_far_check_interval

	if lod_check_timer < check_interval:
		return

	lod_check_timer = 0.0

	var lod_index: int = 0

	if distance >= lod3_distance:
		lod_index = 3
	elif distance >= lod2_distance:
		lod_index = 2
	elif distance >= lod1_distance:
		lod_index = 1

	if lod_index != current_lod:
		#print("Coin distance: %.1f | Switching to LOD %d" % [
		#	distance, lod_index
		#])debugging
		_set_lod(lod_index)


func _set_lod(index: int) -> void:
	for i in range(lod_nodes.size()):
		var lod := lod_nodes[i]

		if not is_instance_valid(lod):
			continue

		lod.visible = (i == index)

	current_lod = index
