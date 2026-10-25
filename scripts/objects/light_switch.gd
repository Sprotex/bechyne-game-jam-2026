extends Interactor
## Toggles the lights in its room.

const OFF_TEXTURE := preload("res://assets/gfx/vypinac_vypnuto.png")
const ON_TEXTURE := preload("res://assets/gfx/vypinac_zapnuto.png")

var room: Room


func _ready() -> void:
	interaction_hint = "Přepnout světla"
	room = get_parent() as Room
	room.lights_state_changed.connect(_on_lights_state_changed)
	super._ready()
	_on_lights_state_changed(room.lights_are_on)


func _interact() -> void:
	room.toggle_lights()
	EventBus.request_audio(&"switch")


func _on_lights_state_changed(is_on: bool) -> void:
	$Sprite2D.texture = ON_TEXTURE if is_on else OFF_TEXTURE
