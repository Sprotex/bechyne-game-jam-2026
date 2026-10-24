extends Area2D
## Starts the sleep dialog when the player approaches the bed.

var nearby := false
var hint: Label
var level: Level


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()


func _unhandled_input(event: InputEvent) -> void:
	if nearby and level != null and level.player_controls_enabled() and event.is_action_pressed("interact"):
		level.start_sleep_dialog()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = true
		hint.show()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		hint.hide()


func _build_hint() -> void:
	hint = Label.new()
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.text = "%s  Jít spát" % InputPrompts.action_label(&"interact")
	hint.position = Vector2(-58, -55)
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
