extends Node2D
class_name Room

signal exit_entered(exit: RoomExit)
signal lights_state_changed(is_on: bool)

@export var room_title := "MĚSTNOST"
@export var room_color := Color("#e8dfc6")
@export var walkable_outline := PackedVector2Array()

const WALL_THICKNESS := 18.0
const EXIT_EDGE_TOLERANCE := 100.0

var lights_are_on := false


func toggle_lights() -> void:
	set_lights_enabled(not lights_are_on)


func set_lights_enabled(is_on: bool) -> void:
	if lights_are_on == is_on:
		return
	lights_are_on = is_on
	lights_state_changed.emit(lights_are_on)


func _ready() -> void:
	for exit in find_children("*", "RoomExit", true, false):
		exit.exit_entered.connect(_on_exit_entered)
	_build_walkable_boundary()


func get_arrival_position(arrival_id: String, fallback: Vector2) -> Vector2:
	var marker := get_node_or_null("Arrivals/" + arrival_id) as Node2D
	return marker.global_position if marker != null else fallback


func get_background_bounds() -> Rect2:
	var background := get_node_or_null("Background") as Sprite2D
	if background == null or background.texture == null:
		return Rect2()
	var sprite_rect := background.get_rect()
	var corners := [
		background.to_global(sprite_rect.position),
		background.to_global(sprite_rect.position + Vector2(sprite_rect.size.x, 0.0)),
		background.to_global(sprite_rect.position + sprite_rect.size),
		background.to_global(sprite_rect.position + Vector2(0.0, sprite_rect.size.y)),
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds


func _on_exit_entered(exit: RoomExit) -> void:
	if not exit.destination_scene_path.is_empty():
		exit_entered.emit(exit)


func _build_walkable_boundary() -> void:
	if walkable_outline.size() < 3:
		return
	var walls := StaticBody2D.new()
	walls.name = "RoomWalls"
	add_child(walls)
	var clockwise := _outline_signed_area() > 0.0
	for index in range(walkable_outline.size()):
		var first := walkable_outline[index]
		var last := walkable_outline[(index + 1) % walkable_outline.size()]
		_add_outline_edge(walls, first, last, clockwise)


func _outline_signed_area() -> float:
	var area := 0.0
	for index in range(walkable_outline.size()):
		var first := walkable_outline[index]
		var last := walkable_outline[(index + 1) % walkable_outline.size()]
		area += first.x * last.y - last.x * first.y
	return area * 0.5


func _add_outline_edge(walls: StaticBody2D, first: Vector2, last: Vector2, clockwise: bool) -> void:
	var edge := last - first
	var edge_length := edge.length()
	if edge_length <= 1.0:
		return
	var direction := edge / edge_length
	var openings: Array[Vector2] = []
	for node in find_children("*", "RoomExit", true, false):
		var exit := node as RoomExit
		var along := clampf((exit.position - first).dot(direction), 0.0, edge_length)
		var nearest := first + direction * along
		if nearest.distance_to(exit.position) > EXIT_EDGE_TOLERANCE:
			continue
		openings.append(Vector2(
			maxf(0.0, along - exit.opening_half_width),
			minf(edge_length, along + exit.opening_half_width)
		))
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := 0.0
	for opening in openings:
		_add_wall_segment(walls, first, direction, cursor, opening.x, clockwise)
		cursor = maxf(cursor, opening.y)
	_add_wall_segment(walls, first, direction, cursor, edge_length, clockwise)


func _add_wall_segment(
	parent: StaticBody2D,
	first: Vector2,
	direction: Vector2,
	from: float,
	to: float,
	clockwise: bool
) -> void:
	if to - from <= 1.0:
		return
	var outward := Vector2(direction.y, -direction.x) if clockwise else Vector2(-direction.y, direction.x)
	var center := first + direction * ((from + to) * 0.5) + outward * (WALL_THICKNESS * 0.5)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(to - from + WALL_THICKNESS, WALL_THICKNESS)
	collision.shape = rectangle
	collision.position = center
	collision.rotation = direction.angle()
	parent.add_child(collision)
