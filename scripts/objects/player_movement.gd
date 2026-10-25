extends CharacterBody2D

@export var horizontal_speed: float = 433.333
@export_range(0.1, 1.0, 0.05) var vertical_speed_ratio: float = 0.55
const SPRINT_SPEED_MULTIPLIER := 2.0
const FOOTSTEP_CONTACT_FRAMES := [0, 8]

@onready var sprite: AnimatedSprite2D = $Sprite2D

var _footstep_player: AudioStreamPlayer
var _walking := false
var _starting_walk := false

var controls_enabled := true:
	set(value):
		controls_enabled = value
		if not value:
			_stop_walking()


func _ready() -> void:
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.bus = &"Sound"
	_footstep_player.stream = AudioManager._get_sound_stream(&"footsteps")
	add_child(_footstep_player)
	sprite.frame_changed.connect(_on_sprite_frame_changed)


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		_stop_walking()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	direction.y *= vertical_speed_ratio
	var speed := horizontal_speed * SPRINT_SPEED_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else horizontal_speed
	velocity = direction.normalized() * speed if direction.length_squared() > 1.0 else direction * speed
	move_and_slide()
	var moved := get_position_delta().length_squared() > 0.01
	if moved:
		_start_walking_if_needed()
		sprite.speed_scale = SPRINT_SPEED_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0
	else:
		_stop_walking()


func _exit_tree() -> void:
	if is_instance_valid(_footstep_player):
		_footstep_player.stop()


func _start_walking_if_needed() -> void:
	if _walking:
		return
	_walking = true
	sprite.speed_scale = 1.0
	_starting_walk = true
	sprite.play(&"walk")
	_starting_walk = false
	_play_footstep_for_contact_frame()


func _stop_walking() -> void:
	if not _walking:
		return
	_walking = false
	sprite.stop()
	sprite.play(&"idle")
	if is_instance_valid(_footstep_player):
		_footstep_player.stop()


func _on_sprite_frame_changed() -> void:
	if _walking and not _starting_walk:
		_play_footstep_for_contact_frame()


func _play_footstep_for_contact_frame() -> void:
	if sprite.animation != &"walk" or not FOOTSTEP_CONTACT_FRAMES.has(sprite.frame):
		return
	if is_instance_valid(_footstep_player) and _footstep_player.stream != null:
		_footstep_player.play()
