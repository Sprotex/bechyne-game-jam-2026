extends Area2D
## Sends a picture of the current room when the player interacts nearby.

var level: Level
var nearby := false
var hint: Label


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hint = Label.new()
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.position = Vector2(-90, -55)
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
	_update_hint()


func _process(_delta: float) -> void:
	if nearby:
		_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or level == null or not level.has_flag("item.camera"):
		return
	if not level.player_controls_enabled() or not event.is_action_pressed("interact"):
		return
	level.send_room_photo()
	get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = true
		_update_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		hint.hide()


func _update_hint() -> void:
	if hint == null or not nearby or level == null or not level.has_flag("item.camera"):
		hint.hide()
		return
	hint.text = "%s  Vyfotit místnost" % InputPrompts.action_label(&"interact")
	hint.show()
