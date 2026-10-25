extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	_check_story_flag_gating_and_one_shot(level)
	await _check_story_interactor(level)
	await _check_locked_exit(level)
	await _check_camera_pickup_hint(level)
	await _check_pickup_sound_ids(level)
	level.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = self
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Story verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_story_flag_gating_and_one_shot(level: Level) -> void:
	var story := StoryText.new()
	story.messages = ["Přečteš zprávu."]
	story.locked_messages = ["Zpráva je zatím zamčená."]
	story.required_flag = "story.key_found"
	story.completed_flag = "story.note_read"
	story.show(level)
	_check(level.dialog_manager.messages.size() == 1 and level.dialog_manager.messages[0] == story.locked_messages[0], "story shows its locked text while its required flag is missing")
	_check(not level.has_flag(story.completed_flag), "locked story does not set its completed flag")
	level.dialog_manager.hide_dialog()
	level.set_flag(story.required_flag)
	story.show(level)
	_check(level.dialog_manager.messages.size() == 1 and level.dialog_manager.messages[0] == story.messages[0], "story shows its main text after the required flag is set")
	_check(level.has_flag(story.completed_flag), "story sets its completed flag after showing main text")
	level.dialog_manager.hide_dialog()
	story.show(level)
	_check(not level.dialog_manager.is_dialog_open(), "completed story cannot be opened a second time")


func _check_story_interactor(level: Level) -> void:
	var story := StoryText.new()
	story.messages = ["Přečteš si zápis."]
	story.completed_flag = "story.interaction_complete"
	var interactor := (load("res://scripts/rooms/story_interactor.gd") as Script).new() as Area2D
	interactor.story = story
	interactor.hint_text = "Přečíst"
	level.room.add_child(interactor)
	await get_tree().process_frame
	interactor._on_body_entered(level.get_node("Player"))
	_check(interactor.nearby and interactor.hint.visible, "story interaction shows its hint when the player is nearby")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	interactor._unhandled_input(event)
	_check(level.has_flag(story.completed_flag), "story interaction records its one-shot completed flag")
	_check(level.dialog_manager.messages.size() == 1 and level.dialog_manager.messages[0] == story.messages[0], "story interaction displays its configured Czech text")
	_check(not interactor.hint.visible, "completed story interaction hides its one-shot hint")


func _check_locked_exit(level: Level) -> void:
	var exit := (load("res://scenes/objects/room_exit.tscn") as PackedScene).instantiate() as RoomExit
	exit.required_flag = "exit.unlocked"
	exit.locked_message = "Dveře jsou zamčené."
	level.room.add_child(exit)
	await get_tree().process_frame
	var entered := [0]
	exit.exit_entered.connect(func(_room_exit: RoomExit): entered[0] += 1)
	exit._on_body_entered(level.get_node("Player"))
	_check(entered[0] == 0, "locked room exit blocks entry without its required flag")
	_check(level.dialog_manager.messages.size() == 1 and level.dialog_manager.messages[0] == exit.locked_message, "locked room exit shows its configured message")
	level.dialog_manager.hide_dialog()
	level.set_flag(exit.required_flag)
	exit._on_body_entered(level.get_node("Player"))
	_check(entered[0] == 1, "room exit allows entry after its required flag is set")
	exit.queue_free()
	await get_tree().process_frame


func _check_pickup_sound_ids(level: Level) -> void:
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	var sounds: Array[StringName] = []
	var callback := func(sound_id: StringName, _volume: float, _bus: StringName): sounds.append(sound_id)
	EventBus.audio_play_requested.connect(callback)
	var pickup := (load("res://scenes/objects/persistent_pickup.tscn") as PackedScene).instantiate() as PersistentPickup
	pickup.item_id = "item.test_pickup"
	level.room.add_child(pickup)
	await get_tree().process_frame
	pickup.nearby = true
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	pickup._unhandled_input(event)
	_check(sounds == [&"pickup"], "ordinary pickups request the optional pickup sound")
	var key_pickup := (load("res://scenes/objects/persistent_pickup.tscn") as PackedScene).instantiate() as PersistentPickup
	key_pickup.item_id = "item.key"
	level.room.add_child(key_pickup)
	await get_tree().process_frame
	key_pickup.nearby = true
	key_pickup._unhandled_input(event)
	_check(sounds == [&"pickup", &"key"], "key pickups request the optional key sound")
	EventBus.audio_play_requested.disconnect(callback)


func _check_camera_pickup_hint(level: Level) -> void:
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level._load_room("res://scenes/rooms/bathroom.tscn", "start")
	await get_tree().process_frame
	var camera := level.room.get_node("PhotoCamera") as PersistentPickup
	var camera_art := camera.get_node("CameraArt") as Sprite2D
	var authored_art_scale := Vector2(0.28, 0.28)
	_check(camera.scale == Vector2(0.28651762, 0.28651762), "bathroom camera keeps its authored pickup scale")
	_check(camera_art.scale == authored_art_scale, "camera art keeps its authored local scale")
	_check(camera.hint.is_set_as_top_level() and camera.hint.get_global_transform().get_scale().is_equal_approx(Vector2.ONE), "camera pickup hint ignores the scaled camera transform")
	camera._on_body_entered(level.get_node("Player"))
	_check(camera.hint.visible, "camera pickup hint appears when the player is nearby")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	camera._unhandled_input(event)
	_check(not camera.visible, "collecting the camera hides its pickup")
	_check(not camera.hint.is_visible_in_tree(), "collecting the camera hides its top-level hint")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
