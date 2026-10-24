extends Area2D
## Bathroom prototype interaction that opens the shared dialog panel.

var nearby := false
var hint: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()


func _unhandled_input(event: InputEvent) -> void:
	if nearby and not DialogManager.is_dialog_open() and event.is_action_pressed("interact"):
		DialogManager.show_dialog([
			"The mirror is fogged over.",
			"Someone has written: HELLO.",
		])
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
	hint.text = "E  Interact"
	hint.position = Vector2(-48, -55)
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
