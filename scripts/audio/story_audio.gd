extends Node

var level: Level
var ending := false


func _ready() -> void:
	level = get_parent() as Level
	level.flag_changed.connect(_on_flag_changed)
	EventBus.game_completed.connect(_on_game_completed)
	_update_washing_machine()


func _exit_tree() -> void:
	AudioManager.stop_sound_effects()


func _on_flag_changed(_flag_id: String, _value: bool) -> void:
	_update_washing_machine()


func _on_game_completed() -> void:
	ending = true
	_update_washing_machine()


func _update_washing_machine() -> void:
	var active := level.has_flag("story.day_two") and not ending
	active = active and not level.has_flag("story.washing_machine_stopped")
	active = active and not level.has_flag("story.act_three")
	active = active and not level.has_flag("story.identity_read")
	AudioManager.set_loop_active(&"washing_machine", active, &"WashingMachine")
