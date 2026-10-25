extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://scenes/objects/player.tscn").instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().physics_frame
	var sprite := player.get_node("Sprite2D") as AnimatedSprite2D
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var collision_transform := collision.transform
	var art_scale := sprite.scale
	Input.action_press("move_right")
	await _wait_for_movement()
	_check(not sprite.flip_h, "moving right keeps the right-facing sprite unflipped")
	Input.action_release("move_right")
	await _wait_for_movement()
	_check(not sprite.flip_h, "stopping preserves the right-facing direction")
	Input.action_press("move_up")
	await _wait_for_movement()
	_check(not sprite.flip_h, "vertical movement preserves the right-facing direction")
	Input.action_release("move_up")
	Input.action_press("move_left")
	await _wait_for_movement()
	_check(sprite.flip_h, "moving left flips the right-facing sprite")
	Input.action_release("move_left")
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _wait_for_movement()
	_check(not sprite.flip_h, "diagonal movement right keeps the sprite unflipped")
	Input.action_release("move_up")
	Input.action_release("move_right")
	player.controls_enabled = false
	Input.action_press("move_left")
	await _wait_for_movement()
	_check(not sprite.flip_h and player.velocity == Vector2.ZERO, "disabled controls preserve the right-facing sprite and prevent movement")
	Input.action_release("move_left")
	_check(collision.transform == collision_transform, "facing changes do not flip the collision shape")
	_check(sprite.scale == art_scale, "facing changes preserve the authored sprite scale")
	_check(sprite.position == Vector2(2, -185), "facing changes preserve the authored sprite position")
	_check(art_scale == Vector2(0.5, 0.5), "sprite keeps its authored half scale")
	player.queue_free()
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Player facing verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _wait_for_movement() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
