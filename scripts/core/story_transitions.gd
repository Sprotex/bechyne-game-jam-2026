extends RefCounted
class_name StoryTransitions
## Keeps story cutscene transitions outside the main level controller.


static func coma_transition(level: Level) -> void:
	level.transition_locked = true
	level._refresh_controls()
	level.dialog_manager.show_dialog(DialogueCatalog.get_messages(&"act2.leaving_cellar"))
	await level.dialog_manager.dialog_finished
	var fade := level.get_node("HUD/Fade") as ColorRect
	var tween := level.create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.8)
	await tween.finished
	level._load_room("res://scenes/rooms/hall.tscn", "from_cellar")
	level.set_flag("story.act_three")
	var title := Label.new()
	title.name = "ComaTransitionText"
	title.text = "O chvíli později"
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fff8df"))
	title.add_theme_font_size_override("font_size", 38)
	level.get_node("HUD").add_child(title)
	await level.get_tree().create_timer(1.2).timeout
	title.queue_free()
	var fade_out := level.create_tween()
	fade_out.tween_property(fade, "color:a", 0.0, 0.9)
	await fade_out.finished
	level.transition_locked = false
	level._refresh_controls()
	AudioManager.select_primary_music()
	level.dialog_manager.show_dialog(DialogueCatalog.get_messages(&"act3.wake"))
