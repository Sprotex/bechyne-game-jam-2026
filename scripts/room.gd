extends Node2D

@export var room_title := "ROOM"
@export var room_color := Color("#e8dfc6")
@export var background_texture: Texture2D
@export var up_room := ""
@export var down_room := ""
@export var left_room := ""
@export var right_room := ""
@export var staircase_wall := ""
@export var staircase_offset := 0.0
@export var staircase_position := Vector2.ZERO

const SIZE := Vector2(1152, 648)
const EDGE := 28.0
const DOOR_HALF_WIDTH := 92.0


func _ready() -> void:
	queue_redraw()


func get_room_for_direction(direction: String) -> String:
	match direction:
		"up": return up_room
		"down": return down_room
		"left": return left_room
		"right": return right_room
	return ""


func _draw() -> void:
	if background_texture:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, SIZE), room_color)
		draw_rect(Rect2(Vector2(EDGE, EDGE), SIZE - Vector2(EDGE * 2.0, EDGE * 2.0)), room_color.lightened(0.08))
	_draw_wall("up")
	_draw_wall("down")
	_draw_wall("left")
	_draw_wall("right")
	if not background_texture:
		draw_string(ThemeDB.fallback_font, Vector2(52, 78), room_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#665f4d"))
		_draw_furniture()
	if staircase_position != Vector2.ZERO:
		_draw_staircase(staircase_position)


func _draw_wall(direction: String) -> void:
	var center := SIZE.x * 0.5 if direction in ["up", "down"] else SIZE.y * 0.5
	var openings: Array[Vector2] = []
	if not get_room_for_direction(direction).is_empty():
		openings.append(Vector2(center - DOOR_HALF_WIDTH, center + DOOR_HALF_WIDTH))
	if direction == staircase_wall:
		openings.append(Vector2(staircase_offset - DOOR_HALF_WIDTH, staircase_offset + DOOR_HALF_WIDTH))
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := EDGE
	for opening in openings:
		_draw_wall_segment(direction, cursor, opening.x)
		cursor = opening.y
	_draw_wall_segment(direction, cursor, (SIZE.x if direction in ["up", "down"] else SIZE.y) - EDGE)


func _draw_wall_segment(direction: String, start: float, finish: float) -> void:
	if finish <= start:
		return
	var color := Color("#857b62")
	var from: Vector2
	var to: Vector2
	match direction:
		"up":
			from = Vector2(start, EDGE)
			to = Vector2(finish, EDGE)
		"down":
			from = Vector2(start, SIZE.y - EDGE)
			to = Vector2(finish, SIZE.y - EDGE)
		"left":
			from = Vector2(EDGE, start)
			to = Vector2(EDGE, finish)
		"right":
			from = Vector2(SIZE.x - EDGE, start)
			to = Vector2(SIZE.x - EDGE, finish)
	_draw_line(from, to, color, 12.0)


func _draw_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)


func _draw_furniture() -> void:
	var furniture_color := room_color.darkened(0.12)
	draw_rect(Rect2(Vector2(175, 190), Vector2(230, 96)), furniture_color, false, 5.0)
	draw_rect(Rect2(Vector2(750, 410), Vector2(225, 82)), furniture_color, false, 5.0)
	draw_circle(Vector2(575, 300), 34.0, furniture_color)


func _draw_staircase(center: Vector2) -> void:
	var rect := Rect2(center - Vector2(35, 72), Vector2(70, 144))
	draw_rect(rect, Color("#c7b99a"), true)
	for step in range(1, 6):
		var y := rect.position.y + rect.size.y * float(step) / 6.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("#766b57"), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-72, 102), "STAIRS", HORIZONTAL_ALIGNMENT_CENTER, 144, 15, Color("#665f4d"))
