extends RefCounted
class_name DialogueCatalog

const _STORIES: Dictionary = {
	&"cutscene.opening": preload("res://resources/dialogues/cutscene/opening.tres"),
	&"act1.intro": preload("res://resources/dialogues/act1/intro.tres"),
	&"act1.call": preload("res://resources/dialogues/act1/call.tres"),
	&"act1.no_response": preload("res://resources/dialogues/act1/no_response.tres"),
	&"act1.camera": preload("res://resources/dialogues/act1/camera.tres"),
	&"act1.locked": preload("res://resources/dialogues/act1/locked.tres"),
	&"act1.sleep": preload("res://resources/dialogues/act1/sleep.tres"),
	&"act2.wake": preload("res://resources/dialogues/act2/wake.tres"),
	&"act2.silhouette_scare": preload("res://resources/dialogues/act2/silhouette_scare.tres"),
	&"act2.coat_rack_reveal": preload("res://resources/dialogues/act2/coat_rack_reveal.tres"),
	&"act2.coat_rack_repeat": preload("res://resources/dialogues/act2/coat_rack_repeat.tres"),
	&"act2.cellar_approach": preload("res://resources/dialogues/act2/cellar_approach.tres"),
	&"act2.washing_machine": preload("res://resources/dialogues/act2/washing_machine.tres"),
	&"act2.leaving_cellar": preload("res://resources/dialogues/act2/leaving_cellar.tres"),
	&"act3.wake": preload("res://resources/dialogues/act3/wake.tres"),
	&"act3.attic_unreachable": preload("res://resources/dialogues/act3/attic_unreachable.tres"),
	&"act3.freezer_ladder": preload("res://resources/dialogues/act3/freezer_ladder.tres"),
	&"act3.attic_entry": preload("res://resources/dialogues/act3/attic_entry.tres"),
	&"act3.documents": preload("res://resources/dialogues/act3/documents.tres"),
	&"act3.diagnosis": preload("res://resources/dialogues/act3/diagnosis.tres"),
	&"act3.mirror_clue": preload("res://resources/dialogues/act3/mirror_clue.tres"),
	&"act3.code": preload("res://resources/dialogues/act3/code.tres"),
	&"act3.id_reveal": preload("res://resources/dialogues/act3/id_reveal.tres"),
}

static func get_story(story_id: StringName) -> StoryText:
	return _STORIES.get(story_id) as StoryText


static func get_messages(story_id: StringName) -> Array[String]:
	var result: Array[String] = []
	var story := get_story(story_id)
	if story == null:
		return result
	for message in story.messages:
		result.append(message)
	return result


static func get_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for story_id in _STORIES:
		result.append(story_id)
	result.sort()
	return result
