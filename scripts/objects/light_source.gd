extends Node2D
## A room light that follows the level-wide EventBus state.


func _ready() -> void:
	EventBus.lights_state_changed.connect(_on_lights_state_changed)
	_on_lights_state_changed(EventBus.lights_are_on)


func _on_lights_state_changed(is_on: bool) -> void:
	$PointLight2D.enabled = is_on
