extends Area2D
## Stops the washer and grants its forgotten key once the player empties it.

var level: Level
var nearby := false
var hint: Label


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hint = Label.new()
	hint.text = "%s  Vyndat prádlo" % InputPrompts.action_label(&"interact")
	hint.position = Vector2(-78, -52)
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
	if level != null:
		level.flag_changed.connect(_on_flag_changed)
	_refresh_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or not _available() or not event.is_action_pressed("interact"):
		return
	level.dialog_manager.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	level.dialog_manager.show_dialog([
		"Pračka pořád běží. Vytáhnu to mokré prádlo.",
		"V kapse něco cinká. Našla jsem starý klíč!",
	])
	get_viewport().set_input_as_handled()


func _on_dialog_finished() -> void:
	if level == null or level.has_flag("story.washing_machine_stopped"):
		return
	level.set_flag("story.washing_machine_stopped")
	level.set_flag("item.key")
	EventBus.request_audio(&"key")
	level.dialog_manager.show_dialog(["Klíč od půdy schovám. Tady už se nedá dýchat."])
	_refresh_hint()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = true
		_refresh_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		hint.hide()


func _on_flag_changed(_flag_id: String, _value: bool) -> void:
	_refresh_hint()


func _available() -> bool:
	return level != null and level.has_flag("story.day_two") and not level.has_flag("story.washing_machine_stopped") and level.player_controls_enabled()


func _refresh_hint() -> void:
	hint.visible = nearby and _available()
