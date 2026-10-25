extends Node
## Lives for the whole game and owns the players used for decoupled audio.

@export_group("Sounds")
@export var voice_message: AudioStream
@export var sound_registry: Dictionary = {
	&"switch": null,
	&"door": null,
	&"key": null,
	&"pickup": null,
	&"lock": null,
	&"footsteps": null,
	&"washing_machine": null,
}

@export_group("Music")
@export var music: AudioStream
@export var alternate_music: AudioStream
@export var loop_music: bool = true

var music_player: AudioStreamPlayer
var alternate_music_selected := false
var looping_players: Dictionary = {}
var lock_player: AudioStreamPlayer


func _ready() -> void:
	EventBus.audio_play_requested.connect(_play_audio)
	_start_music()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_music") and not event.is_echo():
		_toggle_music()


func _play_audio(sound_id: StringName, volume_db: float, bus: StringName) -> void:
	var stream := _get_sound_stream(sound_id)
	if stream == null:
		return
	if sound_id == &"lock" and is_instance_valid(lock_player) and not lock_player.is_queued_for_deletion():
		lock_player.volume_db = volume_db
		lock_player.bus = _get_audio_bus(bus)
		lock_player.play()
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = _get_audio_bus(bus)
	player.finished.connect(player.queue_free)
	add_child(player)
	if sound_id == &"lock":
		lock_player = player
	player.play()


func set_loop_active(
		sound_id: StringName,
		active: bool,
		bus: StringName = &"Sound",
		volume_db: float = 0.0
) -> void:
	var player := looping_players.get(sound_id) as AudioStreamPlayer
	if not active:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		looping_players.erase(sound_id)
		return
	if is_instance_valid(player):
		player.bus = _get_audio_bus(bus)
		player.volume_db = volume_db
		return
	var source := _get_sound_stream(sound_id)
	if source == null:
		return
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	else:
		return
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = _get_audio_bus(bus)
	player.volume_db = volume_db
	add_child(player)
	looping_players[sound_id] = player
	player.play()


func stop_sound_effects() -> void:
	for child in get_children():
		if child is AudioStreamPlayer and child != music_player:
			child.stop()
			child.queue_free()
	looping_players.clear()
	lock_player = null


func _get_sound_stream(sound_id: StringName) -> AudioStream:
	if sound_id == &"voice_message":
		return voice_message
	var stream: Variant = sound_registry.get(sound_id)
	if stream == null:
		stream = sound_registry.get(String(sound_id))
	return stream as AudioStream


func _start_music() -> void:
	if music == null:
		return

	if music is AudioStreamOggVorbis:
		music.loop = loop_music

	music_player = AudioStreamPlayer.new()
	music_player.stream = music
	music_player.bus = &"Music"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)
	music_player.play()


func _toggle_music() -> void:
	if music_player == null or alternate_music == null:
		return

	alternate_music_selected = not alternate_music_selected
	var selected_music := alternate_music if alternate_music_selected else music
	if selected_music is AudioStreamOggVorbis:
		selected_music.loop = loop_music
	music_player.stream = selected_music
	music_player.play()


func _on_music_finished() -> void:
	if loop_music and music_player != null:
		music_player.play()


func _get_audio_bus(bus: StringName) -> StringName:
	if AudioServer.get_bus_index(bus) == -1:
		return &"Master"
	return bus
