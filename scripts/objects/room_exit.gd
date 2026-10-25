extends Area2D
class_name RoomExit

signal exit_entered(exit: RoomExit)

@export_file("*.tscn") var destination_scene_path := ""
@export var destination_arrival_id := "start"
@export_enum("north", "south", "west", "east") var wall_side := "north"
@export_range(24.0, 220.0, 1.0) var opening_half_width := 150.0
@export var required_flag := ""
@export_multiline var locked_message := ""


func _ready() -> void:
	var shape := get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = shape.shape.duplicate()
	var rectangle := shape.shape as RectangleShape2D
	rectangle.size = Vector2(300, 40) if wall_side in ["north", "south"] else Vector2(40, 300)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if not required_flag.is_empty():
			var level := get_tree().current_scene as Level
			if level == null or not level.has_flag(required_flag):
				if level != null and not locked_message.is_empty():
					level.dialog_manager.show_dialog([locked_message])
				return
		EventBus.request_audio(&"door")
		exit_entered.emit(self)
