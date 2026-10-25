extends RefCounted

const LEVEL_SCENE := "res://scenes/level.tscn"
const HALL_SCENE := "res://scenes/rooms/hall.tscn"


static func run(runner: Node) -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	runner.get_tree().root.add_child(level)
	runner.get_tree().current_scene = level
	await runner.get_tree().process_frame
	level.dialog_manager.hide_dialog()
	var main_background := level.room.get_node("Background") as Sprite2D
	runner.call("_check", Vector2i(main_background.texture.get_size()) == Vector2i(2000, 563), "main entrance uses native 2000x563 artwork")
	level._load_room(HALL_SCENE, "from_entrance")
	var hall := level.room
	var player := level.get_node("Player") as CharacterBody2D
	var attic_exit := hall.get_node("ExitToAttic") as RoomExit
	runner.call("_check", not level.has_flag("story.day_two") and not level.has_flag("story.diagnosis_read") and not level.has_flag("story.attic_unlocked"), "attic route begins with empty story flags")
	runner.call("_check", attic_exit.required_flag.is_empty() and attic_exit.locked_message.is_empty(), "hall attic stairs have no story gate or locked dialogue")
	player.global_position = Vector2(350, 280)
	await runner.get_tree().physics_frame
	runner.call("_check", player.test_move(player.global_transform, Vector2(0, -120)), "hall attic perimeter blocks outward movement")
	attic_exit.set("nearby", true)
	runner.call("_check", level.room == hall, "attic exit requires interaction before transition")
	attic_exit.call("_unhandled_input", _interact_event())
	runner.call("_check", level.room == hall and not level.dialog_manager.is_dialog_open(), "attic stair interaction opens no locked dialogue")
	await runner.get_tree().physics_frame
	runner.call("_check", player.test_move(player.global_transform, Vector2(0, -120)), "hall attic perimeter stays solid beside the stair exit")
	await runner.get_tree().create_timer(0.32).timeout
	runner.call("_check", level.room.scene_file_path.ends_with("/attic.tscn"), "attic exit transitions on interaction with empty story flags")
	var attic := level.room
	var entry := attic.get_node_or_null("EntryInteractor")
	var identity := attic.get_node_or_null("IdentityCard")
	runner.call("_check", attic.get_arrival_position("from_hall", Vector2.ZERO) == attic.get_node("Arrivals/from_hall").global_position, "attic has a from_hall arrival")
	runner.call("_check", entry != null, "attic entry interactor is present")
	runner.call("_check", identity == null, "identity document has no standalone collection interaction")
	runner.call("_check", attic.get_node_or_null("CombinationLock") != null, "attic combination lock guards the identity document")
	if entry != null:
		entry.call("_on_body_entered", player)
		entry.call("_unhandled_input", _interact_event())
		runner.call("_check", level.has_flag("story.attic_entered"), "attic entry records story.attic_entered")
		runner.call("_check", level.dialog_manager.is_dialog_open(), "first attic entry shows its story dialogue")
		level.dialog_manager.hide_dialog()
		level._refresh_controls()
		entry.call("_unhandled_input", _interact_event())
		runner.call("_check", not level.dialog_manager.is_dialog_open(), "attic entry dialogue is one-shot")
	level.queue_free()
	await runner.get_tree().process_frame
	runner.get_tree().current_scene = runner
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	await runner.get_tree().process_frame
	await runner.get_tree().create_timer(0.15).timeout


static func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event
