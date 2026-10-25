extends Interactor
class_name RoomExit

signal exit_entered(exit: RoomExit)

@export_file("*.tscn") var destination_scene_path := ""
@export var destination_arrival_id := "start"
@export_enum("north", "south", "west", "east") var wall_side := "north"
@export_range(24.0, 220.0, 1.0) var opening_half_width := 150.0
@export var required_flag := ""
@export_multiline var locked_message := ""

var activated := false
var level: Level


func _ready() -> void:
	interaction_hint = _get_interaction_hint()
	level = _get_level()
	var shape := get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = shape.shape.duplicate()
	var rectangle := shape.shape as RectangleShape2D
	var horizontal_exit := wall_side in ["north", "south"]
	var opening_span := opening_half_width * 2.0
	rectangle.size = Vector2(opening_span, 120) if horizontal_exit else Vector2(120, opening_span)
	shape.position = _walkable_side_offset()
	add_to_group("room_exits")
	super._ready()


func _get_interaction_hint() -> String:
	var destination_name := destination_scene_path.get_file().get_basename()
	var destinations := {
		"attic": "na půdu",
		"bathroom": "do koupelny",
		"bedroom": "do ložnice",
		"cellar": "do sklepa",
		"hall": "do chodby",
		"living_room": "do obývacího pokoje",
		"main_entrance": "do vstupní haly",
	}
	if destinations.has(destination_name):
		return "Jít %s" % destinations[destination_name]
	return "Jít dál"


func _can_interact() -> bool:
	return super._can_interact() and not activated and _is_nearest_exit()


func _interact() -> void:
	if not required_flag.is_empty() and not level.has_flag(required_flag):
		if not locked_message.is_empty():
			level.dialog_manager.show_dialog([locked_message])
		return
	activated = true
	_refresh_hint()
	EventBus.request_audio(&"door")
	exit_entered.emit(self)


func _is_interaction_body(body: Node2D) -> bool:
	return body is CharacterBody2D and level != null and body == level.get_node_or_null("Player")


func _on_left_range() -> void:
	activated = false


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
