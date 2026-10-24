extends Area2D
class_name RoomExit

signal exit_entered(exit: RoomExit)

@export_file("*.tscn") var destination_scene_path := ""
@export var destination_arrival_id := "start"
@export_enum("north", "south", "west", "east") var wall_side := "north"
@export_range(24.0, 180.0, 1.0) var opening_half_width := 52.0


func _ready() -> void:
	var shape := get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = shape.shape.duplicate()
	var rectangle := shape.shape as RectangleShape2D
	rectangle.size = Vector2(140, 90) if wall_side in ["north", "south"] else Vector2(90, 140)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		exit_entered.emit(self)
