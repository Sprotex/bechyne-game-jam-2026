extends Node

var failures := 0
var finished_steps := 0
var changed_frames := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://scenes/objects/player.tscn").instantiate() as CharacterBody2D
	player.position = Vector2(-150, 300)
	add_child(player)
	await get_tree().physics_frame
	var sprite := player.get_node("Sprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	_check(sprite.animation == &"idle" and sprite.frame == 0, "player starts on the original single-frame idle pose")
	_check(frames.get_frame_count(&"walk") == 16, "walk animation has 16 frames")
	_check(is_equal_approx(frames.get_animation_speed(&"walk"), 16.0), "walk animation runs at 16 frames per second")
	_check(_walk_frames_are_ordered(frames), "walk frames are ordered from walk_01 through walk_16")
	_check(frames.get_frame_count(&"idle") == 1, "idle keeps the original borka texture")
	var audio_player := player.get("_footstep_player") as AudioStreamPlayer
	_check(audio_player != null and audio_player.stream == AudioManager._get_sound_stream(&"footsteps"), "player uses the registered footstep clip")
	if audio_player != null:
		audio_player.finished.connect(_on_footstep_finished)
	await _check_wall_block(player, sprite, audio_player)
	await _check_walking(player, sprite, audio_player)
	await _check_sprint_cadence(player, sprite)
	await _check_modal_stop(player, sprite, audio_player)
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")
	_set_shift(false)
	player.queue_free()
	AudioManager.stop_sound_effects()
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stop()
		AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Player animation verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_wall_block(player: CharacterBody2D, sprite: AnimatedSprite2D, audio_player: AudioStreamPlayer) -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(0, 300)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 300)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	add_child(wall)
	Input.action_press(&"move_right")
	await get_tree().create_timer(0.5).timeout
	var stopped_position := player.position
	await get_tree().create_timer(0.1).timeout
	_check(absf(player.position.x - stopped_position.x) < 0.5, "wall collision prevents actual player motion")
	_check(sprite.animation == &"idle" and not audio_player.playing, "wall contact keeps idle animation and footstep audio silent")
	_check(not AudioManager.looping_players.has(&"footsteps"), "movement does not create a held-input footsteps loop")
	Input.action_release(&"move_right")
	wall.queue_free()
	player.position = Vector2(-150, 300)
	await get_tree().physics_frame


func _check_walking(player: CharacterBody2D, sprite: AnimatedSprite2D, audio_player: AudioStreamPlayer) -> void:
	finished_steps = 0
	changed_frames = 0
	sprite.frame_changed.connect(_on_frame_changed)
	var start_position := player.position
	Input.action_press(&"move_right")
	await get_tree().create_timer(0.36).timeout
	_check(player.position.x > start_position.x + 40.0, "free horizontal movement advances the player")
	_check(sprite.animation == &"walk" and sprite.is_playing(), "actual movement plays the walk animation")
	_check(changed_frames >= 4, "walk animation advances through frames while moving")
	_check(finished_steps == 1 and not audio_player.playing, "only the initial contact produces a footstep during non-contact frames")
	_check(not AudioManager.looping_players.has(&"footsteps"), "walking stays out of the AudioManager loop registry")
	await get_tree().create_timer(0.38).timeout
	_check(finished_steps == 2, "the next footstep is emitted at the second contact frame")
	Input.action_release(&"move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(sprite.animation == &"idle" and sprite.frame == 0, "stopping movement returns to the static idle pose")
	var idle_frame := sprite.frame
	await get_tree().create_timer(0.15).timeout
	_check(sprite.animation == &"idle" and sprite.frame == idle_frame, "idle remains stopped after movement ends")
	sprite.frame_changed.disconnect(_on_frame_changed)


func _check_sprint_cadence(player: CharacterBody2D, sprite: AnimatedSprite2D) -> void:
	var normal_changes := await _measure_frame_changes(player, sprite, false)
	var sprint_changes := await _measure_frame_changes(player, sprite, true)
	_check(sprint_changes > normal_changes, "holding Shift doubles the walk animation cadence")
	_check(sprint_changes >= normal_changes * 1.7, "sprint cadence is close to twice the walking cadence")


func _measure_frame_changes(player: CharacterBody2D, sprite: AnimatedSprite2D, sprint: bool) -> int:
	changed_frames = 0
	sprite.frame_changed.connect(_on_frame_changed)
	player.position = Vector2(-400, player.position.y)
	Input.action_press(&"move_right")
	_set_shift(sprint)
	await get_tree().create_timer(0.5).timeout
	Input.action_release(&"move_right")
	_set_shift(false)
	await get_tree().physics_frame
	sprite.frame_changed.disconnect(_on_frame_changed)
	return changed_frames


func _check_modal_stop(player: CharacterBody2D, sprite: AnimatedSprite2D, audio_player: AudioStreamPlayer) -> void:
	player.controls_enabled = true
	Input.action_press(&"move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(sprite.animation == &"walk", "player is walking before modal controls are disabled")
	player.controls_enabled = false
	_check(not audio_player.playing, "disabling controls stops footstep audio immediately")
	_check(sprite.animation == &"idle", "disabling controls stops walk animation immediately")
	await get_tree().physics_frame
	_check(player.velocity == Vector2.ZERO, "disabled modal controls stop player motion")
	Input.action_release(&"move_right")
	player.controls_enabled = true


func _walk_frames_are_ordered(frames: SpriteFrames) -> bool:
	for index in range(16):
		var expected := "walk_%02d.png" % (index + 1)
		var texture := frames.get_frame_texture(&"walk", index)
		if texture == null or not texture.resource_path.ends_with(expected):
			return false
	return true


func _on_footstep_finished() -> void:
	finished_steps += 1


func _on_frame_changed() -> void:
	changed_frames += 1


func _set_shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
