extends RefCounted
class_name StoryProgression

const ATTIC_UNLOCKED_FLAG := "story.attic_unlocked"


static func can_enter_attic(level: Level) -> bool:
	return (
		level != null
		and level.has_flag("story.act_three")
		and level.has_flag("item.key")
	)


static func update_attic_readiness(level: Level) -> void:
	if level != null:
		level.set_flag(ATTIC_UNLOCKED_FLAG, can_enter_attic(level))
