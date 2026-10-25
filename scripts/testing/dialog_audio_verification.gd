extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := load("res://scenes/ui/dialog_manager.tscn").instantiate() as GameDialogManager
	get_tree().root.add_child(manager)
	await get_tree().process_frame
	manager.characters_per_second = 24.0
	var player := manager.typewriter_audio.player
	var lock_stream := AudioManager._get_sound_stream(&"lock")
	_check(lock_stream != null, "lock WAV is registered")
	_check(lock_stream is AudioStreamWAV and absf(lock_stream.get_length() - 0.156) < 0.03, "typewriter source is the short lock WAV")
	_check(player.stream == null and player.bus == &"Sound", "typewriter player starts silent on Sound bus")
	_check(manager.get_node("DialogTypewriterAudio").get_child_count() == 1, "helper owns one reusable audio player")

	var czech_text := "Žluťoučký kůň běží."
	manager.show_dialog([czech_text])
	_check(manager.message_label.text == czech_text, "timed reveal uses the authored Czech text")
	var pitches := await _collect_pitch_changes(manager, 0.72)
	_check(manager.message_label.visible_characters > 5, "Czech letters reveal over time")
	_check(player.stream == lock_stream, "typewriter plays the exact registered lock resource")
	_check(player.bus == &"Sound", "typewriter clicks use Sound bus")
	var revealed_letters := _count_printable_prefix(czech_text, manager.message_label.visible_characters)
	_check(pitches.size() >= revealed_letters - 2, "reveal retriggers the click for successive revealed letters")
	_check(_all_pitches_in_range(pitches), "observed click pitches stay between 0.94 and 1.06")
	_check(_has_pitch_variation(pitches), "observed click pitches vary")
	_check(_count_typewriter_players(manager) == 1, "rapid reveal keeps one bounded typewriter player")
	_check(_count_audio_players(AudioManager, lock_stream) == 0, "typewriter clicks do not replace the game's shared lock player")

	manager.characters_per_second = 4.0
	manager.show_dialog(["A   B"])
	await _wait_seconds(0.34)
	var before_spaces := player.pitch_scale
	await _wait_seconds(0.55)
	_check(is_equal_approx(player.pitch_scale, before_spaces), "whitespace-only reveal steps do not tick")
	await _wait_seconds(0.45)
	_check(not is_equal_approx(player.pitch_scale, before_spaces), "a letter after whitespace ticks")

	manager.characters_per_second = 3.0
	manager.show_dialog(["A very long line that should not burst on skip."])
	await _wait_seconds(0.38)
	manager._finish_reveal()
	var pitch_after_skip := player.pitch_scale
	var skip_clicks := await _count_play_starts(manager, 0.3)
	_check(skip_clicks == 0 and is_equal_approx(player.pitch_scale, pitch_after_skip), "finishing a reveal does not trigger a skip click")
	_check(manager.message_label.visible_characters == -1, "skip still completes the visible text")

	manager.characters_per_second = 5.0
	manager.show_dialog(["Cancel this reveal"])
	await _wait_seconds(0.3)
	manager.set_input_enabled(false)
	var pitch_after_disable := player.pitch_scale
	var disabled_clicks := await _count_play_starts(manager, 0.35)
	_check(disabled_clicks == 0 and is_equal_approx(player.pitch_scale, pitch_after_disable), "disabling dialog input stops further clicks")
	manager.set_input_enabled(true)
	manager.show_dialog(["Hide this reveal"])
	await _wait_seconds(0.3)
	manager.hide_dialog()
	var pitch_after_hide := player.pitch_scale
	var hidden_clicks := await _count_play_starts(manager, 0.35)
	_check(hidden_clicks == 0 and is_equal_approx(player.pitch_scale, pitch_after_hide), "hiding the dialog stops further clicks")

	manager.show_dialog(["First message"])
	await _wait_seconds(0.3)
	manager.show_dialog(["Nová zpráva"])
	_check(manager.message_label.visible_characters == 0, "new messages reset the typewriter reveal")
	var new_message_pitches := await _collect_pitch_changes(manager, 0.35)
	_check(not new_message_pitches.is_empty(), "new messages start their own typewriter clicks")

	var pixel := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	manager.show_document(ImageTexture.create_from_image(pixel), ["Dokument"])
	_check(manager.image_overlay.visible and not manager.is_dialog_open(), "image-only document displays without dialog text")
	var pitch_after_image := player.pitch_scale
	var image_clicks := await _count_play_starts(manager, 0.35)
	_check(image_clicks == 0 and is_equal_approx(player.pitch_scale, pitch_after_image), "image-only display makes no typewriter clicks")
	_check(not player.playing, "cancelled or hidden typewriter audio is stopped")

	manager.show_dialog(["Trigger an ordinary lock sound"])
	EventBus.request_audio(&"lock")
	await get_tree().process_frame
	_check(is_instance_valid(AudioManager.lock_player), "ordinary lock requests still use AudioManager's shared player")
	if is_instance_valid(AudioManager.lock_player):
		_check(AudioManager.lock_player.stream == lock_stream and AudioManager.lock_player.bus == &"Sound", "ordinary lock sound keeps its stream and bus")
	_check(_count_audio_players(AudioManager, lock_stream) <= 1, "ordinary lock playback stays bounded to one player")

	var typewriter_player_id := player.get_instance_id()
	manager.free()
	_check(instance_from_id(typewriter_player_id) == null, "dialog cleanup frees its typewriter player")
	AudioManager.stop_sound_effects()
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stop()
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	AudioManager.alternate_music = null
	await get_tree().process_frame
	await _wait_seconds(0.15)
	print("Dialog audio verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _collect_pitch_changes(manager: GameDialogManager, duration: float) -> Array[float]:
	var changes: Array[float] = []
	var last_pitch := manager.typewriter_audio.player.pitch_scale
	var deadline := Time.get_ticks_msec() + roundi(duration * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var pitch := manager.typewriter_audio.player.pitch_scale
		if not is_equal_approx(pitch, last_pitch):
			changes.append(pitch)
			last_pitch = pitch
	return changes


func _wait_seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _count_play_starts(manager: GameDialogManager, duration: float) -> int:
	var player := manager.typewriter_audio.player
	var previous_playing := player.playing
	var starts := 0
	var deadline := Time.get_ticks_msec() + roundi(duration * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if player.playing and not previous_playing:
			starts += 1
		previous_playing = player.playing
	return starts


func _all_pitches_in_range(pitches: Array[float]) -> bool:
	if pitches.is_empty():
		return false
	for pitch in pitches:
		if pitch < 0.94 or pitch > 1.06:
			return false
	return true


func _has_pitch_variation(pitches: Array[float]) -> bool:
	if pitches.size() < 2:
		return false
	for pitch_index in range(1, pitches.size()):
		if not is_equal_approx(pitches[pitch_index], pitches[0]):
			return true
	return false


func _count_printable_prefix(message: String, visible_characters: int) -> int:
	var printable := 0
	for character_index in range(mini(visible_characters, message.length())):
		if not message.substr(character_index, 1).strip_edges().is_empty():
			printable += 1
	return printable


func _count_typewriter_players(manager: GameDialogManager) -> int:
	var count := 0
	for child in manager.typewriter_audio.get_children():
		if child is AudioStreamPlayer:
			count += 1
	return count


func _count_audio_players(owner: Node, stream: AudioStream) -> int:
	var count := 0
	for child in owner.get_children():
		if child is AudioStreamPlayer and child.stream == stream:
			count += 1
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
