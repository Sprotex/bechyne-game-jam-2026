extends RefCounted

const LEVEL_SCENE := "res://scenes/level.tscn"
const HALL_SCENE := "res://scenes/rooms/hall.tscn"
const ATTIC_SCENE := "res://scenes/rooms/attic.tscn"


static func run(runner: Node) -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	runner.get_tree().root.add_child(level)
	runner.get_tree().current_scene = level
	await runner.get_tree().process_frame
	level.dialog_manager.hide_dialog()
	var main_background := level.room.get_node("Background") as Sprite2D
	runner.call("_check", Vector2i(main_background.texture.get_size()) == Vector2i(2000, 563), "main entrance uses native 2000x563 artwork")
	level._load_room(HALL_SCENE, "from_entrance")
	var gate_room := level.room
	var gates: Array = gate_room.get("exit_gates")
	runner.call("_check", gates.size() == 1, "hall attic opening has a physical gate")
	if gates.size() == 1:
		var gate := gates[0] as Dictionary
		var shape := gate["shape"] as CollisionShape2D
		runner.call("_check", not shape.disabled, "attic boundary blocks entry while locked")
		level.set_flag("story.day_two")
		level.set_flag("story.diagnosis_read")
		runner.call("_check", not shape.disabled, "attic boundary stays blocked before keypad completion")
		level.set_flag("puzzle.bedroom_keypad_unlocked")
		runner.call("_check", shape.disabled, "attic boundary opens when story requirements are met")
	level._load_room(ATTIC_SCENE, "from_hall")
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


static func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event
