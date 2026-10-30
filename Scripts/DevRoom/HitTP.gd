extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(func(Body):
		if Body.is_in_group("Player"):
			Body.global_position = Vector3(0,0.5,0)
		)
