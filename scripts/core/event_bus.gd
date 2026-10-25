extends Node
## Shared signals for communication between otherwise decoupled game systems.

signal audio_play_requested(sound_id: StringName, volume_db: float, bus: StringName)
signal game_completed

const FINAL_CREDITS_SCENE := "res://scenes/ui/final_credits.tscn"

var _completion_requested := false


func _ready() -> void:
	game_completed.connect(_show_final_credits, CONNECT_DEFERRED)


func request_audio(
		sound_id: StringName,
		volume_db: float = 0.0,
		bus: StringName = &"Sound"
) -> void:
	if sound_id.is_empty():
		return
	audio_play_requested.emit(sound_id, volume_db, bus)


func complete_game() -> void:
	if _completion_requested:
		return
	_completion_requested = true
	game_completed.emit()


func reset_game_completion() -> void:
	_completion_requested = false


func _show_final_credits() -> void:
	var change_error := get_tree().change_scene_to_file(FINAL_CREDITS_SCENE)
	if change_error != OK:
		_completion_requested = false
		push_error("Could not open final credits: %s" % error_string(change_error))
