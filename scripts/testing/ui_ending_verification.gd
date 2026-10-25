extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_dialog_layout()
	await _check_credits_content()
	await _check_cutscene_completion_connection()
	_check_final_ending_is_one_shot()
	_check_audio_registry()
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("UI and ending verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_dialog_layout() -> void:
	var dialog := (load("res://scenes/ui/dialog_manager.tscn") as PackedScene).instantiate() as GameDialogManager
	add_child(dialog)
	await get_tree().process_frame
	var panel := dialog.get_node("DialogPanel") as PanelContainer
	var scroll := dialog.get_node("DialogPanel/Content/MessageScroll") as ScrollContainer
	var label := dialog.get_node("DialogPanel/Content/MessageScroll/Message") as Label
	var close_hint := dialog.get_node("DialogPanel/Content/CloseHint") as Label
	var viewport_rect := get_viewport().get_visible_rect()
	_check(viewport_rect.encloses(panel.get_global_rect()), "dialog panel stays inside the viewport")
	_check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "dialog prevents horizontal scrolling")
	_check(label.get_theme_font_size("font_size") >= 22, "dialog font respects its minimum readable size")
	_check(close_hint.get_theme_font_size("font_size") >= 14, "dialog hint respects its minimum readable size")
	var long_message := "Dlouhý text dialogu, který se musí zalomit a zůstat čitelný. ".repeat(30)
	dialog.show_dialog([long_message])
	await get_tree().process_frame
	_check(label.get_minimum_size().x <= scroll.size.x + 1.0, "long dialog text wraps within the message panel")
	_check(label.get_minimum_size().y > scroll.size.y, "long dialog text can overflow vertically into scrolling")
	dialog.queue_free()
	await get_tree().process_frame


func _check_credits_content() -> void:
	var credits := (load("res://scenes/ui/credits.tscn") as PackedScene).instantiate() as Control
	add_child(credits)
	await get_tree().process_frame
	var contributor_names: Array = credits.CREDITS_DATA.names
	for contributor in contributor_names:
		var matches := 0
		for label in credits.find_children("*", "Label", true, false):
			if (label as Label).text == contributor:
				matches += 1
		_check(matches == 1, "credits show %s exactly once" % contributor)
	var back_button := credits.find_child("Back", true, false) as Button
	_check(back_button != null and back_button.text == "ZPĚT", "credits back action is labeled in Czech")
	credits.queue_free()
	await get_tree().process_frame


func _check_cutscene_completion_connection() -> void:
	var root := (load("res://scenes/root.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	root._show_cutscene()
	var dialog: GameDialogManager = root.cutscene_dialog
	var callbacks := 0
	for connection in dialog.dialog_finished.get_connections():
		if connection.callable.get_method() == "_enter_game":
			callbacks += 1
	_check(callbacks == 1, "cutscene completion enters gameplay through one callback")
	root.queue_free()
	await get_tree().process_frame


func _check_final_ending_is_one_shot() -> void:
	var event_bus_script := load("res://scripts/core/event_bus.gd") as Script
	var event_bus = event_bus_script.new()
	var completion_count := [0]
	event_bus.game_completed.connect(func(): completion_count[0] += 1)
	event_bus.complete_game()
	event_bus.complete_game()
	_check(completion_count[0] == 1, "game completion emits the ending signal only once")
	event_bus.free()


func _check_audio_registry() -> void:
	var audio := (load("res://scenes/audio/audio_manager.tscn") as PackedScene).instantiate()
	var registry: Dictionary = audio.sound_registry
	for sound_id in [&"switch", &"door", &"key", &"pickup"]:
		_check(registry.has(sound_id), "audio registry declares %s" % sound_id)
		var configured: AudioStream = registry.get(sound_id)
		_check(audio._get_sound_stream(sound_id) == configured, "%s resolves when assigned and stays silent when empty" % sound_id)
		if configured == null:
			_check(audio._get_sound_stream(sound_id) == null, "unassigned %s request resolves silently" % sound_id)
			var child_count := audio.get_child_count()
			audio._play_audio(sound_id, 0.0, &"Sound")
			_check(audio.get_child_count() == child_count, "unassigned %s request creates no audio player" % sound_id)
	_check(audio._get_sound_stream(&"unknown_test_sound") == null, "unknown sound requests resolve silently")
	var child_count := audio.get_child_count()
	audio._play_audio(&"unknown_test_sound", 0.0, &"Sound")
	_check(audio.get_child_count() == child_count, "unknown sound request creates no audio player")
	_check(audio._get_sound_stream(&"voice_message") == audio.voice_message, "legacy voice message ID keeps its fallback")
	_check(audio.music != null and audio.alternate_music != null and audio.loop_music, "configured music tracks and looping remain available")
	audio.free()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
