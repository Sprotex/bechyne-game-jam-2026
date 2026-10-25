extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := load("res://scenes/level.tscn").instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	level.dialog_manager.hide_dialog()
	var player := level.get_node("Player") as CharacterBody2D
	var feet := player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule := feet.shape as CapsuleShape2D
	_check(capsule.radius == 16.0 and capsule.height == 120.0, "player capsule keeps its authored dimensions")
	_check(is_equal_approx(feet.rotation, PI / 2.0) and feet.position == Vector2(6, -7), "player capsule keeps its feet anchor and rotation")
	_check(player.get_node("Sprite2D") is AnimatedSprite2D, "player animation changes keep the capsule node")
	var cases := [
		{
			"room": "hall", "art": "chodba2.png", "height": 377.0,
			"blocked": [Vector2(765, 260), Vector2(1390, 370)],
			"clear": [Vector2(100, 300), Vector2(1000, 300), Vector2(1900, 310)],
		},
		{
			"room": "living_room", "art": "obyvak.png", "height": 375.0,
			"blocked": [Vector2(550, 274), Vector2(1000, 275), Vector2(1385, 250), Vector2(542, 360), Vector2(1505, 355)],
			"clear": [Vector2(1190, 320), Vector2(1000, 320)],
		},
		{
			"room": "cellar", "art": "sklep.png", "height": 377.0,
			"blocked": [Vector2(420, 207), Vector2(1090, 212), Vector2(1300, 230), Vector2(1410, 230), Vector2(1700, 230)],
			"clear": [Vector2(700, 300), Vector2(1550, 300)],
		},
	]
	for room_case in cases:
		level._load_room("res://scenes/rooms/%s.tscn" % room_case.room, "start")
		await get_tree().physics_frame
		await get_tree().physics_frame
		var background := level.room.get_node("Background") as Sprite2D
		_check(background.texture.resource_path.ends_with(room_case.art), "%s uses the new supplied artwork" % room_case.room)
		_check(level.room.get_background_bounds().size == Vector2(2000, room_case.height), "%s retains the correct native dimensions" % room_case.room)
		var camera := level.get_node("Player/Camera2D") as Camera2D
		_check(camera.zoom.is_equal_approx(Vector2.ONE * level.get_viewport_rect().size.y / room_case.height), "%s fills the viewport height without distorting the artwork" % room_case.room)
		for point in room_case.blocked:
			_check(_point_blocked(level, point), "%s furniture blocks %s" % [room_case.room, point])
			if room_case.room == "cellar":
				_check(Geometry2D.is_point_in_polygon(point, level.room.walkable_outline), "cellar furniture point %s stays inside the walkable room" % point)
		for point in room_case.clear:
			_check(not _point_blocked(level, point), "%s floor remains clear at %s" % [room_case.room, point])
		for marker in level.room.get_node("Arrivals").get_children():
			_check(_arrival_clear(level, marker.global_position), "%s arrival %s is clear for the player's feet" % [room_case.room, marker.name])
		var start := Vector2(1000, 300) if room_case.room == "hall" else Vector2(150, 345) if room_case.room == "cellar" else Vector2(1100, 320)
		var motion := Vector2(1500, 0) if room_case.room == "cellar" else Vector2(-450, 0) if room_case.room == "hall" else Vector2(-850, 0)
		_check(not player.test_move(Transform2D(0, start), motion), "%s has a traversable route between its furniture and foreground" % room_case.room)
		if room_case.room == "cellar":
			_check(background.texture.get_size() == Vector2(2000, 377), "cellar art keeps its native aspect ratio")
			_check(not player.test_move(Transform2D(0, Vector2(150, 345)), Vector2(1500, 0)), "cellar route from staircase to washer stays clear")
			_check(not player.test_move(Transform2D(0, Vector2(1550, 270)), Vector2(80, 0)), "cellar route passes close to the washer footprint")
	level.queue_free()
	await get_tree().process_frame
	AudioManager.stop_sound_effects()
	AudioManager.music_player.stop()
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Room art verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _point_blocked(level: Level, point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = false
	query.collision_mask = 1
	query.exclude = [(level.get_node("Player") as CharacterBody2D).get_rid()]
	return not level.get_world_2d().direct_space_state.intersect_point(query).is_empty()


func _arrival_clear(level: Level, position: Vector2) -> bool:
	var player := level.get_node("Player") as CharacterBody2D
	var feet := player.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = Transform2D(player.global_rotation, position) * feet.transform
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return level.get_world_2d().direct_space_state.intersect_shape(query).is_empty()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
