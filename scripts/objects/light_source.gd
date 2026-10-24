extends Node2D
## A room light that follows its containing room's state.

var room: Room


func _ready() -> void:
	room = get_parent() as Room
	room.lights_state_changed.connect(_on_lights_state_changed)
	_on_lights_state_changed(room.lights_are_on)


func _on_lights_state_changed(is_on: bool) -> void:
	$PointLight2D.enabled = is_on
