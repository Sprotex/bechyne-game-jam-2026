extends CharacterBody2D

@export var horizontal_speed: float = 433.333
@export_range(0.1, 1.0, 0.05) var vertical_speed_ratio: float = 0.55
const SPRINT_SPEED_MULTIPLIER := 2.0
var controls_enabled := true:
	set(value):
		controls_enabled = value
		if not value:
			_set_footsteps_active(false)

var _footsteps_active := false


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		_set_footsteps_active(false)
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_set_footsteps_active(not direction.is_zero_approx())
	if not is_zero_approx(direction.x):
		$Sprite2D.flip_h = direction.x > 0.0
	direction.y *= vertical_speed_ratio
	var speed := horizontal_speed * SPRINT_SPEED_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else horizontal_speed
	velocity = direction.normalized() * speed if direction.length_squared() > 1.0 else direction * speed
	move_and_slide()


func _exit_tree() -> void:
	_set_footsteps_active(false)


func _set_footsteps_active(active: bool) -> void:
	if _footsteps_active == active:
		return
	_footsteps_active = active
	AudioManager.set_loop_active(&"footsteps", active)
