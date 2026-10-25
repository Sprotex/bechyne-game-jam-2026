extends Node

var failures := 0
var saved_progress := PackedByteArray()
var had_progress := false
const CAMERA_FRAMING_VERIFICATION = preload("res://scripts/testing/camera_framing_verification.gd")
const ROOM_EXIT_VERIFICATION = preload("res://scripts/testing/room_exit_verification_helper.gd")
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
	await _check_lights_persist(level)
	await _check_camera_and_art_bounds(level)
	failures += await CAMERA_FRAMING_VERIFICATION.run(level)
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
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Refactor verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
func _check_room_links() -> void:
	var paths := [
		"res://scenes/rooms/main_entrance.tscn",
		"res://scenes/rooms/hall.tscn",
		"res://scenes/rooms/bathroom.tscn",
		"res://scenes/rooms/bedroom.tscn",
		"res://scenes/rooms/living_room.tscn",
		"res://scenes/rooms/attic.tscn",
		"res://scenes/rooms/cellar.tscn",
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
	_check(count == 12, "all twelve directed room links are present")
	var bathroom := (load("res://scenes/rooms/bathroom.tscn") as PackedScene).instantiate() as Room
	_check(bathroom.has_node("PhotoCamera") and bathroom.has_node("CameraPhotoSpot"), "bathroom camera and photo spot remain present")
	_check(bathroom.get_node("PhotoCamera").position == Vector2(1020, 435), "bathroom camera keeps its authored position")
	_check(bathroom.get_node("CameraPhotoSpot").position == Vector2(1220, 430), "bathroom photo spot keeps its authored position")
	bathroom.free()

func _check_lights_persist(level: Level) -> void:
	var paths := [
		"res://scenes/rooms/main_entrance.tscn",
		"res://scenes/rooms/hall.tscn",
		"res://scenes/rooms/living_room.tscn",
		"res://scenes/rooms/bedroom.tscn",
		"res://scenes/rooms/bathroom.tscn",
	]
	for path in paths:
		level._load_room(path, "start")
		await get_tree().process_frame
		var lights := level.room.find_children("*", "PointLight2D", true, false)
		var switch := level.room.get_node("LightSwitch/Sprite2D") as Sprite2D
		_check(not level.room.lights_are_on, "%s starts with its own lights off" % path.get_file())
		_check(not lights.is_empty(), "%s creates room lights" % path.get_file())
		for light in lights:
			_check(not (light as PointLight2D).enabled, "%s initializes each light off" % path.get_file())
		_check(switch.texture.resource_path.ends_with("vypinac_vypnuto.png"), "%s switch shows off state" % path.get_file())
		if path == paths[0]:
			level.room.set_lights_enabled(true)
			_check(level.room.lights_are_on, "entrance lights can be turned on")
	level._load_room(paths[1], "start")
	await get_tree().process_frame
	_check(not level.room.lights_are_on, "another room keeps its own lights off")
	level._load_room(paths[0], "start")
	await get_tree().process_frame
	var revisited_lights := level.room.find_children("*", "PointLight2D", true, false)
	var revisited_switch := level.room.get_node("LightSwitch/Sprite2D") as Sprite2D
	_check(level.room.lights_are_on, "room light state returns when revisiting")
	for light in revisited_lights:
		_check((light as PointLight2D).enabled, "revisited room lights restore their state")
	_check(revisited_switch.texture.resource_path.ends_with("vypinac_zapnuto.png"), "revisited switch restores its state")
	level.room.set_lights_enabled(false)
func _check_camera_and_art_bounds(level: Level) -> void:
	var room_cases := [
		{"path": "res://scenes/rooms/main_entrance.tscn", "probe": Vector2(1750, 440), "native_size": Vector2(2000, 563)},
		{"path": "res://scenes/rooms/bathroom.tscn", "probe": Vector2(1050, 390), "native_size": Vector2(2000, 563)},
		{"path": "res://scenes/rooms/bedroom.tscn", "probe": Vector2(800, 370), "native_size": Vector2(2000, 563)},
		{"path": "res://scenes/rooms/hall.tscn", "probe": Vector2(1000, 300), "native_size": Vector2(2000, 377)},
		{"path": "res://scenes/rooms/living_room.tscn", "probe": Vector2(1300, 328), "native_size": Vector2(2000, 375)},
		{"path": "res://scenes/rooms/attic.tscn", "probe": Vector2(275, 320), "native_size": Vector2(2000, 377)},
		{"path": "res://scenes/rooms/cellar.tscn", "probe": Vector2(1000, 320), "native_size": Vector2(2000, 377)},
	]
	var player: CharacterBody2D = level.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var viewport_size := level.get_viewport_rect().size
	for room_case in room_cases:
		level._load_room(room_case.path, "start")
		await get_tree().physics_frame
		var room := level.room
		var bounds := room.get_background_bounds()
		var background := room.get_node("Background") as Sprite2D
		var expected_size: Vector2 = room_case.native_size
		_check(background.texture.get_size() == expected_size, "%s texture matches its native source dimensions" % room.name)
		_check(background.scale == Vector2.ONE and background.global_transform.get_scale().is_equal_approx(Vector2.ONE), "%s background transform stays at native scale" % room.name)
		_check(bounds.size == expected_size, "%s camera bounds use the native image extents" % room.name)
		_check(camera.zoom.is_equal_approx(Vector2.ONE * level.get_viewport_rect().size.y / bounds.size.y), "%s camera fits the room height uniformly" % room.name)
		_check(camera.limit_left == floori(bounds.position.x) and camera.limit_top == floori(bounds.position.y) and camera.limit_right == ceili(bounds.end.x) and camera.limit_bottom == ceili(bounds.end.y), "%s camera limits match the native image edges" % room.name)
		_check(room.has_node("RoomWalls") and room.get_node("RoomWalls").get_child_count() >= 4, "%s builds its authored outline collisions" % room.name)
		_check(room.has_node("FurnitureCollisions") and room.get_node("FurnitureCollisions").get_child_count() > 0, "%s furniture collisions match its room content" % room.name)
		var points_inside := true
		for point in room.walkable_outline:
			if point.x < bounds.position.x or point.x > bounds.end.x or point.y < bounds.position.y or point.y > bounds.end.y:
				points_inside = false
		_check(points_inside, "%s walkable outline stays within its background" % room.name)
		player.global_position = room_case.probe
		await get_tree().process_frame
		camera.force_update_scroll()
		var half_viewport := viewport_size / camera.zoom * 0.5
		var min_x := bounds.position.x + half_viewport.x
		var max_x := bounds.end.x - half_viewport.x
		var expected_x := (bounds.position.x + bounds.end.x) * 0.5 if max_x < min_x else clampf(player.global_position.x, min_x, max_x)
		var expected_y := (bounds.position.y + bounds.end.y) * 0.5
		if bounds.size.y >= half_viewport.y * 2.0:
			expected_y = clampf(player.global_position.y, bounds.position.y + half_viewport.y, bounds.end.y - half_viewport.y)
		var camera_center := camera.get_screen_center_position()
		_check(absf(camera_center.x - expected_x) < 2.0 and absf(camera_center.y - expected_y) < 2.0, "%s camera follows within image limits" % room.name)
		await get_tree().physics_frame
		var hits_top_boundary := player.test_move(player.global_transform, Vector2(0, -120))
		_check(hits_top_boundary, "%s top walkable edge blocks the player" % room.name)
func _check_duplicate_exit() -> void:
	var main_scene := load("res://scenes/rooms/main_entrance.tscn") as PackedScene
	var baseline := main_scene.instantiate() as Room; get_tree().root.add_child(baseline)
	await get_tree().process_frame
	var baseline_segments := baseline.get_node("RoomWalls").get_child_count()
	baseline.queue_free(); await get_tree().process_frame
	var room := main_scene.instantiate() as Room
	var second := (load("res://scenes/objects/room_exit.tscn") as PackedScene).instantiate() as RoomExit
	second.name = "SecondSouthExit"; second.position = Vector2(650, 555)
	second.wall_side = "south"; second.destination_scene_path = "res://scenes/rooms/living_room.tscn"
	second.destination_arrival_id = "from_entrance"
	room.add_child(second)
	get_tree().root.add_child(room)
	await get_tree().process_frame
	var south_count := 0
	for node in room.find_children("*", "RoomExit", true, false):
		if (node as RoomExit).wall_side == "south":
			south_count += 1
	_check(south_count == 2, "two south exits retain independent destinations and arrivals")
	var wall_segments := room.get_node("RoomWalls").get_child_count()
	_check(second.position == Vector2(650, 555), "exit root keeps its authored position for wall topology")
	_check(second.get_node("CollisionShape2D").position == Vector2(0, -65), "south exit interaction area stays on the walkable side")
	_check(second.destination_scene_path == "res://scenes/rooms/living_room.tscn" and second.destination_arrival_id == "from_entrance", "second exit keeps its own destination and arrival")
	_check(wall_segments == baseline_segments, "adding an exit leaves the continuous room perimeter unchanged")
	room.queue_free()
	await get_tree().process_frame
func _check_room_collisions(level: Level) -> void:
	var player: CharacterBody2D = level.get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite2D")
	var body_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	_check(sprite.position.y < body_shape.position.y and body_shape.position.y < 0.0, "player art and hit shape align above the feet anchor")
	_check(player.vertical_speed_ratio < 1.0, "vertical speed is tunable below horizontal speed")
	var cases := [
		{"path": "res://scenes/rooms/main_entrance.tscn", "origin": Vector2(1225, 500), "motion": Vector2(0, 100), "description": "entrance chest footprint blocks the walk path"},
		{"path": "res://scenes/rooms/hall.tscn", "origin": Vector2(765, 320), "motion": Vector2(0, -80), "description": "hall laundry footprint blocks the walk path"},
		{"path": "res://scenes/rooms/bedroom.tscn", "origin": Vector2(700, 450), "motion": Vector2(-180, 0), "description": "bed footprint blocks the walk path"},
		{"path": "res://scenes/rooms/living_room.tscn", "origin": Vector2(700, 330), "motion": Vector2(0, -100), "description": "living room sofa footprint blocks the walk path"},
		{"path": "res://scenes/rooms/bathroom.tscn", "origin": Vector2(770, 420), "motion": Vector2(0, -160), "description": "bathroom vanity footprint blocks the walk path"},
	]
	for collision_case in cases:
		level._load_room(collision_case.path, "start")
		await get_tree().physics_frame
		player.global_position = collision_case.origin
		await get_tree().physics_frame
		_check(player.test_move(player.global_transform, collision_case.motion), collision_case.description)
	level._load_room("res://scenes/rooms/main_entrance.tscn", "start")
	await get_tree().physics_frame
	player.global_position = Vector2(1000, 400)
	await get_tree().physics_frame
	_check(player.test_move(player.global_transform, Vector2(0, -120)), "entrance outline blocks the upper walkable edge")
	player.global_position = Vector2(1750, 440)
	await get_tree().physics_frame

func _check_modal_controls(level: Level) -> void:
	var movement: CharacterBody2D = level.get_node("Player")
	var light_switch := level.room.get_node("LightSwitch")
	var lights_before := level.room.lights_are_on
	level.dialog_manager.show_dialog(["První zpráva.", "Druhá zpráva."])
	_check(not level.player_controls_enabled(), "dialog blocks controls")
	movement.velocity = Vector2(100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(movement.velocity == Vector2.ZERO, "blocked movement zeroes player velocity")
	light_switch.nearby = true
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	light_switch._unhandled_input(event)
	_check(level.room.lights_are_on == lights_before, "modal dialog blocks world interactions")
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
	_check(is_equal_approx(level.get_world_render_rect().size.y, level.get_viewport_rect().size.y), "transition fills viewport height with hall artwork")
	_check(level.player_controls_enabled(), "fade completion restores controls")
	level.request_room_transition("res://scenes/rooms/main_entrance.tscn", "from_hall")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "VSTUPNÍ HALA", "reverse exit returns to entrance")
	_check(level.get_node("Player").global_position == Vector2(240, 440), "arrival marker positions player at the west doorway")
	_check(is_equal_approx(level.get_world_render_rect().size.y, level.get_viewport_rect().size.y), "transition fills viewport height with entrance artwork")
	var player: CharacterBody2D = level.get_node("Player")
	player.global_position = Vector2(170, 440)
	await get_tree().physics_frame
	_check(player.test_move(player.global_transform, Vector2(-200, 0)), "entrance doorway remains physically blocked outward")
	Input.action_press("move_left")
	await get_tree().create_timer(0.16).timeout
	Input.action_release("move_left")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "VSTUPNÍ HALA", "walking through a doorway does not transition automatically")
	ROOM_EXIT_VERIFICATION.interact(level.room.get_node("ExitToHall"), player)
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "CHODBA", "player can cross a configured exit threshold")
	player.global_position = Vector2(1850, 270)
	await get_tree().physics_frame
	_check(player.test_move(player.global_transform, Vector2(200, 0)), "hall doorway remains physically blocked outward")
	Input.action_press("move_right")
	await get_tree().create_timer(0.16).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.32).timeout
	_check(level.room.room_title == "CHODBA", "walking through a paired doorway does not transition automatically")
	ROOM_EXIT_VERIFICATION.interact(level.room.get_node("ExitToEntrance"), player)
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
