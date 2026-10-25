extends Node
class_name DialogTypewriterAudio

const CLICK_VOLUME_DB := -18.0
const MIN_PITCH_SCALE := 0.94
const MAX_PITCH_SCALE := 1.06

var player: AudioStreamPlayer
var random := RandomNumberGenerator.new()
var last_visible_characters := 0


func _ready() -> void:
	random.randomize()
	player = AudioStreamPlayer.new()
	player.name = "TypewriterClickPlayer"
	player.bus = &"Sound"
	player.volume_db = CLICK_VOLUME_DB
	add_child(player)


func update_reveal(message: String, visible_characters: int, active: bool) -> void:
	if visible_characters < 0:
		stop()
		last_visible_characters = message.length()
		return
	var visible_count := mini(visible_characters, message.length())
	if not active:
		stop()
		last_visible_characters = visible_count
		return
	if visible_count > last_visible_characters and _range_contains_printable(message, last_visible_characters, visible_count):
		_play_click()
	last_visible_characters = visible_count


func stop() -> void:
	if is_instance_valid(player):
		player.stop()
	last_visible_characters = 0


func _play_click() -> void:
	if not is_instance_valid(player):
		return
	var click_stream := AudioManager._get_sound_stream(&"lock")
	if click_stream == null:
		return
	player.stream = click_stream
	player.pitch_scale = random.randf_range(MIN_PITCH_SCALE, MAX_PITCH_SCALE)
	player.play()


func _range_contains_printable(message: String, start: int, end: int) -> bool:
	for character_index in range(start, end):
		if not message.substr(character_index, 1).strip_edges().is_empty():
			return true
	return false
