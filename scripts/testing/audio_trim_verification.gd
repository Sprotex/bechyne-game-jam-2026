extends Node

const BACKUP := "res://audio_sources/untrimmed/2026-10-25/"
const ORIGINAL_HASHES := {
	"door": "4f8c51776686cc336f018edd4a19aa3702570a6196d134666cc24bfff2917798",
	"footsteps": "3ee15c0e588e9e81f3faab2b37c9c6fbe751fa6111c4828059b2ab1256e6b2dd",
	"lock": "ff1c229b27b4f730b838a4d0ab2f785de0afce69777661f301a2a991db74564f",
	"washing_machine": "5e670bea3fae3ba6893859255208143e869a0d38079909f226014334f3965ea0",
	"voice_message": "ea7a636e58c0ef4d764792a76ff9a7b48507daafcb82348f3223bb6e274e656a",
}
const START_SAMPLES := {"door": 30572, "footsteps": 28175, "lock": 147460, "washing_machine": 15321, "voice_message": 3158}

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for sound_name in ORIGINAL_HASHES:
		var original_path: String = BACKUP + sound_name + ".wav"
		_check(FileAccess.get_sha256(original_path) == ORIGINAL_HASHES[sound_name], "%s backup is byte-identical to the original recording" % sound_name)
		var original := _read_wave(original_path)
		var trimmed := _read_wave("res://assets/audio/" + sound_name + ".wav")
		if original.is_empty() or trimmed.is_empty():
			_check(false, "%s WAV files contain valid PCM audio" % sound_name)
			continue
		_check(original.rate == trimmed.rate and original.channels == trimmed.channels and trimmed.bits == 16, "%s trimming preserves sample rate, channels and PCM16 format" % sound_name)
		var original_data: PackedByteArray = original.data
		var trimmed_data: PackedByteArray = trimmed.data
		var removed := original_data.size() - trimmed_data.size()
		_check(removed > 0 and trimmed_data.size() > 0, "%s leading silence was removed without emptying the recording" % sound_name)
		var start_byte: int = START_SAMPLES[sound_name] * trimmed.channels * 2
		_check(original_data.slice(start_byte, start_byte + trimmed_data.size()) == trimmed_data, "%s selected waveform and internal pauses are unchanged" % sound_name)
		if sound_name == "lock":
			_check(trimmed_data.size() == (154350 - 147460) * trimmed.channels * 2, "lock contains only the selected single take")
		var peak := 0
		var onset_bytes := mini(trimmed_data.size(), roundi(trimmed.rate * trimmed.channels * 0.02) * 2)
		for offset in range(0, onset_bytes, 2):
			peak = maxi(peak, absi(trimmed_data.decode_s16(offset)))
		_check(peak >= 583, "%s sound begins within the first 20 milliseconds" % sound_name)
	_check(FileAccess.get_sha256(BACKUP + "creepy.ogg") == "d2e7d9a4f63827bba12132f8aa82c41c360e03aba7e69eb269ff3c959615a942", "original creepy music is backed up byte-identically")
	_check(is_equal_approx(AudioManager.music.get_length(), 54.0), "new creepy music is the supplied 54-second recording")
	_check(AudioManager.music is AudioStreamOggVorbis and AudioManager.music.loop, "new creepy music uses native OGG looping")
	_check(AudioManager.music_player.stream == AudioManager.music and AudioManager.music_player.playing, "new creepy music is connected to the active music player")
	AudioManager.stop_sound_effects()
	AudioManager.music_player.stop()
	AudioManager.music_player.queue_free()
	AudioManager.music_player = null
	AudioManager.music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Audio trim verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _read_wave(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_buffer(4).get_string_from_ascii() != "RIFF":
		return {}
	file.seek(8)
	if file.get_buffer(4).get_string_from_ascii() != "WAVE":
		return {}
	var result := {}
	while file.get_position() + 8 <= file.get_length():
		var chunk := file.get_buffer(4).get_string_from_ascii()
		var length := file.get_32()
		var next_chunk := file.get_position() + length + length % 2
		if chunk == "fmt " and length >= 16:
			if file.get_16() != 1:
				return {}
			result.channels = file.get_16()
			result.rate = file.get_32()
			file.get_32()
			file.get_16()
			result.bits = file.get_16()
		elif chunk == "data":
			result.data = file.get_buffer(length)
		file.seek(next_chunk)
	return result if result.has_all(["channels", "rate", "bits", "data"]) else {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
