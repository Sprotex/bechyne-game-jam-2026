extends Node2D
class_name Level

const OPTIONS_SCENE := preload("res://scenes/ui/options.tscn")
const KEYPAD_SCENE := preload("res://scenes/ui/keypad.tscn")
const ATTIC_COMBINATION_FLAG := "puzzle.attic_combination_unlocked"
const IDENTITY_CARD_TEXTURE := preload("res://assets/gfx/identity_card.png")
const WORLD_FRAME_SCRIPT := preload("res://scripts/core/world_frame.gd")
const INITIAL_ROOM := "res://scenes/rooms/main_entrance.tscn"
const AFTER_SLEEP_ROOM := "res://scenes/rooms/hall.tscn"
const AFTER_SLEEP_ARRIVAL := "from_bedroom"
const START_POSITION := Vector2(1000, 281.5)
const STORY_DAY_TWO := "story.day_two"
const STORY_WAKE_SHOWN := "story.day_two_wake_shown"
const INITIAL_ROOM_MESSAGES: Array[String] = [
	"TETO!! Už jsem tady!",
	"Neodpovídá.",
	"Asi mě neslyšela.",
	"Měla bych ji najít a říct jí že už jsem tady.",
]
signal flag_changed(flag_id: String, value: bool)

var room: Room
var room_scene_path := ""
var room_light_states: Dictionary = {}
var transition_locked := false
var options_screen: Control
var dialog_manager: GameDialogManager
var flags: Dictionary = {}
var keypad: Control
var ending_started := false
var world_frame: Variant
var letterbox_bars: Dictionary:
	get:
		return world_frame.bars if is_instance_valid(world_frame) else {}


func _ready() -> void:
	world_frame = WORLD_FRAME_SCRIPT.new()
	add_child(world_frame)
	world_frame.setup($Player/Camera2D)
	get_viewport().size_changed.connect(world_frame.update_frame)
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
	if ending_started:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_back"):
		options_screen.visible = not options_screen.visible
		_refresh_controls()
		get_viewport().set_input_as_handled()


func send_room_photo() -> void:
	if not has_flag("item.camera") or not player_controls_enabled():
		return
	$HUD.hide()
	await RenderingServer.frame_post_draw
	var photo: Image = world_frame.crop_photo(get_viewport().get_texture().get_image())
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


func get_world_render_rect() -> Rect2:
	return world_frame.get_render_rect()


func _crop_photo_to_world_rect(photo: Image) -> Image:
	return world_frame.crop_photo(photo)


func open_keypad() -> void:
	if has_flag(ATTIC_COMBINATION_FLAG) or is_instance_valid(keypad) or not player_controls_enabled():
		return
	keypad = KEYPAD_SCENE.instantiate() as Control
	keypad.submitted.connect(_on_keypad_submitted)
	keypad.cancelled.connect(_on_keypad_cancelled)
	$HUD.add_child(keypad)
	_refresh_controls()


func start_sleep_dialog() -> void:
	if transition_locked or has_flag(STORY_DAY_TWO) or not player_controls_enabled():
		return
	dialog_manager.dialog_finished.connect(_on_sleep_dialog_finished, CONNECT_ONE_SHOT)
	dialog_manager.show_dialog(DialogueCatalog.get_messages(&"act1.sleep"))
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
	set_flag(STORY_DAY_TWO)
	transition_locked = false
	_refresh_controls()
	if not has_flag(STORY_WAKE_SHOWN):
		set_flag(STORY_WAKE_SHOWN)
		dialog_manager.show_dialog(DialogueCatalog.get_messages(&"act2.wake"))


func _on_keypad_submitted(is_correct: bool) -> void:
	if not is_instance_valid(keypad):
		return
	keypad.queue_free()
	keypad = null
	if is_correct:
		ending_started = true
		transition_locked = true
		set_flag(ATTIC_COMBINATION_FLAG)
		EventBus.request_audio(&"door_unlock")
		dialog_manager.document_closed.connect(_on_identity_document_closed, CONNECT_ONE_SHOT)
		dialog_manager.show_document(
			IDENTITY_CARD_TEXTURE,
			DialogueCatalog.get_messages(&"act3.id_reveal")
		)
	else:
		dialog_manager.show_dialog(["Zámek kód odmítl."])
	_refresh_controls()


func _on_identity_document_closed() -> void:
	if ending_started:
		set_flag("story.identity_read")
		EventBus.call_deferred("complete_game")


func _on_keypad_cancelled() -> void:
	keypad.queue_free()
	keypad = null
	_refresh_controls()


func set_flag(flag_id: String, value: bool = true) -> void:
	if flag_id.is_empty():
		return
	if has_flag(flag_id) == value:
		return
	flags[flag_id] = value
	flag_changed.emit(flag_id, value)
	StoryProgression.update_attic_readiness(self)


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
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()
	camera.force_update_scroll()
	world_frame.set_room(room)
	world_frame.update_frame()


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
