extends CharacterBody2D

@export var horizontal_speed: float = 260.0
@export_range(0.1, 1.0, 0.05) var vertical_speed_ratio: float = 0.55
var controls_enabled := true


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	direction.y *= vertical_speed_ratio
	velocity = direction.normalized() * horizontal_speed if direction.length_squared() > 1.0 else direction * horizontal_speed
	move_and_slide()
