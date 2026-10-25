extends Area2D

const STORY_ID := &"act3.attic_entry"
const COMPLETED_FLAG := "story.attic_entered"

var nearby := false
var hint: Label
var level: Level


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or level == null or not level.player_controls_enabled():
		return
	if not event.is_action_pressed("interact") or level.has_flag(COMPLETED_FLAG):
		return
	var story := DialogueCatalog.get_story(STORY_ID)
	if story != null:
		story.show(level)
		level.set_flag(COMPLETED_FLAG)
	_update_hint()
	get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = true
		_update_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		hint.hide()


func _build_hint() -> void:
	hint = Label.new()
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.position = Vector2(-68, -55)
	hint.text = "%s  Prohlédnout" % InputPrompts.action_label(&"interact")
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)


func _update_hint() -> void:
	hint.visible = nearby and level != null and not level.has_flag(COMPLETED_FLAG)
