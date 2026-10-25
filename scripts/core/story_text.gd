extends Resource
class_name StoryText

@export var messages: PackedStringArray = []
@export var locked_messages: PackedStringArray = []
@export var required_flag := ""
@export var completed_flag := ""


func is_available(level: Level) -> bool:
	return required_flag.is_empty() or level.has_flag(required_flag)


func is_completed(level: Level) -> bool:
	return not completed_flag.is_empty() and level.has_flag(completed_flag)


func show(level: Level) -> void:
	if level == null or is_completed(level):
		return
	var lines: Array[String] = []
	var source := messages if is_available(level) else locked_messages
	for line in source:
		lines.append(line)
	if not lines.is_empty():
		level.dialog_manager.show_dialog(lines)
	if is_available(level) and not completed_flag.is_empty():
		level.set_flag(completed_flag)
