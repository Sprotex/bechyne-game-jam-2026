extends Node
## Lives for the whole game and owns the players used for decoupled audio.

@export_group("Sounds")
@export var voice_message: AudioStream

@export_group("Music")
@export var music: AudioStream
@export var alternate_music: AudioStream
@export var loop_music: bool = true

var music_player: AudioStreamPlayer
var alternate_music_selected := false


func _ready() -> void:
	EventBus.audio_play_requested.connect(_play_audio)
	_start_music()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_music") and not event.is_echo():
		_toggle_music()


func _play_audio(sound_id: StringName, volume_db: float, bus: StringName) -> void:
	var stream := _get_sound_stream(sound_id)
	if stream == null:
		push_warning("No audio stream is registered for sound ID '%s'." % sound_id)
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = _get_audio_bus(bus)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _get_sound_stream(sound_id: StringName) -> AudioStream:
	match sound_id:
		&"voice_message":
			return voice_message
		_:
			return null


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
