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
	player.global_position = Vector2(350, 280)
	await runner.get_tree().physics_frame
	runner.call("_check", player.test_move(player.global_transform, Vector2(0, -120)), "hall attic perimeter blocks outward movement while locked")
	attic_exit.set("nearby", true)
	attic_exit.call("_unhandled_input", _interact_event())
	runner.call("_check", level.room == hall and not level.has_flag("story.attic_unlocked"), "attic exit interaction remains locked before its prerequisites")
	level.dialog_manager.hide_dialog()
	level._refresh_controls()
	level.set_flag("story.day_two")
	level.set_flag("story.diagnosis_read")
	runner.call("_check", not level.has_flag("story.attic_unlocked"), "attic stays locked before keypad completion")
	level.set_flag("puzzle.bedroom_keypad_unlocked")
	runner.call("_check", level.has_flag("story.attic_unlocked"), "story requirements unlock attic interaction")
	await runner.get_tree().physics_frame
	runner.call("_check", player.test_move(player.global_transform, Vector2(0, -120)), "hall attic perimeter stays blocked after unlocking")
	attic_exit.call("_unhandled_input", _interact_event())
	await runner.get_tree().create_timer(0.32).timeout
	runner.call("_check", level.room.scene_file_path.ends_with("/attic.tscn"), "unlocked attic exit transitions on interaction")
	var attic := level.room
	var entry := attic.get_node("EntryInteractor")
	runner.call("_check", attic.get_arrival_position("from_hall", Vector2.ZERO) == attic.get_node("Arrivals/from_hall").global_position, "attic has a from_hall arrival")
	entry.set("nearby", true)
	entry.call("_unhandled_input", _interact_event())
	runner.call("_check", level.has_flag("story.attic_entered"), "attic entry records story.attic_entered")
	runner.call("_check", level.dialog_manager.is_dialog_open(), "first attic entry shows its story dialogue")
	level.dialog_manager.hide_dialog()
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
