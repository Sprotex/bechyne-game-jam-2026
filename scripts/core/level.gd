extends Node2D
class_name Level

const OPTIONS_SCENE := preload("res://scenes/ui/options.tscn")
const KEYPAD_SCENE := preload("res://scenes/ui/keypad.tscn")
const BEDROOM_KEYPAD_FLAG := "puzzle.bedroom_keypad_unlocked"
const INITIAL_ROOM := "res://scenes/rooms/main_entrance.tscn"
const AFTER_SLEEP_ROOM := "res://scenes/rooms/hall.tscn"
const AFTER_SLEEP_ARRIVAL := "from_bedroom"
const START_POSITION := Vector2(1800, 933.333)
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
var room_scene_path := ""
var room_light_states: Dictionary = {}
var transition_locked := false
var options_screen: Control
var dialog_manager: GameDialogManager
var flags: Dictionary = {}
var keypad: Control
var world_frame: CanvasLayer
var letterbox_bars: Dictionary = {}


func _ready() -> void:
	_create_world_frame()
	get_viewport().size_changed.connect(_update_world_frame)
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
	var photo := _crop_photo_to_world_rect(get_viewport().get_texture().get_image())
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
		room_light_states[room_scene_path] = room.lights_are_on
		room.queue_free()
	room = (load(scene_path) as PackedScene).instantiate() as Room
	room_scene_path = scene_path
	room.set_lights_enabled(bool(room_light_states.get(scene_path, false)))
	room.lights_state_changed.connect(_on_lights_state_changed)
	$RoomHolder.add_child(room)
	_on_lights_state_changed(room.lights_are_on)
	room.exit_entered.connect(_on_exit_entered)
	$Player.global_position = room.get_arrival_position(arrival_id, START_POSITION)
	_update_camera_bounds()
	_update_room_label()


func _update_camera_bounds() -> void:
	var camera := $Player/Camera2D as Camera2D
	var bounds := room.get_background_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	camera.zoom = Vector2.ONE
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()
	camera.force_update_scroll()
	_update_world_frame()


func _create_world_frame() -> void:
	world_frame = CanvasLayer.new()
	world_frame.name = "WorldFrame"
	world_frame.layer = 10
	add_child(world_frame)
	for bar_name in ["TopLetterbox", "BottomLetterbox", "LeftLetterbox", "RightLetterbox"]:
		var bar := ColorRect.new()
		bar.name = bar_name
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world_frame.add_child(bar)
		letterbox_bars[bar_name] = bar

func get_world_render_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var bounds := room.get_background_bounds() if is_instance_valid(room) else Rect2()
	var render_size := Vector2(
		minf(viewport_size.x, bounds.size.x),
		minf(viewport_size.y, bounds.size.y)
	)
	return Rect2((viewport_size - render_size) * 0.5, render_size)

func _update_world_frame() -> void:
	if letterbox_bars.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var render_rect := get_world_render_rect()
	_set_letterbox_bar("TopLetterbox", Rect2(0, 0, viewport_size.x, render_rect.position.y))
	_set_letterbox_bar("BottomLetterbox", Rect2(0, render_rect.end.y, viewport_size.x, viewport_size.y - render_rect.end.y))
	_set_letterbox_bar("LeftLetterbox", Rect2(0, render_rect.position.y, render_rect.position.x, render_rect.size.y))
	_set_letterbox_bar("RightLetterbox", Rect2(render_rect.end.x, render_rect.position.y, viewport_size.x - render_rect.end.x, render_rect.size.y))

func _set_letterbox_bar(bar_name: String, rect: Rect2) -> void:
	var bar := letterbox_bars[bar_name] as ColorRect
	bar.position = rect.position
	bar.size = rect.size
	bar.visible = rect.size.x > 0.0 and rect.size.y > 0.0

func _crop_photo_to_world_rect(photo: Image) -> Image:
	var render_rect := get_world_render_rect()
	var crop := Rect2i(
		floori(render_rect.position.x),
		floori(render_rect.position.y),
		mini(roundi(render_rect.size.x), photo.get_width()),
		mini(roundi(render_rect.size.y), photo.get_height())
	)
	crop.position.x = clampi(crop.position.x, 0, photo.get_width() - crop.size.x)
	crop.position.y = clampi(crop.position.y, 0, photo.get_height() - crop.size.y)
	return photo.get_region(crop)


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
