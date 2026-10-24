extends Node2D
class_name Level

const OPTIONS_SCENE := preload("res://scenes/options.tscn")
const INITIAL_ROOM := "res://scenes/rooms/main_entrance.tscn"
const START_POSITION := Vector2(1080, 560)

var room: Room
var transition_locked := false
var options_screen: Control
var dialog_manager: DialogManager
var flags: Dictionary = {}


func _ready() -> void:
	_load_room(INITIAL_ROOM, "start")
	options_screen = OPTIONS_SCENE.instantiate()
	options_screen.hide()
	options_screen.connect("back_pressed", _close_options)
	$HUD.add_child(options_screen)
	dialog_manager = preload("res://scenes/dialog_manager.tscn").instantiate() as DialogManager
	add_child(dialog_manager)
	dialog_manager.modal_changed.connect(_refresh_controls)
	UserMessages.message_delivered.connect(_on_message_delivered)
	_refresh_controls()
	_update_room_label()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		options_screen.visible = not options_screen.visible
		_refresh_controls()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("take_photo"):
		_take_photo()
		get_viewport().set_input_as_handled()


func _take_photo() -> void:
	if not has_flag("item.camera") or not player_controls_enabled():
		return
	$HUD.hide()
	await RenderingServer.frame_post_draw
	var photo := get_viewport().get_texture().get_image()
	$HUD.show()
	var result := UserMessages.deliver_user_picture(photo, "room_photo.png")
	if result == OK and not OS.has_feature("web"):
		dialog_manager.show_dialog(["Photo saved to your user messages folder."])
	elif result != OK:
		dialog_manager.show_dialog(["The photo could not be saved. Error code: %d" % result])


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
	_update_room_label()


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
	$Player.controls_enabled = not transition_locked and not dialog_manager.is_modal_open() and not options_screen.visible


func _on_message_delivered(file_name: String, content: PackedByteArray) -> void:
	dialog_manager.show_generated_file(file_name, content)


func _update_room_label() -> void:
	if is_instance_valid(room):
		$HUD/RoomLabel.text = room.room_title
