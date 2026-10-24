extends Node2D
class_name Level

const OPTIONS_SCENE := preload("res://scenes/ui/options.tscn")
const KEYPAD_SCENE := preload("res://scenes/ui/keypad.tscn")
const BEDROOM_KEYPAD_FLAG := "puzzle.bedroom_keypad_unlocked"
const INITIAL_ROOM := "res://scenes/rooms/main_entrance.tscn"
const AFTER_SLEEP_ROOM := "res://scenes/rooms/hall.tscn"
const AFTER_SLEEP_ARRIVAL := "from_bedroom"
const START_POSITION := Vector2(1800, 933.333)
const CAMERA_OVERSCAN := 1.05
const INITIAL_ROOM_MESSAGES: Array[String] = [
	"TETO!! Už jsem tady!",
	"Neodpovídá.",
	"Asi mě neslyšela.",
	"Měla bych ji najít a říct jí že už jsem tady.",
]
const BED_DIALOG_MESSAGES: Array[String] = [
	"Už se stmívá a TETA furt nikde. Asi zase někde bloudí jako vždycky.",
	"Moc ráda se procházela po přírodě a naslouchala lesu.",
	"Byla trochu divná.",
	"Asi si půjdu schrupnout, mám za sebou dlouhou cestu. Na TETU nemá cenu čekat, stejně se ze svého toulání po přírodě vracela často až ráno.",
]

var room: Room
var transition_locked := false
var options_screen: Control
var dialog_manager: GameDialogManager
var flags: Dictionary = {}
var keypad: Control


func _ready() -> void:
	EventBus.lights_state_changed.connect(_on_lights_state_changed)
	_on_lights_state_changed(EventBus.lights_are_on)
	_load_room(INITIAL_ROOM, "start")
	options_screen = OPTIONS_SCENE.instantiate()
	options_screen.hide()
	options_screen.connect("back_pressed", _close_options)
	$HUD.add_child(options_screen)
	dialog_manager = preload("res://scenes/ui/dialog_manager.tscn").instantiate() as GameDialogManager
	add_child(dialog_manager)
	dialog_manager.modal_changed.connect(_refresh_controls)
	UserMessages.message_delivered.connect(_on_message_delivered)
	_refresh_controls()
	_update_room_label()
	dialog_manager.show_dialog(INITIAL_ROOM_MESSAGES)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		options_screen.visible = not options_screen.visible
		_refresh_controls()
		get_viewport().set_input_as_handled()


func send_room_photo() -> void:
	if not has_flag("item.camera") or not player_controls_enabled():
		return
	$HUD.hide()
	await RenderingServer.frame_post_draw
	var photo := get_viewport().get_texture().get_image()
	$HUD.show()
	var result := UserMessages.deliver_user_picture(photo, "fotografie_mistnosti.png")
	if result == OK and not OS.has_feature("web"):
		dialog_manager.show_dialog(["Fotografie byla uložena do složky se zprávami."])
	elif result != OK:
		dialog_manager.show_dialog(["Fotografii se nepodařilo uložit. Kód chyby: %d" % result])


func _close_options() -> void:
	options_screen.hide()
	_refresh_controls()


func request_room_transition(destination_scene_path: String, arrival_id: String) -> void:
	if transition_locked or not $Player.controls_enabled:
		return
	transition_locked = true
	_refresh_controls()
	_perform_room_transition(destination_scene_path, arrival_id)


func _perform_room_transition(destination_scene_path: String, arrival_id: String) -> void:
	var destination := load(destination_scene_path) as PackedScene
	$HUD/Fade.color.a = 1.0
	_load_room(destination.resource_path, arrival_id)
	_update_room_label()
	$HUD/Hint.text = ""
	var tween := create_tween()
	tween.tween_property($HUD/Fade, "color:a", 0.0, 0.22)
	await tween.finished
	transition_locked = false
	_refresh_controls()


func has_flag(flag_id: String) -> bool:
	return bool(flags.get(flag_id, false))


func player_controls_enabled() -> bool:
	return $Player.controls_enabled


func open_keypad() -> void:
	if has_flag(BEDROOM_KEYPAD_FLAG) or is_instance_valid(keypad) or not player_controls_enabled():
		return
	keypad = KEYPAD_SCENE.instantiate() as Control
	keypad.submitted.connect(_on_keypad_submitted)
	keypad.cancelled.connect(_on_keypad_cancelled)
	$HUD.add_child(keypad)
	_refresh_controls()


func start_sleep_dialog() -> void:
	if transition_locked or not player_controls_enabled():
		return
	dialog_manager.dialog_finished.connect(_on_sleep_dialog_finished, CONNECT_ONE_SHOT)
	dialog_manager.show_dialog(BED_DIALOG_MESSAGES)
	_refresh_controls()


func _on_sleep_dialog_finished() -> void:
	if not is_instance_valid(room) or room.name != "Bedroom":
		return
	transition_locked = true
	_refresh_controls()
	_run_sleep_transition()


func _run_sleep_transition() -> void:
	var fade := $HUD/Fade as ColorRect
	fade.color = Color.BLACK
	fade.color.a = 0.0
	var title := Label.new()
	title.name = "SleepTransitionText"
	title.text = "po nějaké době"
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fff8df"))
	title.add_theme_font_size_override("font_size", 38)
	title.modulate.a = 0.0
	$HUD.add_child(title)

	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 1.0, 0.7)
	await fade_in.finished
	var text_in := create_tween()
	text_in.tween_property(title, "modulate:a", 1.0, 0.8)
	await text_in.finished
	await get_tree().create_timer(1.2).timeout
	var text_out := create_tween()
	text_out.tween_property(title, "modulate:a", 0.0, 0.8)
	await text_out.finished
	title.queue_free()
	_load_room(AFTER_SLEEP_ROOM, AFTER_SLEEP_ARRIVAL)
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 0.0, 1.0)
	await fade_out.finished
	transition_locked = false
	_refresh_controls()


func _on_keypad_submitted(is_correct: bool) -> void:
	keypad.queue_free()
	keypad = null
	if is_correct:
		set_flag(BEDROOM_KEYPAD_FLAG)
		dialog_manager.show_dialog(["Zámek cvakl. Kód je správný."])
	else:
		dialog_manager.show_dialog(["Zámek kód odmítl."])
	_refresh_controls()


func _on_keypad_cancelled() -> void:
	keypad.queue_free()
	keypad = null
	_refresh_controls()


func set_flag(flag_id: String, value: bool = true) -> void:
	if flag_id.is_empty():
		return
	flags[flag_id] = value


func _load_room(scene_path: String, arrival_id: String) -> void:
	if is_instance_valid(room):
		room.queue_free()
	room = (load(scene_path) as PackedScene).instantiate() as Room
	$RoomHolder.add_child(room)
	room.exit_entered.connect(_on_exit_entered)
	$Player.global_position = room.get_arrival_position(arrival_id, START_POSITION)
	_update_camera_bounds()
	_update_room_label()


func _update_camera_bounds() -> void:
	var camera := $Player/Camera2D as Camera2D
	var bounds := room.get_background_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	var fit_zoom := maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)
	var zoom := maxf(1.0, fit_zoom) * CAMERA_OVERSCAN
	camera.zoom = Vector2.ONE * zoom
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()
	camera.force_update_scroll()


func _on_exit_entered(exit: RoomExit) -> void:
	if transition_locked or not $Player.controls_enabled:
		return
	transition_locked = true
	_refresh_controls()
	_perform_room_transition.call_deferred(exit.destination_scene_path, exit.destination_arrival_id)


func _refresh_controls() -> void:
	if not is_instance_valid($Player):
		return
	dialog_manager.set_input_enabled(not options_screen.visible)
	$Player.controls_enabled = not transition_locked and not dialog_manager.is_modal_open() and not options_screen.visible and not is_instance_valid(keypad)


func _on_message_delivered(file_name: String, content: PackedByteArray) -> void:
	dialog_manager.show_generated_file(file_name, content)


func _on_lights_state_changed(is_on: bool) -> void:
	$LightDimmer.color = Color("#e9e5d8") if is_on else Color("#77756d")


func _update_room_label() -> void:
	if is_instance_valid(room):
		$HUD/RoomLabel.text = room.room_title
