extends Node2D

@export var main_entrance_scene: PackedScene
@export var west_room_scene: PackedScene
@export var office_scene: PackedScene
@export var hall_scene: PackedScene
@export var living_room_scene: PackedScene

var room_scenes: Dictionary
const ROOM_LABELS := {
	"entrance": "MAIN ENTRANCE",
	"west_room": "BATHROOM",
	"office": "BEDROOM",
	"hall": "CORRIDOR",
	"living_room": "LIVING ROOM",
}
const VIEW_SIZE := Vector2(1152, 648)
const PLAYER_MARGIN := 28.0
const DOOR_HALF_WIDTH := 92.0
const START_POSITION := Vector2(1080, 324)

var current_room := "entrance"
var transition_locked := false
var room_instance: Node2D


func _ready() -> void:
	room_scenes = {
		"entrance": main_entrance_scene,
		"west_room": west_room_scene,
		"office": office_scene,
		"hall": hall_scene,
		"living_room": living_room_scene,
	}
	_load_room(current_room)
	$Player/Movement.global_position = START_POSITION
	_update_room_label()


func _physics_process(_delta: float) -> void:
	if transition_locked:
		return
	var player: CharacterBody2D = $Player/Movement
	var point := player.global_position
	var exit_direction := ""
	if point.x <= PLAYER_MARGIN and absf(point.y - VIEW_SIZE.y * 0.5) < DOOR_HALF_WIDTH:
		exit_direction = "left"
	elif point.x >= VIEW_SIZE.x - PLAYER_MARGIN and absf(point.y - VIEW_SIZE.y * 0.5) < DOOR_HALF_WIDTH:
		exit_direction = "right"
	elif point.y <= PLAYER_MARGIN and absf(point.x - VIEW_SIZE.x * 0.5) < DOOR_HALF_WIDTH:
		exit_direction = "up"
	elif point.y >= VIEW_SIZE.y - PLAYER_MARGIN and absf(point.x - VIEW_SIZE.x * 0.5) < DOOR_HALF_WIDTH:
		exit_direction = "down"
	if not exit_direction.is_empty():
		var destination: String = room_instance.call("get_room_for_direction", exit_direction)
		if not destination.is_empty():
			_transition_to(destination, exit_direction)
			return
		player.global_position = point.clamp(Vector2(PLAYER_MARGIN, PLAYER_MARGIN), VIEW_SIZE - Vector2(PLAYER_MARGIN, PLAYER_MARGIN))
		return
	player.global_position = point.clamp(Vector2(PLAYER_MARGIN, PLAYER_MARGIN), VIEW_SIZE - Vector2(PLAYER_MARGIN, PLAYER_MARGIN))
	_update_staircase_hint(player.global_position)


func _transition_to(destination: String, exit_direction: String) -> void:
	transition_locked = true
	var arrival := VIEW_SIZE * 0.5
	match exit_direction:
		"left": arrival.x = VIEW_SIZE.x - PLAYER_MARGIN - 4.0
		"right": arrival.x = PLAYER_MARGIN + 4.0
		"up": arrival.y = VIEW_SIZE.y - PLAYER_MARGIN - 4.0
		"down": arrival.y = PLAYER_MARGIN + 4.0
	$Player/Movement.global_position = arrival
	$HUD/Fade.color.a = 1.0
	_load_room(destination)
	current_room = destination
	_update_room_label()
	$HUD/Hint.text = ""
	var tween := create_tween()
	tween.tween_property($HUD/Fade, "color:a", 0.0, 0.22)
	await tween.finished
	transition_locked = false


func _load_room(room_id: String) -> void:
	if is_instance_valid(room_instance):
		room_instance.queue_free()
	room_instance = room_scenes[room_id].instantiate()
	$RoomHolder.add_child(room_instance)


func _update_staircase_hint(player_position: Vector2) -> void:
	var staircase_position: Vector2 = room_instance.get("staircase_position")
	if staircase_position != Vector2.ZERO and player_position.distance_to(staircase_position) < 90.0:
		$HUD/Hint.text = "The staircase leads to another room"
	elif $HUD/Hint.text == "The staircase leads to another room":
		$HUD/Hint.text = ""


func _update_room_label() -> void:
	$HUD/RoomLabel.text = ROOM_LABELS[current_room]
