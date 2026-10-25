extends RefCounted
class_name StoryProgression

const DAY_TWO_FLAG := "story.day_two"
const DIAGNOSIS_READ_FLAG := "story.diagnosis_read"
const ATTIC_UNLOCKED_FLAG := "story.attic_unlocked"


static func can_enter_attic(level: Level) -> bool:
	return (
		level != null
		and level.has_flag(DAY_TWO_FLAG)
		and level.has_flag(DIAGNOSIS_READ_FLAG)
	)


static func update_attic_readiness(level: Level) -> void:
	if level != null:
		level.set_flag(ATTIC_UNLOCKED_FLAG, can_enter_attic(level))
