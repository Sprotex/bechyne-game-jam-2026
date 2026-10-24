extends Node

var failures := 0
var saved_progress := PackedByteArray()
var had_progress := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var progress_path := ProjectSettings.globalize_path("user://game_progress.cfg")
	had_progress = FileAccess.file_exists(progress_path)
	if had_progress:
		var previous := FileAccess.open(progress_path, FileAccess.READ)
		saved_progress = previous.get_buffer(previous.get_length())
	var level := load("res://scenes/level.tscn").instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	_check(level.room.room_title == "VSTUPNÍ HALA", "initial room loads")
	_check(level.dialog_manager.is_dialog_open(), "opening dialog is shown on arrival")
	_check(not level.player_controls_enabled(), "opening dialog blocks controls")
	_check_room_links()
	await _check_camera_and_art_bounds(level)
	await _check_duplicate_exit()
	await _check_room_collisions(level)
	await _check_modal_controls(level)
	await _check_fade_and_arrival(level)
	await _check_pickup_persistence(level)
	level.queue_free()
	await get_tree().process_frame
	if had_progress:
		var restore := FileAccess.open(progress_path, FileAccess.WRITE)
		restore.store_buffer(saved_progress)
	else:
		DirAccess.remove_absolute(progress_path)
	print("Refactor verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_room_links() -> void:
	var paths := [
		"res://scenes/rooms/main_entrance.tscn",
		"res://scenes/rooms/hall.tscn",
		"res://scenes/rooms/bathroom.tscn",
		"res://scenes/rooms/bedroom.tscn",
		"res://scenes/rooms/living_room.tscn",
	]
	var count := 0
	for path in paths:
		var room := (load(path) as PackedScene).instantiate() as Room
		for node in room.find_children("*", "RoomExit", true, false):
			var exit := node as RoomExit
			var destination := (load(exit.destination_scene_path) as PackedScene).instantiate() as Room
			_check(destination.get_node_or_null("Arrivals/" + exit.destination_arrival_id) != null, "%s has arrival %s" % [path.get_file(), exit.destination_arrival_id])
			destination.free()
			count += 1
		room.free()
	_check(count == 8, "all eight existing directed room links are present")


func _check_camera_and_art_bounds(level: Level) -> void:
	var room_cases := [
		{"path": "res://scenes/rooms/main_entrance.tscn", "probe": Vector2(1700, 650)},
		{"path": "res://scenes/rooms/bathroom.tscn", "probe": Vector2(1050, 390)},
		{"path": "res://scenes/rooms/bedroom.tscn", "probe": Vector2(800, 370)},
		{"path": "res://scenes/rooms/hall.tscn", "probe": Vector2(1300, 370)},
		{"path": "res://scenes/rooms/living_room.tscn", "probe": Vector2(1300, 328)},
	]
	var player: CharacterBody2D = level.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var viewport_size := level.get_viewport_rect().size
	for room_case in room_cases:
		level._load_room(room_case.path, "start")
		await get_tree().physics_frame
		var room := level.room
		var bounds := room.get_background_bounds()
		var expected_size: Vector2 = room.get_node("Background").texture.get_size()
		_check(bounds.size == expected_size, "%s background uses its native bounds" % room.name)
		_check(room.has_node("RoomWalls") and room.get_node("RoomWalls").get_child_count() >= 4, "%s builds its authored outline collisions" % room.name)
		_check(room.has_node("FurnitureCollisions") and room.get_node("FurnitureCollisions").get_child_count() > 0, "%s has room-specific furniture collisions" % room.name)
		var points_inside := true
		for point in room.walkable_outline:
			if point.x < bounds.position.x or point.x > bounds.end.x or point.y < bounds.position.y or point.y > bounds.end.y:
				points_inside = false
		_check(points_inside, "%s walkable outline stays within its background" % room.name)
		player.global_position = room_case.probe
		await get_tree().process_frame
		camera.force_update_scroll()
		var min_x := bounds.position.x + viewport_size.x * 0.5
		var max_x := bounds.end.x - viewport_size.x * 0.5
		var expected_x := (bounds.position.x + bounds.end.x) * 0.5 if max_x < min_x else clampf(player.global_position.x, min_x, max_x)
		var expected_y := (bounds.position.y + bounds.end.y) * 0.5
		if bounds.size.y >= viewport_size.y:
			expected_y = clampf(player.global_position.y, bounds.position.y + viewport_size.y * 0.5, bounds.end.y - viewport_size.y * 0.5)
		var camera_center := camera.get_screen_center_position()
		_check(absf(camera_center.x - expected_x) < 2.0 and absf(camera_center.y - expected_y) < 2.0, "%s camera follows within image limits" % room.name)
		await get_tree().physics_frame
		var hits_top_boundary := player.test_move(player.global_transform, Vector2(0, -120))
		_check(hits_top_boundary, "%s top walkable edge blocks the player" % room.name)


func _check_duplicate_exit() -> void:
	var room := (load("res://scenes/rooms/main_entrance.tscn") as PackedScene).instantiate() as Room
	var second := (load("res://scenes/objects/room_exit.tscn") as PackedScene).instantiate() as RoomExit
	second.name = "SecondSouthExit"
	second.position = Vector2(1100, 1060)
	second.wall_side = "south"
	second.destination_scene_path = "res://scenes/rooms/bedroom.tscn"
	second.destination_arrival_id = "from_hall"
	room.add_child(second)
	get_tree().root.add_child(room)
	await get_tree().process_frame
	var south_count := 0
	for node in room.find_children("*", "RoomExit", true, false):
		if (node as RoomExit).wall_side == "south":
			south_count += 1
	_check(south_count == 2, "two south exits retain independent destinations and arrivals")
	_check(room.get_node("RoomWalls").get_child_count() >= 7, "room builds physical wall segments around both south openings")
	room.queue_free()
	await get_tree().process_frame


func _check_room_collisions(level: Level) -> void:
	level._load_room("res://scenes/rooms/main_entrance.tscn", "start")
	await get_tree().physics_frame
	var player: CharacterBody2D = level.get_node("Player")
	var sprite: Sprite2D = player.get_node("Sprite2D")
	var body_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	_check(sprite.position.y < body_shape.position.y and body_shape.position.y < 0.0, "player art and hit shape align above the feet anchor")
	_check(player.vertical_speed_ratio < 1.0, "vertical speed is tunable below horizontal speed")
	player.global_position = Vector2(1225, 700)
	await get_tree().physics_frame
	_check(player.test_move(player.global_transform, Vector2(0, -100)), "entrance chest collision blocks the walk path")
	player.global_position = Vector2(1700, 650)
	await get_tree().physics_frame
	_check(player.test_move(player.global_transform, Vector2(0, -120)), "entrance outline blocks a closed threshold")
	player.global_position = Vector2(1500, 700)
	await get_tree().physics_frame


func _check_modal_controls(level: Level) -> void:
	var movement: CharacterBody2D = level.get_node("Player")
	var preview = level.room.get_node("MessagePreviewInteractor")
	level.dialog_manager.show_dialog(["one", "two"])
	_check(not level.player_controls_enabled(), "dialog blocks controls")
	movement.velocity = Vector2(100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(movement.velocity == Vector2.ZERO, "blocked movement zeroes player velocity")
	preview.nearby = true
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	preview._unhandled_input(event)
	_check(preview.preview_index == 0, "modal dialog blocks world interactions")
	level.request_room_transition("res://scenes/rooms/hall.tscn", "from_entrance")
	_check(level.room.room_title == "VSTUPNÍ HALA", "modal dialog blocks exit transitions")
	level.dialog_manager._input(event)
	_check(not level.player_controls_enabled(), "dialog advance remains modal")
	level.dialog_manager._input(event)
	level.dialog_manager._input(event)
	level.dialog_manager._input(event)
	await get_tree().process_frame
	_check(level.player_controls_enabled(), "dialog close restores controls")
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	level.dialog_manager._show_generated_image("test.png", image.save_png_to_buffer())
	_check(level.dialog_manager.is_modal_open() and not level.player_controls_enabled(), "image preview blocks controls")
	level.request_room_transition("res://scenes/rooms/hall.tscn", "from_entrance")
	_check(level.room.room_title == "VSTUPNÍ HALA", "image preview blocks exit transitions")
	level.dialog_manager._input(event)
	_check(not level.dialog_manager.is_modal_open() and level.player_controls_enabled(), "image close restores controls")


func _check_fade_and_arrival(level: Level) -> void:
	level.request_room_transition("res://scenes/rooms/hall.tscn", "from_entrance")
	_check(not level.player_controls_enabled(), "fade transition locks controls")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "CHODBA", "entrance exit loads hall")
	_check(level.get_node("Player") != null, "player stays in the level across room transitions")
	_check(level.player_controls_enabled(), "fade completion restores controls")
	level.request_room_transition("res://scenes/rooms/main_entrance.tscn", "from_hall")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "VSTUPNÍ HALA", "reverse exit returns to entrance")
	_check(level.get_node("Player").global_position == Vector2(200, 916), "arrival marker positions player at return doorway")
	Input.action_press("move_left")
	await get_tree().create_timer(0.16).timeout
	Input.action_release("move_left")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "CHODBA", "player can cross a configured exit threshold")
	Input.action_press("move_right")
	await get_tree().create_timer(0.16).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "VSTUPNÍ HALA", "player can return through the paired threshold")


func _check_pickup_persistence(level: Level) -> void:
	var pickup := (load("res://scenes/objects/persistent_pickup.tscn") as PackedScene).instantiate() as PersistentPickup
	pickup.item_id = "verification.pickup"
	level.room.add_child(pickup)
	await get_tree().process_frame
	pickup._on_body_entered(level.get_node("Player"))
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	pickup._unhandled_input(event)
	_check(level.has_flag("verification.pickup") and not pickup.visible, "pickup stores flag and hides")
	level._load_room("res://scenes/rooms/main_entrance.tscn", "start")
	var revisited := (load("res://scenes/objects/persistent_pickup.tscn") as PackedScene).instantiate() as PersistentPickup
	revisited.item_id = "verification.pickup"
	level.room.add_child(revisited)
	await get_tree().process_frame
	_check(not revisited.visible, "collected pickup stays hidden after room revisit")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)
