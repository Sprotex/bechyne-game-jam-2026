extends Node

const ATTIC := "res://scenes/rooms/attic.tscn"
const HALL := "res://scenes/rooms/hall.tscn"
const CELLAR := "res://scenes/rooms/cellar.tscn"
const CAPSULE_FEET_OFFSET := Vector2(6.0, -7.0)
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
	var hall := level.room
	var player := level.get_node("Player") as CharacterBody2D
	var attic_exit := hall.get_node("ExitToAttic") as RoomExit
	_check(not level.has_flag("story.day_two") and not level.has_flag("story.diagnosis_read") and not level.has_flag("story.attic_unlocked"), "attic route starts with no story prerequisites")
	_check(attic_exit.required_flag.is_empty() and attic_exit.locked_message.is_empty(), "hall attic stairs have no story gate or locked dialogue")
	attic_exit.nearby = true
	_check(level.room == hall, "attic route does not transition before interaction")
	attic_exit._unhandled_input(_interact_event())
	_check(level.room == hall and not level.dialog_manager.is_dialog_open(), "attic stair interaction is not blocked by a locked dialogue")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.scene_file_path == ATTIC, "hall stair exit enters attic with empty story flags")
	var attic := level.room
	_check(Vector2i(attic.get_node("Background").texture.get_size()) == Vector2i(2000, 377), "attic art retains native aspect dimensions")
	var camera := player.get_node("Camera2D") as Camera2D
	_check(camera.zoom.x == camera.zoom.y, "attic art is scaled without distortion")
	_check(_capsule_clear(level, attic.get_node("Arrivals/from_hall").global_position), "stair landing fits the player capsule")
	_check(_capsule_clear(level, attic.get_node("Arrivals/start").global_position), "start arrival fits the player capsule")
	_check(_point_blocked(level, Vector2(1200, 255)), "cabinet collision covers its illustrated footprint")
	_check(_point_blocked(level, Vector2(1080, 330)), "left box collision covers its illustrated footprint")
	_check(_point_blocked(level, Vector2(1500, 282)), "right boxes collision covers their illustrated footprint")
	_check(not _point_blocked(level, Vector2(800, 350)), "rug and floor remain traversable")
	player.global_position = Vector2(275, 366)
	await get_tree().physics_frame
	var route_collision := player.move_and_collide(Vector2(1000, 0))
	_check(route_collision == null, "capsule can walk from stairs along the floor to the identity location")
	_check(Vector2(1385, 330).distance_to(player.global_position + CAPSULE_FEET_OFFSET) <= 120.0, "clear floor route reaches combination lock interaction range")
	_check(attic.get_node_or_null("IdentityCard") == null, "identity document has no standalone pickup bypass")
	_check(attic.get_node_or_null("CombinationLock") != null, "attic identity location is accessed through the combination lock")
	var return_exit := attic.get_node("ExitToHall") as RoomExit
	_check(return_exit.destination_scene_path == HALL and return_exit.destination_arrival_id == "from_attic", "attic return points to hall from_attic arrival")
	return_exit.nearby = true
	return_exit._unhandled_input(_interact_event())
	await get_tree().create_timer(0.32).timeout
	_check(level.room.scene_file_path == HALL, "attic return interaction transitions back to hall")
	_check(_capsule_clear(level, level.room.get_node("Arrivals/from_attic").global_position), "hall return arrival fits the player capsule")
	_check(not level.has_flag("story.day_two") and not level.has_flag("story.diagnosis_read") and not level.has_flag("story.attic_unlocked"), "cellar route also starts with empty story flags")
	var cellar_exit := level.room.get_node("ExitToCellar") as RoomExit
	_check(cellar_exit != null and cellar_exit.required_flag.is_empty() and cellar_exit.locked_message.is_empty(), "hall cellar stairs have no story gate or locked dialogue")
	if cellar_exit != null:
		cellar_exit.nearby = true
		await get_tree().physics_frame
		_check(level.room.scene_file_path == HALL, "cellar route does not travel on proximity alone")
		cellar_exit._unhandled_input(_interact_event())
		_check(level.room.scene_file_path == HALL and not level.dialog_manager.is_dialog_open(), "cellar stairs wait for E without showing locked dialogue")
		await get_tree().create_timer(0.32).timeout
		_check(level.room.scene_file_path == CELLAR, "E enters cellar with empty story flags")
		var cellar := level.room
		_check(_capsule_clear(level, cellar.get_node("Arrivals/from_hall").global_position), "cellar arrival fits the player capsule")
		var cellar_background := cellar.get_node_or_null("Background") as Sprite2D
		_check(cellar_background != null and cellar_background.texture != null and Vector2i(cellar_background.texture.get_size()) == Vector2i(2000, 377) and cellar_background.texture.resource_path.ends_with("sklep.png"), "cellar art uses the native 2000x377 frame")
		var cellar_camera := player.get_node("Camera2D") as Camera2D
		_check(cellar_camera.limit_bottom - cellar_camera.limit_top == 377, "cellar camera bounds fit its room height")
		_check(not _point_blocked(level, Vector2(100, 320)), "cellar floor remains traversable")
		var return_cellar := cellar.get_node("ExitToHall") as RoomExit
		_check(return_cellar != null and return_cellar.destination_scene_path == HALL and return_cellar.destination_arrival_id == "from_cellar", "cellar return points to hall from_cellar arrival")
		if return_cellar != null:
			return_cellar.nearby = true
			_check(level.room.scene_file_path == CELLAR, "cellar does not auto-return from proximity")
			return_cellar._unhandled_input(_interact_event())
			await get_tree().create_timer(0.32).timeout
			_check(level.room.scene_file_path == HALL, "cellar E interaction returns to hall")
			_check(_capsule_clear(level, level.room.get_node("Arrivals/from_cellar").global_position), "hall cellar return arrival fits the player capsule")
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
	print("Attic route verification: %d failures" % failures)
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


func _point_blocked(level: Level, point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [(level.get_node("Player") as CharacterBody2D).get_rid()]
	return not level.get_world_2d().direct_space_state.intersect_point(query).is_empty()


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
