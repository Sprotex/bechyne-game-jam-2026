extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/rooms/bathroom.tscn") as PackedScene
	var room_state := packed.get_state()
	_check(room_state.get_node_count() == 15, "bathroom keeps 15 declared nodes")
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	level.dialog_manager.hide_dialog()
	level._load_room("res://scenes/rooms/bathroom.tscn", "from_entrance")
	await get_tree().physics_frame
	var room := level.room
	var background := room.get_node("Background") as Sprite2D
	_check(background.texture.get_size() == Vector2(2000, 563), "bathroom background uses the replacement artwork dimensions")
	_check(room.get_node("PhotoCamera").position == Vector2(1020, 435), "camera pickup keeps its authored position")
	_check(room.get_node("CameraPhotoSpot").position == Vector2(1220, 430), "photo spot keeps its authored position")
	_check(room.get_node("ExitToEntrance").destination_arrival_id == "from_bathroom", "bathroom exit keeps its arrival ID")
	_check(room.get_node("Arrivals/from_entrance").position == Vector2(350, 375), "entrance arrival stays at its authored position")
	_check(room.get_node("TestInteractor").position == Vector2(760, 405), "TestInteractor stays in place")
	var player := level.get_node("Player") as CharacterBody2D
	await _check_blocked(player, Vector2(760, 420), Vector2(0, -100), "sink feet collision blocks approach")
	await _check_blocked(player, Vector2(1042, 430), Vector2(0, -100), "basket feet collision blocks approach")
	await _check_blocked(player, Vector2(1235, 430), Vector2(0, -100), "cabinet feet collision blocks approach")
	await _check_blocked(player, Vector2(1750, 495), Vector2(0, -80), "shower foot collision blocks approach")
	await _check_blocked(player, Vector2(125, 570), Vector2(0, -80), "toilet feet collision blocks approach")
	player.global_position = Vector2(350, 495)
	await get_tree().physics_frame
	_check(not player.test_move(player.global_transform, Vector2(1500, 0)), "lower route from the entrance stays clear through the right side")
	level.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = self
	AudioManager.stop_sound_effects()
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stop()
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Bathroom replacement verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_blocked(player: CharacterBody2D, origin: Vector2, motion: Vector2, label: String) -> void:
	player.global_position = origin
	await get_tree().physics_frame
	_check(player.test_move(player.global_transform, motion), label)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
