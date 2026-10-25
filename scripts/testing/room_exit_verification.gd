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
	var exit := (load("res://scenes/objects/room_exit.tscn") as PackedScene).instantiate() as RoomExit
	level.add_child(exit)
	await get_tree().process_frame
	var player := level.get_node("Player") as CharacterBody2D
	var entered := [0]
	var sounds: Array[StringName] = []
	var entered_callback := func(_room_exit: RoomExit): entered[0] += 1
	var sound_callback := func(sound_id: StringName, _volume: float, _bus: StringName): sounds.append(sound_id)
	exit.exit_entered.connect(entered_callback)
	EventBus.audio_play_requested.connect(sound_callback)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	exit._on_body_entered(player)
	_check(exit.nearby and exit.hint.visible, "door hint appears within reach")
	_check(entered[0] == 0 and sounds.is_empty(), "proximity does not transition or play door audio")
	level.dialog_manager.show_dialog(["Testovací dialog."])
	exit._unhandled_input(event)
	_check(entered[0] == 0 and sounds.is_empty(), "modal dialog blocks door interaction")
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	exit.required_flag = "test.door_unlocked"
	exit.locked_message = "Dveře jsou zamčené."
	exit._unhandled_input(event)
	_check(entered[0] == 0 and sounds.is_empty(), "locked door interaction has no transition or sound")
	_check(level.dialog_manager.messages == [exit.locked_message], "locked message appears only after interaction")
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level.set_flag(exit.required_flag)
	exit._unhandled_input(event)
	exit._unhandled_input(event)
	_check(entered[0] == 1 and sounds == [&"door"], "one unlocked interaction emits one signal and one sound")
	exit._on_body_exited(player)
	_check(not exit.nearby and not exit.hint.visible, "leaving the trigger clears proximity and the hint")
	EventBus.audio_play_requested.disconnect(sound_callback)
	exit.exit_entered.disconnect(entered_callback)
	level.queue_free()
	await get_tree().process_frame
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().create_timer(0.15).timeout
	print("Room exit verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
