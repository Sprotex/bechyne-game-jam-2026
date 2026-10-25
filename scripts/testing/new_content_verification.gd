extends Node

const ATTIC := "res://scenes/rooms/attic.tscn"
const IDENTITY := "res://scenes/objects/identity_card.tscn"
const DIAGNOSIS := "res://scenes/objects/diagnosis.tscn"
const ENTITY := "res://scenes/objects/night_entity.tscn"
const RuntimeChecks := preload("res://scripts/testing/new_content_runtime_checks.gd")
const ART := {
	"attic": ["res://assets/gfx/attic.png", Vector2i(2000, 377)],
	"diagnosis": ["res://assets/gfx/diagnosis.png", Vector2i(297, 420)],
	"identity card": ["res://assets/gfx/identity_card.png", Vector2i(420, 297)],
	"night entity": ["res://assets/gfx/night_entity.png", Vector2i(420, 297)],
}

var failures := 0
var pending: Array[String] = []


func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	_check_art()
	_check_story_progression()
	await _check_document_ui()
	_check_evidence_scenes()
	_check_attic_scene()
	await _check_entity()
	await _check_evidence_runtime()
	_check_topology()
	await RuntimeChecks.run(self)
	for note in pending:
		print("PENDING: " + note)
	print("New content verification: %d failures, %d pending" % [failures, pending.size()])
	get_tree().quit(1 if failures > 0 else 0)
func _check_art() -> void:
	for label in ART:
		var spec: Array = ART[label]
		var texture := load(spec[0]) as Texture2D
		if texture == null:
			_fail("%s art loads" % label)
		else:
			_check(Vector2i(texture.get_size()) == spec[1], "%s art native size is %s" % [label, spec[1]])
func _check_story_progression() -> void:
	var level_script := load("res://scripts/core/level.gd") as Script
	var progression := load("res://scripts/core/story_progression.gd") as Script
	if level_script == null or progression == null:
		_pending("Level or StoryProgression is not available")
		return
	var level: Object = level_script.new()
	var signal_info: Array = level.get_signal_list().filter(func(info: Dictionary): return info.name == "flag_changed")
	_check(not signal_info.is_empty(), "Level exposes flag_changed")
	if not signal_info.is_empty():
		_check(signal_info[0].args.size() == 2, "flag_changed carries flag id and boolean value")
	_check(not progression.call("can_enter_attic", level), "attic starts locked")
	level.call("set_flag", "story.day_two")
	level.call("set_flag", "story.diagnosis_read")
	_check(not progression.call("can_enter_attic", level), "attic stays locked until keypad completion")
	level.call("set_flag", "puzzle.bedroom_keypad_unlocked")
	_check(progression.call("can_enter_attic", level), "attic unlock requires day two, diagnosis, and keypad")
	level.free()
func _check_document_ui() -> void:
	var script := load("res://scripts/ui/dialog_manager.gd") as Script
	if script == null:
		_pending("dialog manager is unavailable")
		return
	var manager := script.new() as Node
	if not manager.has_signal("document_closed") or not manager.has_method("show_document"):
		_pending("document UI API is incomplete")
		manager.free()
		return
	add_child(manager)
	await get_tree().process_frame
	var closed := [0]
	manager.connect("document_closed", func(): closed[0] += 1)
	var art := load("res://assets/gfx/identity_card.png") as Texture2D
	var lines: Array[String] = ["DokumentovĂ˝ text."]
	manager.show_document(art, lines)
	_check(manager.is_modal_open() and manager.image_preview.texture == art, "document opens its full image as a modal")
	_check(closed[0] == 0, "document remains open before image dismissal")
	_send_interact(manager)
	await get_tree().process_frame
	_check(manager.is_dialog_open() and closed[0] == 0, "document dialogue follows image without early close signal")
	manager._finish_reveal()
	manager.advance_dialog()
	await get_tree().process_frame
	_check(closed[0] == 1, "document_closed fires after final dialogue line")
	var ordinary: Array[String] = ["BÄ›ĹľnĂ˝ dialog."]
	manager.show_dialog(ordinary)
	manager._finish_reveal()
	manager.advance_dialog()
	await get_tree().process_frame
	_check(closed[0] == 1, "ordinary dialogue does not emit document_closed")
	var empty_lines: Array[String] = []
	manager.show_document(art, empty_lines)
	_send_interact(manager)
	await get_tree().process_frame
	_check(closed[0] == 2 and not manager.is_modal_open(), "empty document closes after image dismissal")
	manager.show_document(art, lines)
	manager.show_document(art, lines)
	_send_interact(manager)
	await get_tree().process_frame
	_check(closed[0] == 2 and manager.is_dialog_open(), "reentrant document opens one dialogue")
	manager._finish_reveal()
	manager.advance_dialog()
	await get_tree().process_frame
	_check(closed[0] == 3, "reentrant document emits one close signal")
	manager.queue_free()
	await get_tree().process_frame
func _check_evidence_scenes() -> void:
	for pair in [["diagnosis", DIAGNOSIS], ["identity card", IDENTITY]]:
		var label: String = pair[0]
		var packed := load(pair[1]) as PackedScene
		if packed == null:
			_fail("%s scene loads" % label)
			continue
		var item := packed.instantiate()
		_check(item.get_script().resource_path.ends_with("evidence_document.gd"), "%s uses evidence_document.gd" % label)
		_check(item.get("document_texture") != null, "%s has assigned document artwork" % label)
		var required: PackedStringArray = item.get("required_flags")
		var primary := "story.day_two" if label == "diagnosis" else "story.diagnosis_read"
		_check(primary in required, "%s requires %s" % [label, primary])
		if label == "identity card":
			_check("story.day_two" in required, "identity card requires day two too")
			_check(item.get("completes_game"), "identity card is configured as the ending")
		item.free()
func _check_attic_scene() -> void:
	if not ResourceLoader.exists(ATTIC):
		_pending("attic scene is not available")
		return
	var room := (load(ATTIC) as PackedScene).instantiate()
	var background := room.get_node_or_null("Background") as Sprite2D
	_check(background != null and background.texture != null, "attic has a background")
	if background != null and background.texture != null:
		_check(Vector2i(background.texture.get_size()) == Vector2i(2000, 377), "attic background remains native 2000x377")
	_check(room.get_node_or_null("IdentityCard") != null, "identity card is placed in attic")
	_pending("diagnosis and entity room placements await user location decision")
	_check(room.get_node_or_null("EntryInteractor") != null, "attic entry trigger is present")
	var exit := room.get_node_or_null("ExitToHall") as RoomExit
	_check(exit != null and exit.destination_scene_path.ends_with("hall.tscn"), "attic has return route to hall")
	if exit != null:
		_check(exit.destination_arrival_id == "from_attic", "attic return uses hall.from_attic")
	room.free()
func _check_entity() -> void:
	if not ResourceLoader.exists(ENTITY):
		_pending("night entity scene is unavailable")
		return
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	var entity := (load(ENTITY) as PackedScene).instantiate()
	if entity.get_script() == null:
		_fail("night entity script compiles")
		_pending("entity behavior checks await a valid night entity script")
		entity.free()
		level.queue_free()
		await get_tree().process_frame
		get_tree().current_scene = self
		if is_instance_valid(AudioManager.music_player):
			AudioManager.music_player.queue_free()
			AudioManager.music_player = null
		AudioManager.music = null
		return
	level.room.add_child(entity)
	await get_tree().process_frame
	var sprite := entity.get_node("Sprite2D") as Sprite2D
	_check(not sprite.visible, "entity is hidden on day one")
	level.set_flag("story.day_two")
	_check(sprite.visible, "entity appears in darkness on day two")
	level.room.set_lights_enabled(true)
	_check(not sprite.visible, "entity hides when lights turn on")
	level.room.set_lights_enabled(false)
	_check(sprite.visible, "entity reappears in darkness on revisit")
	level.transition_locked = true
	entity._on_body_entered(level.get_node("Player"))
	_check(level.has_flag("story.entity_seen"), "proximity scare records its one-shot flag")
	_check(entity.pending_dialogues.size() == 1, "scare dialogue defers while controls are locked")
	_check(not level.dialog_manager.is_modal_open(), "deferred scare does not interrupt current modal state")
	entity._on_body_entered(level.get_node("Player"))
	_check(entity.pending_dialogues.size() == 1, "proximity scare cannot queue twice")
	level.transition_locked = false
	level._refresh_controls()
	await get_tree().process_frame
	_check(level.dialog_manager.is_dialog_open(), "deferred scare dialogue appears when controls return")
	entity.queue_free()
	level.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = self
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
func _check_evidence_runtime() -> void:
	var level := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Level
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.dialog_manager.hide_dialog()
	var completion_handler := Callable(EventBus, "_show_final_credits")
	if EventBus.game_completed.is_connected(completion_handler):
		EventBus.game_completed.disconnect(completion_handler)
	EventBus.reset_game_completion()
	var completions := [0]
	var completed_callback := func(): completions[0] += 1
	EventBus.game_completed.connect(completed_callback)
	var diagnosis := (load(DIAGNOSIS) as PackedScene).instantiate()
	level.room.add_child(diagnosis)
	await get_tree().process_frame
	diagnosis._on_body_entered(level.get_node("Player"))
	diagnosis._unhandled_input(_interact_event())
	_check(not diagnosis.reading, "diagnosis cannot open before day two")
	level.set_flag("story.day_two")
	await get_tree().process_frame
	diagnosis._unhandled_input(_interact_event())
	_check(diagnosis.reading and not level.has_flag("story.diagnosis_read"), "reading diagnosis does not complete before document closes")
	_send_interact(level.dialog_manager)
	await get_tree().process_frame
	_check(level.dialog_manager.is_dialog_open() and not level.has_flag("story.diagnosis_read"), "diagnosis flag waits through its dialogue")
	level.dialog_manager._finish_reveal()
	level.dialog_manager.advance_dialog()
	await get_tree().process_frame
	_check(level.has_flag("story.diagnosis_read"), "diagnosis flag is set after document dialogue")
	_check(completions[0] == 0, "diagnosis document does not complete the game")
	var identity := (load(IDENTITY) as PackedScene).instantiate()
	level.room.add_child(identity)
	await get_tree().process_frame
	identity._on_body_entered(level.get_node("Player"))
	identity._unhandled_input(_interact_event())
	_check(identity.reading and completions[0] == 0, "identity document does not complete before its dialogue")
	_send_interact(level.dialog_manager)
	await get_tree().process_frame
	_check(level.dialog_manager.is_dialog_open() and completions[0] == 0, "identity ending waits through its dialogue")
	level.dialog_manager._finish_reveal()
	level.dialog_manager.advance_dialog()
	await get_tree().process_frame
	_check(completions[0] == 1, "identity document completes only after its final dialogue")
	_check(level.has_flag("story.identity_read"), "identity completion flag follows document close")
	EventBus.game_completed.disconnect(completed_callback)
	if not EventBus.game_completed.is_connected(completion_handler):
		EventBus.game_completed.connect(completion_handler, CONNECT_DEFERRED)
	EventBus.reset_game_completion()
	level.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = self
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
func _check_topology() -> void:
	_check_route("main_entrance", "living_room", "from_entrance", "north")
	_check_route("main_entrance", "bathroom", "from_entrance", "south")
	_check_route("main_entrance", "hall", "from_entrance", "west")
	_check_route("hall", "bedroom", "from_hall", "south")
	_check_route("hall", "main_entrance", "from_hall", "east")
	_check_route("hall", "attic", "from_hall", "north", "story.attic_unlocked")
func _check_route(source: String, destination: String, arrival: String, side: String, required := "") -> void:
	var path := "res://scenes/rooms/%s.tscn" % source
	if not ResourceLoader.exists(path):
		_pending("room topology for %s is not landed" % source)
		return
	var room := (load(path) as PackedScene).instantiate()
	var found: RoomExit
	for node in room.find_children("*", "RoomExit", true, false):
		var exit := node as RoomExit
		if exit.destination_scene_path.ends_with("/%s.tscn" % destination):
			found = exit
			break
	if found == null:
		_pending("%s to %s route awaits the topology update" % [source, destination])
	else:
		_check(found.destination_arrival_id == arrival and found.wall_side == side, "%s to %s uses %s arrival on %s wall" % [source, destination, arrival, side])
		if required != "":
			_check(found.required_flag == required, "hall attic exit requires story.attic_unlocked")
	room.free()
func _send_interact(manager: Node) -> void:
	manager.call("_input", _interact_event())
func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event
func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_fail(description)
func _fail(description: String) -> void:
	failures += 1
	push_error("FAIL: " + description)


func _pending(description: String) -> void:
	pending.append(description)
