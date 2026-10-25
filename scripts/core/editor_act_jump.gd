extends RefCounted
## Editor-only shortcuts for jumping to the opening of each act.

const MAIN_ENTRANCE := "res://scenes/rooms/main_entrance.tscn"
const HALL := "res://scenes/rooms/hall.tscn"


static func handle_key_input(level: Level, event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return
	var act := 0
	match key_event.keycode:
		KEY_1: act = 1
		KEY_2: act = 2
		KEY_3: act = 3
	if act == 0:
		return
	level.get_viewport().set_input_as_handled()
	_jump_to_act(level, act)


static func _jump_to_act(level: Level, act: int) -> void:
	if level.transition_locked:
		return
	level.transition_locked = true
	level._refresh_controls()
	level.options_screen.hide()
	if is_instance_valid(level.keypad):
		level.keypad.hide()
		level.keypad.queue_free()
		level.keypad = null
	if is_instance_valid(level.dialog_manager.image_overlay):
		level.dialog_manager.image_overlay.hide()
		level.dialog_manager.generated_image_visible = false
	var fade := level.get_node("HUD/Fade") as ColorRect
	var fade_in := level.create_tween()
	fade_in.tween_property(fade, "color:a", 1.0, 0.35)
	await fade_in.finished
	level.room_light_states.clear()
	for flag_id in level.flags.keys():
		level.set_flag(flag_id, false)
	level.ending_started = false
	EventBus.reset_game_completion()
	var scene := MAIN_ENTRANCE
	var arrival := "start"
	if act >= 2:
		scene = HALL
		arrival = "from_bedroom"
		level.set_flag("story.day_two")
		level.set_flag("story.day_two_wake_shown")
	if act == 3:
		level.set_flag("story.washing_machine_stopped")
		level.set_flag("item.key")
		level.set_flag("story.act_three")
	level._load_room(scene, arrival)
	level._refresh_controls()
	var fade_out := level.create_tween()
	fade_out.tween_property(fade, "color:a", 0.0, 0.4)
	await fade_out.finished
	level.transition_locked = false
	level._refresh_controls()
	match act:
		1: level.dialog_manager.show_dialog(level.INITIAL_ROOM_MESSAGES)
		2: level.dialog_manager.show_dialog(DialogueCatalog.get_messages(&"act2.wake"))
		3: level.dialog_manager.show_dialog(DialogueCatalog.get_messages(&"act3.wake"))
