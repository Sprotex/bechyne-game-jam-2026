extends Node

const HALL := "res://scenes/rooms/hall.tscn"
const CELLAR := "res://scenes/rooms/cellar.tscn"
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().physics_frame
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level._load_room(HALL, "from_entrance")
	var player := level.get_node("Player") as CharacterBody2D
	var hall := level.room
	var hall_exit := hall.get_node("ExitToCellar") as RoomExit
	_check(hall_exit != null, "hall has cellar exit")
	_check(hall_exit.destination_scene_path == CELLAR and hall_exit.destination_arrival_id == "from_hall", "hall cellar exit targets cellar from_hall arrival")
	_check(hall_exit.position == Vector2(150, 211) and hall_exit.wall_side == "north", "cellar exit uses the authored north doorway")
	_check(hall_exit.required_flag.is_empty() and hall_exit.locked_message.is_empty(), "cellar exit has no gate")
	var attic_exit := hall.get_node("ExitToAttic") as RoomExit
	_check(attic_exit.position == Vector2(350, 211) and attic_exit.wall_side == "north", "attic entrance stays next to the cellar entrance")
	_check(attic_exit.required_flag.is_empty() and attic_exit.locked_message.is_empty(), "attic entrance has no gate")
	_check(hall.get_node("Arrivals/from_cellar").position == Vector2(150, 320), "hall cellar arrival stays inside the doorway")
	_check(hall.get_node("Arrivals/from_attic").position == Vector2(550, 300), "hall attic arrival remains separate")
	hall_exit.nearby = true
	_check(level.room == hall, "cellar does not auto-enter from proximity")
	hall_exit._unhandled_input(_interact_event())
	_check(level.room == hall, "cellar exit waits for E interaction")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.scene_file_path == CELLAR, "E enters the cellar")
	var cellar := level.room
	_check(player.global_position == cellar.get_node("Arrivals/from_hall").global_position, "cellar transition uses its from_hall arrival")
	_check(_capsule_clear(level, player.global_position), "cellar arrival is clear for the player capsule")
	_check(Vector2i(cellar.get_node("Background").texture.get_size()) == Vector2i(2000, 377), "cellar keeps the height-fitted aspect frame")
	_check(cellar.get_node("Background").texture.resource_path.ends_with("sklep.png"), "cellar displays the final cellar artwork")
	_check(cellar.find_children("*", "RoomExit", true, false).size() == 1, "cellar has only its hall return route")
	_check(cellar.get_node("ExitToHall").destination_scene_path == HALL, "cellar return targets hall")
	var return_exit := cellar.get_node("ExitToHall") as RoomExit
	_check(return_exit.destination_arrival_id == "from_cellar" and return_exit.wall_side == "north", "cellar return uses hall from_cellar arrival")
	_check(return_exit.required_flag.is_empty() and return_exit.locked_message.is_empty(), "cellar return has no gate")
	return_exit.nearby = true
	_check(level.room == cellar, "cellar does not auto-return from proximity")
	return_exit._unhandled_input(_interact_event())
	_check(level.room == cellar, "cellar return waits for E interaction")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.scene_file_path == HALL, "E returns from cellar to hall")
	var hall_arrival: Vector2 = level.room.get_node("Arrivals/from_cellar").global_position
	_check(absf(player.global_position.x - hall_arrival.x) < 0.01 and absf(player.global_position.y - hall_arrival.y) <= 4.0, "hall transition uses from_cellar arrival")
	_check(_capsule_clear(level, player.global_position), "hall return arrival is clear for the player capsule")
	level.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = self
	AudioManager.stop_sound_effects()
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stop()
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Cellar route verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _capsule_clear(level: Level, position: Vector2) -> bool:
	var player := level.get_node("Player") as CharacterBody2D
	var feet := player.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = Transform2D(player.global_rotation, position) * feet.transform
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return level.get_world_2d().direct_space_state.intersect_shape(query).is_empty()


func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
