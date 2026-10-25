extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_wheels()
	await _check_gameplay_submission()
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
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
	_check(lock.submit_button.text == "Zkusit kód", "submit button uses requested Czech label")
	var results: Array[bool] = []
	lock.submitted.connect(func(correct: bool): results.append(correct))
	lock.submit_button.pressed.emit()
	lock.submit_button.pressed.emit()
	_check(results == [true], "matching code submits once even with duplicate presses")
	lock.queue_free()
	await get_tree().process_frame


func _check_gameplay_submission() -> void:
	var level := load("res://scenes/level.tscn").instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level.open_keypad()
	_check(not level.player_controls_enabled(), "open lock blocks movement")
	var wrong_lock: Control = level.keypad
	wrong_lock.submit_button.pressed.emit()
	await get_tree().process_frame
	_check(level.keypad == null and not is_instance_valid(wrong_lock), "wrong attempt closes the lock")
	_check(level.dialog_manager.is_dialog_open(), "wrong attempt shows the failure dialog")
	_check(not level.has_flag(Level.BEDROOM_KEYPAD_FLAG), "wrong attempt does not unlock the puzzle")
	_check(not level.player_controls_enabled(), "failure dialog continues to block movement")
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level.open_keypad()
	var correct_lock: Control = level.keypad
	_check(correct_lock.entered_code == "0000", "reopened lock resets to four zeroes")
	for index in range(4):
		correct_lock.wheels.get_child(index).set_digit(index + 1)
	correct_lock.submit_button.pressed.emit()
	await get_tree().process_frame
	_check(level.keypad == null and not is_instance_valid(correct_lock), "correct attempt also closes the lock")
	_check(level.has_flag(Level.BEDROOM_KEYPAD_FLAG), "correct code sets the existing unlock flag")
	_check(level.dialog_manager.is_dialog_open(), "correct attempt preserves success dialog")
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	_check(level.player_controls_enabled(), "controls resume when the result dialog closes")
	level.queue_free()
	await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
