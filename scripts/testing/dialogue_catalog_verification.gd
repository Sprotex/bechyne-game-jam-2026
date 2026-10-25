extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids: Array[StringName] = DialogueCatalog.get_ids()
	_check(ids.size() == 23, "catalogue contains 23 dialogue resources")
	var message_count := 0
	for story_id in ids:
		var story: StoryText = DialogueCatalog.get_story(story_id)
		_check(story != null, "%s resolves to a story resource" % story_id)
		if story == null:
			continue
		var messages: Array[String] = DialogueCatalog.get_messages(story_id)
		_check(not story.messages.is_empty(), "%s has authored dialogue" % story_id)
		_check(messages.size() == story.messages.size(), "%s returns all dialogue lines" % story_id)
		message_count += messages.size()
	_check(message_count == 54, "catalogue contains 54 dialogue lines")
	_check(DialogueCatalog.get_story(&"act4.missing") == null, "unknown IDs return null stories")
	_check(DialogueCatalog.get_messages(&"act4.missing").is_empty(), "unknown IDs return empty typed dialogue")
	var wake_story: StoryText = DialogueCatalog.get_story(&"act3.wake")
	_check(
		wake_story != null and wake_story.messages[4] == "Proč by TETA bydlela se mnou? Kde  Ale byl tam ten klíč na půdu",
		"ambiguous authored line is preserved exactly"
	)
	if is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stop()
		AudioManager.music_player.stream = null
		AudioManager.music_player.queue_free()
		AudioManager.music_player = null
	AudioManager.music = null
	AudioManager.alternate_music = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("Dialogue catalogue verification: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
