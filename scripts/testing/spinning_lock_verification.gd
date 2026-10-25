extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_wheels()
	await _check_gameplay_submission()
	AudioManager.stop_sound_effects()
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stop()
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Spinning lock verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_wheels() -> void:
	var lock := load("res://scenes/ui/keypad.tscn").instantiate() as Control
	get_tree().root.add_child(lock)
	await get_tree().process_frame
	var wheels: HBoxContainer = lock.wheels
	_check(wheels.get_child_count() == 4, "lock has four independent digit wheels")
	_check(lock.entered_code == "0000", "lock initially displays four zeroes")
	var first_wheel := wheels.get_child(0)
	(first_wheel.get_node("Decrease") as Button).pressed.emit()
	_check(lock.entered_code == "9000", "decrement wraps zero to nine without changing other digits")
	(first_wheel.get_node("Increase") as Button).pressed.emit()
	_check(lock.entered_code == "0000", "increment wraps nine to zero")
	for index in range(4):
		wheels.get_child(index).set_digit(index + 1)
	_check(lock.entered_code == "1234", "digits are read from left to right")
	_check(lock.find_child("Cancel", true, false) == null, "lock has no leave button")
	_check(lock.submit_button.text == "Zkusit kód", "submit button uses the requested Czech label")
	var results: Array[bool] = []
	lock.submitted.connect(func(correct: bool): results.append(correct))
	lock.submit_button.pressed.emit()
	lock.submit_button.pressed.emit()
	_check(results == [true], "matching code submits once even with duplicate presses")
	lock.queue_free()
	await get_tree().process_frame


func _check_gameplay_submission() -> void:
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level.set_flag("story.day_two")
	level.set_flag("story.diagnosis_read")
	level._load_room("res://scenes/rooms/attic.tscn", "from_hall")
	var interactor := level.room.get_node("CombinationLock")
	_check(level.room.get_node_or_null("IdentityCard") == null, "there is no standalone identity pickup to bypass the lock")
	var player := level.get_node("Player") as CharacterBody2D
	interactor.call("_on_body_entered", player)
	interactor.call("_unhandled_input", _interact_event())
	_check(level.keypad != null and not level.player_controls_enabled(), "E opens the attic lock and blocks movement")
	var wrong_lock := level.keypad
	wrong_lock.submit_button.pressed.emit()
	await get_tree().process_frame
	_check(level.keypad == null and not is_instance_valid(wrong_lock), "wrong attempt closes the lock")
	_check(level.dialog_manager.is_dialog_open(), "wrong attempt shows the failure dialog")
	_check(not level.has_flag(Level.ATTIC_COMBINATION_FLAG), "wrong attempt does not unlock the attic combination")
	_check(not level.has_flag("story.identity_read"), "wrong attempt does not set the identity story flag")
	_check(not level.ending_started, "wrong attempt does not start the ending")
	_check(not level.player_controls_enabled(), "failure dialog continues to block movement")
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	interactor.call("_unhandled_input", _interact_event())
	var correct_lock := level.keypad
	_check(correct_lock.entered_code == "0000", "reopened lock resets to four zeroes")
	for index in range(4):
		correct_lock.wheels.get_child(index).set_digit(index + 1)
	correct_lock.submit_button.pressed.emit()
	await get_tree().process_frame
	_check(level.keypad == null and not is_instance_valid(correct_lock), "correct attempt closes the lock")
	_check(level.has_flag(Level.ATTIC_COMBINATION_FLAG), "correct code sets the attic combination flag")
	_check(level.dialog_manager.showing_document, "correct code automatically opens the identity document")
	_check(level.dialog_manager.image_preview.texture == load("res://assets/gfx/identity_card.png"), "automatic document uses identity card artwork")
	_check(level.dialog_manager.document_messages == DialogueCatalog.get_messages(&"act3.id_reveal"), "automatic document uses act3.id_reveal")
	_check(level.dialog_manager.is_modal_open() and not level.player_controls_enabled(), "identity image blocks movement")
	_check(not level.has_flag("story.identity_read"), "identity story flag waits for document dismissal")
	var completions := [0]
	var completion_callback := func(): completions[0] += 1
	EventBus.reset_game_completion()
	EventBus.game_completed.connect(completion_callback)
	level.dialog_manager._input(_interact_event())
	_check(level.dialog_manager.is_dialog_open(), "dismissing the image opens its reveal dialogue")
	_check(level.dialog_manager.messages == DialogueCatalog.get_messages(&"act3.id_reveal"), "reveal dialogue contains the registered story text")
	_check(not level.has_flag("story.identity_read") and completions[0] == 0, "identity is incomplete while reveal dialogue remains open")
	level.dialog_manager._finish_reveal()
	level.dialog_manager.advance_dialog()
	_check(level.has_flag("story.identity_read"), "identity story flag is set after the final reveal line")
	await get_tree().process_frame
	_check(completions[0] == 1, "game completion fires once after document dismissal")
	await get_tree().process_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("/final_credits.tscn"), "identity dismissal opens final credits")
	var credits := get_tree().current_scene.get_node("Credits")
	var back_button := credits.find_child("Back", true, false) as Button
	_check(back_button != null and back_button.text == "ZPĚT DO MENU", "credits offer a Czech return-to-menu action")
	if back_button != null:
		back_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("/root.tscn"), "credits return to the main menu")
	EventBus.game_completed.disconnect(completion_callback)


func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
