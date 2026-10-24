extends Node
## Shared signals for communication between otherwise decoupled game systems.

signal audio_play_requested(sound_id: StringName, volume_db: float, bus: StringName)
signal lights_state_changed(is_on: bool)

var lights_are_on := true


func request_audio(
		sound_id: StringName,
		volume_db: float = 0.0,
		bus: StringName = &"Sound"
) -> void:
	if sound_id.is_empty():
		return
	audio_play_requested.emit(sound_id, volume_db, bus)


func toggle_lights() -> void:
	set_lights_enabled(not lights_are_on)


func set_lights_enabled(is_on: bool) -> void:
	if lights_are_on == is_on:
		return
	lights_are_on = is_on
	lights_state_changed.emit(lights_are_on)
