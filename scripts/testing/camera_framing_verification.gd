extends RefCounted
class_name CameraFramingVerification

var failures := 0


static func run(level: Level) -> int:
	var verifier := CameraFramingVerification.new()
	await verifier._run(level)
	return verifier.failures


func _run(level: Level) -> void:
	var cases := [
		{"path": "res://scenes/rooms/main_entrance.tscn", "probe": Vector2(1700, 650), "height": 1080.0},
		{"path": "res://scenes/rooms/bathroom.tscn", "probe": Vector2(1050, 390), "height": 563.0},
		{"path": "res://scenes/rooms/bedroom.tscn", "probe": Vector2(800, 370), "height": 563.0},
		{"path": "res://scenes/rooms/hall.tscn", "probe": Vector2(1300, 370), "height": 563.0},
		{"path": "res://scenes/rooms/living_room.tscn", "probe": Vector2(1300, 328), "height": 375.0},
	]
	_check(level.get_node("HUD").layer == 30, "HUD remains on its window-space canvas layer")
	_check(level.dialog_manager.layer == 20 and level.world_frame.layer == 10, "letterbox stays below dialog and HUD layers")
	var player: CharacterBody2D = level.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	for room_case in cases:
		level._load_room(room_case.path, "start")
		await level.get_tree().process_frame
		var bounds := level.room.get_background_bounds()
		var view_size := level.get_viewport_rect().size
		var opening := level.get_world_render_rect()
		var expected_size := Vector2(minf(view_size.x, bounds.size.x), room_case.height)
		_check(opening.size == expected_size, "%s visible world opening is limited to native art size" % level.room.name)
		_check(opening.position == (view_size - opening.size) * 0.5, "%s world opening is centered in the window" % level.room.name)
		_check(camera.zoom == Vector2.ONE, "%s camera keeps native 1x scale" % level.room.name)
		var top := level.letterbox_bars["TopLetterbox"] as ColorRect
		var bottom := level.letterbox_bars["BottomLetterbox"] as ColorRect
		_check(top.color.a == 1.0 and top.size.y == opening.position.y, "%s top outside-art area is opaque" % level.room.name)
		_check(bottom.color.a == 1.0 and bottom.position.y == opening.end.y, "%s bottom outside-art area is opaque" % level.room.name)
		player.global_position = room_case.probe
		await level.get_tree().process_frame
		camera.force_update_scroll()
		var half_opening := opening.size * 0.5
		var expected_x := clampf(player.global_position.x, bounds.position.x + half_opening.x, bounds.end.x - half_opening.x)
		var expected_y := clampf(player.global_position.y, bounds.position.y + half_opening.y, bounds.end.y - half_opening.y)
		var camera_center := camera.get_screen_center_position()
		_check(absf(camera_center.x - expected_x) < 2.0 and absf(camera_center.y - expected_y) < 2.0, "%s camera follows within native image bounds" % level.room.name)
		var visible_world := Rect2(camera_center - half_opening, opening.size)
		_check(bounds.encloses(visible_world), "%s effective visible world rectangle stays inside its artwork" % level.room.name)
		if level.room.name == "Bathroom" or level.room.name == "MainEntrance":
			var screenshot := Image.create(roundi(view_size.x), roundi(view_size.y), false, Image.FORMAT_RGBA8)
			var photo := level._crop_photo_to_world_rect(screenshot)
			_check(Vector2(photo.get_size()) == opening.size, "%s photo crop excludes the letterbox" % level.room.name)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)
