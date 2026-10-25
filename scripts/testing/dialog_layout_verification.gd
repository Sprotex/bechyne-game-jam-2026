extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := get_tree().root
	var manager := load("res://scenes/ui/dialog_manager.tscn").instantiate() as GameDialogManager
	root.add_child(manager)
	await get_tree().process_frame
	var panel := manager.panel
	var viewport_size := root.get_visible_rect().size
	var panel_size := panel.size
	_check(absf(panel_size.x / viewport_size.x - 0.6) < 0.02, "dialog uses about 60% of viewport width")
	_check(absf(panel_size.y / viewport_size.y - 0.26) < 0.02, "dialog uses about 26% of viewport height")
	_check(manager.message_label.get_theme_font_size("font_size") > 20, "dialog font is larger than before")
	root.size = Vector2i(960, 540)
	await get_tree().process_frame
	_check(absf(panel.size.x / root.get_visible_rect().size.x - 0.6) < 0.02, "dialog width follows a smaller viewport")
	_check(manager.message_label.get_theme_font_size("font_size") == 22, "font scales down for a smaller viewport")
	root.size = Vector2i(1920, 1080)
	await get_tree().process_frame

	var long_text := "Tohle je delší český odstavec s háčky a čárkami. "
	long_text = long_text.repeat(24)
	manager.show_dialog([long_text])
	await get_tree().create_timer(0.2).timeout
	_check(manager.message_label.get_total_character_count() == long_text.length(), "long Czech text is present for reveal")
	_check(manager.message_label.size.y > manager.message_label.get_parent().size.y, "long text extends beyond the scroll viewport")
	_check(manager.is_modal_open(), "dialog remains modal while text is shown")
	manager._finish_reveal()
	_check(manager.message_label.visible_characters == -1, "reveal can still be completed")
	manager.advance_dialog()
	_check(not manager.is_modal_open(), "dialog closes after advancing past the final message")

	print("Dialog layout verification: %d failures" % failures)
	manager.free()
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
