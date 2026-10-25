extends Node

const ROOM_PATHS := [
	"res://scenes/rooms/main_entrance.tscn",
	"res://scenes/rooms/living_room.tscn",
	"res://scenes/rooms/hall.tscn",
	"res://scenes/rooms/bedroom.tscn",
	"res://scenes/rooms/bathroom.tscn",
	"res://scenes/rooms/attic.tscn",
	"res://scenes/rooms/cellar.tscn",
]
const FEET_OFFSET := Vector2(6.0, -7.0)
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().physics_frame
	level.dialog_manager.hide_dialog()
	var player := level.get_node("Player") as CharacterBody2D
	for room_path in ROOM_PATHS:
		level._load_room(room_path, "start")
		await get_tree().physics_frame
		var room := level.room
		var exits := room.find_children("*", "RoomExit", true, false)
		for exit_node in exits:
			var exit := exit_node as RoomExit
			_check_trigger_inside(room, exit)
			var inward := _inward_direction(exit.wall_side)
			var trigger_shape := exit.get_node("CollisionShape2D") as CollisionShape2D
			var feet_position := trigger_shape.global_position
			for unlocked in [false, true]:
				if not exit.required_flag.is_empty():
					level.flags[exit.required_flag] = unlocked
				room._refresh_exit_gates()
				player.global_position = feet_position - FEET_OFFSET
				await get_tree().physics_frame
				var before := player.global_position
				var collision := player.move_and_collide(-inward * 320.0)
				var hit_perimeter := collision != null and collision.get_collider() == room.get_node("RoomWalls")
				_check(hit_perimeter and player.global_position.distance_to(before) < 320.0, "%s %s exit blocks outward movement (%s)" % [room.name, exit.name, "unlocked" if unlocked else "locked"])
				player.velocity = Vector2.ZERO
				await get_tree().physics_frame
		if room_path.ends_with("cellar.tscn"):
			player.global_position = Vector2(150, 320)
			await get_tree().physics_frame
			_check(player.test_move(player.global_transform, Vector2(0, -120)), "cellar staircase edge blocks outward movement")
			player.global_position = Vector2(1850, 320)
			await get_tree().physics_frame
			_check(player.test_move(player.global_transform, Vector2(150, 0)), "cellar right wall blocks outward movement")
			player.global_position = Vector2(1800, 340)
			await get_tree().physics_frame
			_check(player.test_move(player.global_transform, Vector2(0, 100)), "cellar south wall blocks outward movement")
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
	print("Room bounds verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_trigger_inside(room: Room, exit: RoomExit) -> void:
	var shape := exit.get_node("CollisionShape2D") as CollisionShape2D
	var outline := PackedVector2Array()
	for point in room.walkable_outline:
		outline.append(room.to_global(point))
	_check(Geometry2D.is_point_in_polygon(shape.global_position, outline), "%s %s trigger center is on interior floor" % [room.name, exit.name])


func _inward_direction(wall_side: String) -> Vector2:
	match wall_side:
		"north":
			return Vector2.DOWN
		"south":
			return Vector2.UP
		"west":
			return Vector2.RIGHT
		"east":
			return Vector2.LEFT
	return Vector2.ZERO


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
