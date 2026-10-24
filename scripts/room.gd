extends Node2D
class_name Room

signal exit_entered(exit: RoomExit)

@export var room_title := "ROOM"
@export var room_color := Color("#e8dfc6")
@export var background_texture: Texture2D
@export var staircase_position := Vector2.ZERO

const SIZE := Vector2(1152, 648)
const EDGE := 28.0
const WALL_THICKNESS := 20.0


func _ready() -> void:
	for exit in find_children("*", "RoomExit", true, false):
		exit.exit_entered.connect(_on_exit_entered)
	_build_collisions()
	queue_redraw()


func get_arrival_position(arrival_id: String, fallback: Vector2) -> Vector2:
	var marker := get_node_or_null("Arrivals/" + arrival_id) as Node2D
	return marker.global_position if marker != null else fallback


func _on_exit_entered(exit: RoomExit) -> void:
	if not exit.destination_scene_path.is_empty():
		exit_entered.emit(exit)


func _draw() -> void:
	if background_texture:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, SIZE), room_color)
		draw_rect(Rect2(Vector2(EDGE, EDGE), SIZE - Vector2(EDGE * 2.0, EDGE * 2.0)), room_color.lightened(0.08))
		draw_string(ThemeDB.fallback_font, Vector2(52, 78), room_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#665f4d"))
		_draw_furniture()
	_draw_walls()


func _draw_walls() -> void:
	var color := Color("#857b62")
	_draw_wall_side("north", Vector2(EDGE, EDGE), Vector2(SIZE.x - EDGE, EDGE), true, color)
	_draw_wall_side("south", Vector2(EDGE, SIZE.y - EDGE), Vector2(SIZE.x - EDGE, SIZE.y - EDGE), true, color)
	_draw_wall_side("west", Vector2(EDGE, EDGE), Vector2(EDGE, SIZE.y - EDGE), false, color)
	_draw_wall_side("east", Vector2(SIZE.x - EDGE, EDGE), Vector2(SIZE.x - EDGE, SIZE.y - EDGE), false, color)
	if staircase_position != Vector2.ZERO:
		_draw_staircase(staircase_position)


func _draw_wall_side(side: String, start: Vector2, finish: Vector2, horizontal: bool, color: Color) -> void:
	var openings: Array[Vector2] = []
	for node in find_children("*", "RoomExit", true, false):
		var exit := node as RoomExit
		if exit.wall_side == side:
			var offset := exit.position.x if horizontal else exit.position.y
			openings.append(Vector2(offset - exit.opening_half_width, offset + exit.opening_half_width))
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := EDGE
	for opening in openings:
		_draw_wall_segment(start, finish, horizontal, cursor, opening.x, color)
		cursor = opening.y
	_draw_wall_segment(start, finish, horizontal, cursor, (SIZE.x if horizontal else SIZE.y) - EDGE, color)


func _draw_wall_segment(start: Vector2, finish: Vector2, horizontal: bool, from: float, to: float, color: Color) -> void:
	if to <= from:
		return
	var first := Vector2(from, start.y) if horizontal else Vector2(start.x, from)
	var last := Vector2(to, finish.y) if horizontal else Vector2(finish.x, to)
	draw_line(first, last, color, 12.0, true)


func _draw_staircase(center: Vector2) -> void:
	var rect := Rect2(center - Vector2(35, 72), Vector2(70, 144))
	draw_rect(rect, Color("#c7b99a"), true)
	for step in range(1, 6):
		var y := rect.position.y + rect.size.y * float(step) / 6.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("#766b57"), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-72, 102), "STAIRS", HORIZONTAL_ALIGNMENT_CENTER, 144, 15, Color("#665f4d"))


func _build_collisions() -> void:
	var walls := StaticBody2D.new()
	walls.name = "RoomWalls"
	add_child(walls)
	_add_wall_segments(walls, "north", Vector2(EDGE, EDGE), Vector2(SIZE.x - EDGE, EDGE))
	_add_wall_segments(walls, "south", Vector2(EDGE, SIZE.y - EDGE), Vector2(SIZE.x - EDGE, SIZE.y - EDGE))
	_add_wall_segments(walls, "west", Vector2(EDGE, EDGE), Vector2(EDGE, SIZE.y - EDGE))
	_add_wall_segments(walls, "east", Vector2(SIZE.x - EDGE, EDGE), Vector2(SIZE.x - EDGE, SIZE.y - EDGE))
	if background_texture == null:
		_add_obstacle(walls, RectangleShape2D.new(), Vector2(290, 238), Vector2(230, 96))
		_add_obstacle(walls, RectangleShape2D.new(), Vector2(862, 451), Vector2(225, 82))
		_add_obstacle(walls, CircleShape2D.new(), Vector2(575, 300), Vector2(34, 34))


func _add_obstacle(parent: StaticBody2D, shape: Shape2D, center: Vector2, size: Vector2) -> void:
	if shape is RectangleShape2D:
		(shape as RectangleShape2D).size = size
	elif shape is CircleShape2D:
		(shape as CircleShape2D).radius = size.x
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = center
	parent.add_child(collision)


func _add_wall_segments(walls: StaticBody2D, side: String, start: Vector2, finish: Vector2) -> void:
	var horizontal := side in ["north", "south"]
	var openings: Array[Vector2] = []
	for node in find_children("*", "RoomExit", true, false):
		var exit := node as RoomExit
		if exit.wall_side != side:
			continue
		var offset := exit.position.x if horizontal else exit.position.y
		openings.append(Vector2(offset - exit.opening_half_width, offset + exit.opening_half_width))
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := EDGE
	var span := SIZE.x if horizontal else SIZE.y
	for opening in openings:
		_add_wall_segment(walls, side, start, horizontal, cursor, opening.x)
		cursor = opening.y
	_add_wall_segment(walls, side, start, horizontal, cursor, span - EDGE)


func _add_wall_segment(walls: StaticBody2D, side: String, start: Vector2, horizontal: bool, from: float, to: float) -> void:
	if to <= from:
		return
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(to - from, WALL_THICKNESS) if horizontal else Vector2(WALL_THICKNESS, to - from)
	shape.shape = rectangle
	shape.position = Vector2((from + to) * 0.5, start.y) if horizontal else Vector2(start.x, (from + to) * 0.5)
	walls.add_child(shape)


func _draw_furniture() -> void:
	var furniture_color := room_color.darkened(0.12)
	draw_rect(Rect2(Vector2(175, 190), Vector2(230, 96)), furniture_color, false, 5.0)
	draw_rect(Rect2(Vector2(750, 410), Vector2(225, 82)), furniture_color, false, 5.0)
	draw_circle(Vector2(575, 300), 34.0, furniture_color)
