extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level._load_room("res://scenes/rooms/hall.tscn", "from_entrance")
	await get_tree().process_frame
	var attic := level.room.get_node("ExitToAttic") as RoomExit
	var cellar := level.room.get_node("ExitToCellar") as RoomExit
	await get_tree().physics_frame
	_check((attic.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(190, 120), "attic trigger matches its opening")
	_check((cellar.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(120, 120), "cellar trigger matches its opening")

	var player := level.get_node("Player") as CharacterBody2D
	player.global_position = Vector2(250, 276)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(attic.overlaps_body(player) and cellar.overlaps_body(player), "player capsule overlaps both adjacent areas")
	attic._on_body_entered(player)
	cellar._on_body_entered(player)
	_check(attic.hint.visible != cellar.hint.visible, "only the nearest adjacent exit shows its prompt")
	attic.destination_scene_path = ""
	cellar.destination_scene_path = ""
	var activated := [0]
	attic.exit_entered.connect(func(_exit: RoomExit): activated[0] += 1)
	cellar.exit_entered.connect(func(_exit: RoomExit): activated[0] += 1)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	attic._unhandled_input(event)
	cellar._unhandled_input(event)
	_check(activated[0] == 1, "nearest adjacent exit alone accepts interaction")

	var exit_scene := load("res://scenes/objects/room_exit.tscn") as PackedScene
	var first_tie := exit_scene.instantiate() as RoomExit
	var second_tie := exit_scene.instantiate() as RoomExit
	first_tie.position = Vector2(250, 211)
	second_tie.position = Vector2(250, 211)
	level.room.add_child(first_tie)
	level.room.add_child(second_tie)
	await get_tree().physics_frame
	first_tie.nearby = true
	second_tie.nearby = true
	var lower_id_wins := first_tie.get_instance_id() < second_tie.get_instance_id()
	_check(first_tie._is_nearest_exit() == lower_id_wins, "same-position arbitration favors the lower instance id")
	_check(second_tie._is_nearest_exit() != lower_id_wins, "same-position arbitration is deterministic")

	level.queue_free()
	await get_tree().process_frame
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().create_timer(0.15).timeout
	print("Adjacent exit verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
