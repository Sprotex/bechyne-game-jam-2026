extends Node

var failures := 0
var switch_requests: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	EventBus.audio_play_requested.connect(_record_audio)
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	var light_switch := level.room.get_node("LightSwitch")
	var initial_request_count := switch_requests.size()
	_check(AudioManager._get_sound_stream(&"switch") == AudioManager._get_sound_stream(&"lock"), "switch sound uses the existing lock click resource")
	_check(switch_requests.size() == initial_request_count, "scene setup does not request switch audio")
	var original_lights := level.room.lights_are_on
	level.room.set_lights_enabled(not original_lights)
	_check(switch_requests.size() == initial_request_count, "programmatic light changes stay silent")
	level.room.set_lights_enabled(original_lights)
	_check(switch_requests.size() == initial_request_count, "restoring light state stays silent")
	light_switch.nearby = true
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	light_switch._unhandled_input(event)
	_check(level.room.lights_are_on != original_lights, "valid interaction toggles room lights")
	_check(switch_requests.size() == initial_request_count + 1, "valid interaction requests exactly one switch sound")
	if switch_requests.size() > initial_request_count:
		var request: Dictionary = switch_requests.back()
		_check(request.id == &"switch" and request.bus == &"Sound", "switch request uses the switch sound on Sound bus")
	var echo := InputEventKey.new()
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	light_switch._unhandled_input(echo)
	_check(switch_requests.size() == initial_request_count + 1, "key repeat does not request switch audio")
	level.dialog_manager.show_dialog(["TestovacĂ­ dialog."])
	light_switch._unhandled_input(event)
	_check(switch_requests.size() == initial_request_count + 1, "modal dialog blocks switch audio")
	EventBus.audio_play_requested.disconnect(_record_audio)
	level.queue_free()
	await get_tree().process_frame
	AudioManager.stop_sound_effects()
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().create_timer(0.15).timeout
	print("Switch audio verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _record_audio(sound_id: StringName, _volume_db: float, bus: StringName) -> void:
	if sound_id == &"switch":
		switch_requests.append({"id": sound_id, "bus": bus})


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
