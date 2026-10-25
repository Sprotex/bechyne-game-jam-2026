extends Node

var failures := 0
var audio_requests: Array[StringName] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	EventBus.audio_play_requested.connect(_record_audio_request)
	_check_audio_manager()
	await _check_level_audio()
	await _check_wheel_audio()
	await _check_cleanup()
	EventBus.audio_play_requested.disconnect(_record_audio_request)
	_stop_all_audio()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Audio effects verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_audio_manager() -> void:
	for sound_id in [&"door", &"lock", &"door_unlock", &"footsteps", &"washing_machine"]:
		_check(AudioManager._get_sound_stream(sound_id) != null, "%s sound is registered" % sound_id)
	var footsteps := AudioManager._get_sound_stream(&"footsteps") as AudioStreamWAV
	_check(footsteps != null and footsteps.resource_path.ends_with("footstep_single.wav"), "footsteps uses the single contact sound clip")
	var door_unlock := AudioManager._get_sound_stream(&"door_unlock") as AudioStreamWAV
	_check(door_unlock != null, "door unlock sound is a WAV resource")
	if door_unlock != null:
		_check(door_unlock.mix_rate == 44100 and not door_unlock.stereo, "door unlock WAV is mono at 44100 Hz")
	_check(AudioServer.get_bus_index(&"Sound") >= 0, "Sound bus exists")
	AudioManager.set_loop_active(&"washing_machine", true, &"Sound")
	var first_player: AudioStreamPlayer = AudioManager.looping_players.get(&"washing_machine")
	_check(is_instance_valid(first_player), "loop starts a player")
	_check(first_player.bus == &"Sound", "loop uses requested bus")
	var first_id := first_player.get_instance_id()
	AudioManager.set_loop_active(&"washing_machine", true, &"Sound")
	_check(AudioManager.looping_players.size() == 1, "repeated activation keeps one player")
	_check(AudioManager.looping_players[&"washing_machine"].get_instance_id() == first_id, "repeated activation does not restart the player")
	var loop_stream := first_player.stream as AudioStreamWAV
	_check(loop_stream != AudioManager._get_sound_stream(&"washing_machine"), "loop plays a duplicated WAV resource")
	if loop_stream != null:
		_check(loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "duplicated WAV loops forward")
	AudioManager.set_loop_active(&"missing_audio_test", true)
	_check(not AudioManager.looping_players.has(&"missing_audio_test"), "unknown loop sound is ignored")
	EventBus.request_audio(&"missing_audio_test")
	await get_tree().process_frame
	_check(_count_players_for(&"missing_audio_test") == 0, "unknown one-shot sound creates no player")
	AudioManager.set_loop_active(&"washing_machine", false)
	_check(not AudioManager.looping_players.has(&"washing_machine"), "deactivation removes loop from registry")
	await get_tree().process_frame
	_check(not is_instance_valid(first_player), "deactivation frees loop player")
	EventBus.request_audio(&"door")
	await get_tree().process_frame
	var door_player := _find_recent_effect(&"door")
	_check(is_instance_valid(door_player), "one-shot door effect plays")
	if is_instance_valid(door_player):
		_check(door_player.bus == &"Sound", "one-shot effect uses Sound bus")
		AudioManager.remove_child(door_player)
		door_player.queue_free()


func _check_level_audio() -> void:
	var level := load("res://scenes/level.tscn").instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	level.set_flag("story.day_two")
	await get_tree().process_frame
	var washer := AudioManager.looping_players.get(&"washing_machine") as AudioStreamPlayer
	_check(is_instance_valid(washer), "day two starts washer loop")
	if is_instance_valid(washer):
		_check(washer.bus == &"WashingMachine", "washer loop uses WashingMachine bus")
	_check(AudioServer.get_bus_index(&"WashingMachine") >= 0, "WashingMachine bus exists")
	if AudioServer.get_bus_index(&"WashingMachine") >= 0:
		_check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"WashingMachine")) == &"Sound", "WashingMachine bus sends to Sound")
	var washer_id := washer.get_instance_id() if is_instance_valid(washer) else 0
	level._load_room("res://scenes/rooms/hall.tscn", "start")
	await get_tree().process_frame
	_check(is_instance_valid(AudioManager.looping_players.get(&"washing_machine")), "washer keeps playing through room change")
	if washer_id != 0:
		_check(AudioManager.looping_players[&"washing_machine"].get_instance_id() == washer_id, "room change keeps the same washer player")
	for flag in ["story.washing_machine_stopped", "story.act_three", "story.identity_read"]:
		level.set_flag(flag)
		await get_tree().process_frame
		_check(not AudioManager.looping_players.has(&"washing_machine"), "%s stops washer loop" % flag)
		level.set_flag("story.washing_machine_stopped", false)
		level.set_flag("story.act_three", false)
		level.set_flag("story.identity_read", false)
		level.set_flag("story.day_two", false)
		await get_tree().process_frame
		level.set_flag("story.day_two")
		await get_tree().process_frame
	_check(AudioManager.looping_players.has(&"washing_machine"), "washer restarts while day two remains active")
	level.queue_free()
	await get_tree().process_frame
	_check(not AudioManager.looping_players.has(&"washing_machine"), "level exit stops washer loop")
	EventBus.reset_game_completion()
	EventBus.game_completed.emit()
	await get_tree().process_frame
	_check(not AudioManager.looping_players.has(&"washing_machine"), "game completion stops washer loop")


func _check_wheel_audio() -> void:
	var keypad := load("res://scenes/ui/keypad.tscn").instantiate() as Control
	get_tree().root.add_child(keypad)
	await get_tree().process_frame
	audio_requests.clear()
	var wheel: Node = keypad.wheels.get_child(0)
	wheel.get_node("Increase").pressed.emit()
	wheel.get_node("Decrease").pressed.emit()
	_check(audio_requests == [&"lock", &"lock"], "each wheel increase and decrease requests one lock sound")
	_check(is_instance_valid(AudioManager.lock_player), "lock requests use the shared lock player")
	if is_instance_valid(AudioManager.lock_player):
		_check(AudioManager.lock_player.bus == &"Sound", "lock one-shot uses Sound bus")
		_check(_count_players_for(&"lock") == 1, "rapid lock requests do not create duplicate players")
	keypad.queue_free()
	await get_tree().process_frame


func _check_cleanup() -> void:
	var music_player: AudioStreamPlayer = AudioManager.music_player
	if is_instance_valid(music_player):
		AudioManager.remove_child(music_player)
		music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
	await get_tree().process_frame


func _stop_all_audio() -> void:
	AudioManager.stop_sound_effects()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()


func _find_recent_effect(sound_id: StringName) -> AudioStreamPlayer:
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer and child.stream == AudioManager._get_sound_stream(sound_id):
			return child
	return null


func _count_players_for(sound_id: StringName) -> int:
	var count := 0
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer and child.stream == AudioManager._get_sound_stream(sound_id):
			count += 1
	return count


func _record_audio_request(sound_id: StringName, _volume_db: float, _bus: StringName) -> void:
	audio_requests.append(sound_id)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
