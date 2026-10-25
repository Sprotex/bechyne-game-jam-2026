extends Area2D
## Lets the player call for her aunt once in each room during Act One.

@export var room_flag := ""

var level: Level
var nearby := false
var hint: Label


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hint = Label.new()
	hint.text = "%s  Zavolat na tetu" % InputPrompts.action_label(&"interact")
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
	level.set_flag(room_flag)
	level.dialog_manager.show_dialog(["Teto? Jsem tady!", "Odpovídá jen ticho."])
	_refresh_hint()
	get_viewport().set_input_as_handled()


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
	return level != null and not level.has_flag("story.day_two") and not room_flag.is_empty() and not level.has_flag(room_flag) and level.player_controls_enabled()


func _refresh_hint() -> void:
	hint.visible = nearby and _available()
