extends Area2D
class_name RoomExit

signal exit_entered(exit: RoomExit)

@export_file("*.tscn") var destination_scene_path := ""
@export var destination_arrival_id := "start"
@export_enum("north", "south", "west", "east") var wall_side := "north"
@export_range(24.0, 220.0, 1.0) var opening_half_width := 150.0
@export var required_flag := ""
@export_multiline var locked_message := ""

var nearby := false
var activated := false
var level: Level
var hint: Label


func _ready() -> void:
	level = _get_level()
	var shape := get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = shape.shape.duplicate()
	var rectangle := shape.shape as RectangleShape2D
	var horizontal_exit := wall_side in ["north", "south"]
	var opening_span := opening_half_width * 2.0
	rectangle.size = Vector2(opening_span, 120) if horizontal_exit else Vector2(120, opening_span)
	shape.position = _walkable_side_offset()
	add_to_group("room_exits")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()


func _process(_delta: float) -> void:
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or activated or level == null or not level.player_controls_enabled() or not _is_nearest_exit():
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if not required_flag.is_empty() and not level.has_flag(required_flag):
		if not locked_message.is_empty():
			level.dialog_manager.show_dialog([locked_message])
		return
	activated = true
	hint.hide()
	EventBus.request_audio(&"door")
	exit_entered.emit(self)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		nearby = true
		_update_hint()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		nearby = false
		activated = false
		_update_hint()


func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and level != null and body == level.get_node_or_null("Player")


func _is_nearest_exit() -> bool:
	if not is_instance_valid(level) or is_queued_for_deletion():
		return false
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		return false
	var room := _get_room()
	if room != null and (room.is_queued_for_deletion() or room != level.room):
		return false
	var distance := global_position.distance_squared_to(player.global_position)
	for node in get_tree().get_nodes_in_group("room_exits"):
		var candidate := node as RoomExit
		if candidate == null or candidate == self or not is_instance_valid(candidate):
			continue
		if candidate.is_queued_for_deletion() or candidate.level != level:
			continue
		var candidate_room := candidate._get_room()
		if candidate_room != room or (candidate_room != null and (candidate_room.is_queued_for_deletion() or candidate_room != level.room)):
			continue
		if not candidate.nearby:
			continue
		var candidate_distance: float = candidate.global_position.distance_squared_to(player.global_position)
		if candidate_distance < distance or (is_equal_approx(candidate_distance, distance) and candidate.get_instance_id() < get_instance_id()):
			return false
	return true


func _get_room() -> Room:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Room:
			return ancestor as Room
		ancestor = ancestor.get_parent()
	return null


func _get_level() -> Level:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Level:
			return ancestor as Level
		ancestor = ancestor.get_parent()
	return get_tree().current_scene as Level


func _walkable_side_offset() -> Vector2:
	match wall_side:
		"north":
			return Vector2(0, 65)
		"south":
			return Vector2(0, -65)
		"west":
			return Vector2(65, 0)
		"east":
			return Vector2(-65, 0)
	return Vector2.ZERO


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hint = Label.new()
	hint.anchor_left = 0.15
	hint.anchor_top = 1.0
	hint.anchor_right = 0.85
	hint.anchor_bottom = 1.0
	hint.offset_top = -58
	hint.offset_bottom = -24
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.text = "%s  Projít dveřmi" % InputPrompts.action_label(&"interact")
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	layer.add_child(hint)


func _update_hint() -> void:
	hint.visible = nearby and not activated and level != null and level.player_controls_enabled() and _is_nearest_exit()
