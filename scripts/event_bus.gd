extends Node
## Shared signals for communication between otherwise decoupled game systems.

signal audio_play_requested(sound_id: StringName, volume_db: float, bus: StringName)


func request_audio(
		sound_id: StringName,
		volume_db: float = 0.0,
		bus: StringName = &"Master"
) -> void:
	if sound_id.is_empty():
		return
	audio_play_requested.emit(sound_id, volume_db, bus)
