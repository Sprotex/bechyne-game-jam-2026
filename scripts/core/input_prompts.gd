extends RefCounted
class_name InputPrompts


static func action_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action).capitalize()
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return String(action).capitalize()
	var labels: PackedStringArray = []
	for event in events:
		var label := event.as_text().replace(" - Physical", "").replace("(Physical)", "").strip_edges()
		if not labels.has(label):
			labels.append(label)
	return " / ".join(labels)
