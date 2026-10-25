extends Area2D

var nearby := false
var hint: Label
var level: Level


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()


func _process(_delta: float) -> void:
	if nearby:
		_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if (
		nearby
		and level != null
		and level.has_flag("story.act_three")
		and level.has_flag("story.mirror_photographed")
		and not level.has_flag(Level.ATTIC_COMBINATION_FLAG)
		and level.player_controls_enabled()
		and event.is_action_pressed("interact")
	):
		level.open_keypad()
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
	hint.text = "%s  Použít číselný zámek" % InputPrompts.action_label(&"interact")
	hint.position = Vector2(-100, -55)
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)


func _update_hint() -> void:
	if level == null or not level.has_flag("story.act_three") or not level.has_flag("story.mirror_photographed") or level.has_flag(Level.ATTIC_COMBINATION_FLAG):
		hint.hide()
	else:
		hint.show()
