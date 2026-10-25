extends RefCounted
class_name CameraFramingVerification

var failures := 0


static func run(level: Level) -> int:
	var verifier: Variant = load("res://scripts/testing/camera_framing_verification.gd").new()
	await verifier._run(level)
	return verifier.failures


func _run(level: Level) -> void:
	var cases := [
		{"path": "res://scenes/rooms/main_entrance.tscn", "probe": Vector2(1750, 440), "height": 563.0},
		{"path": "res://scenes/rooms/bathroom.tscn", "probe": Vector2(1050, 390), "height": 563.0},
		{"path": "res://scenes/rooms/bedroom.tscn", "probe": Vector2(800, 370), "height": 563.0},
		{"path": "res://scenes/rooms/hall.tscn", "probe": Vector2(1000, 300), "height": 377.0},
		{"path": "res://scenes/rooms/living_room.tscn", "probe": Vector2(1300, 328), "height": 375.0},
		{"path": "res://scenes/rooms/attic.tscn", "probe": Vector2(275, 320), "height": 377.0},
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
		var expected_zoom: float = view_size.y / room_case.height
		var expected_size := Vector2(minf(view_size.x, bounds.size.x * expected_zoom), view_size.y)
		_check(opening.size.is_equal_approx(expected_size), "%s artwork fills the viewport height" % level.room.name)
		_check(opening.position == (view_size - opening.size) * 0.5, "%s world opening is centered in the window" % level.room.name)
		_check(camera.zoom.is_equal_approx(Vector2.ONE * expected_zoom), "%s uniform camera zoom preserves art and collision proportions" % level.room.name)
		var top := level.letterbox_bars["TopLetterbox"] as ColorRect
		var bottom := level.letterbox_bars["BottomLetterbox"] as ColorRect
		_check(top.color.a == 1.0 and top.size.y == opening.position.y, "%s top outside-art area is opaque" % level.room.name)
		_check(bottom.color.a == 1.0 and bottom.position.y == opening.end.y, "%s bottom outside-art area is opaque" % level.room.name)
		player.global_position = room_case.probe
		await level.get_tree().process_frame
		camera.force_update_scroll()
		var half_opening := opening.size / camera.zoom * 0.5
		var expected_x := clampf(player.global_position.x, bounds.position.x + half_opening.x, bounds.end.x - half_opening.x)
		var expected_y := clampf(player.global_position.y, bounds.position.y + half_opening.y, bounds.end.y - half_opening.y)
		var camera_center := camera.get_screen_center_position()
		_check(absf(camera_center.x - expected_x) < 2.0 and absf(camera_center.y - expected_y) < 2.0, "%s camera follows within native image bounds" % level.room.name)
		var visible_world := Rect2(camera_center - half_opening, opening.size / camera.zoom)
		var within_bounds := visible_world.position.x >= bounds.position.x - 0.5
		within_bounds = within_bounds and visible_world.position.y >= bounds.position.y - 0.5
		within_bounds = within_bounds and visible_world.end.x <= bounds.end.x + 0.5
		within_bounds = within_bounds and visible_world.end.y <= bounds.end.y + 0.5
		_check(within_bounds, "%s effective visible world rectangle %s stays inside %s" % [level.room.name, visible_world, bounds])
		if level.room.name == "Bathroom" or level.room.name == "MainEntrance":
			var screenshot := Image.create(roundi(view_size.x), roundi(view_size.y), false, Image.FORMAT_RGBA8)
			var photo := level._crop_photo_to_world_rect(screenshot)
			_check(Vector2(photo.get_size()) == opening.size, "%s photo crop excludes the letterbox" % level.room.name)
		await _check_resizing(level)


func _check_resizing(level: Level) -> void:
	var window := level.get_window()
	var original_size := window.size
	var bounds := level.room.get_background_bounds()
	var camera := level.get_node("Player/Camera2D") as Camera2D
	for window_size in [Vector2i(1280, 720), Vector2i(1000, 1000), Vector2i(2560, 1080)]:
		window.size = window_size
		await level.get_tree().process_frame
		await level.get_tree().process_frame
		var viewport_size := level.get_viewport_rect().size
		_check(camera.zoom.is_equal_approx(Vector2.ONE * viewport_size.y / bounds.size.y), "%s resize to %s recalculates uniform height-fit zoom" % [level.room.name, window_size])
		_check(is_equal_approx(level.get_world_render_rect().size.y, viewport_size.y), "%s resize keeps the full room height visible" % level.room.name)
		_check(level.room.get_background_bounds() == bounds, "%s resize preserves world geometry and collision coordinates" % level.room.name)
	window.size = original_size
	await level.get_tree().process_frame
	await level.get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)
