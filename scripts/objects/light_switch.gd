extends Area2D
## Toggles every room light through the shared event bus.

const OFF_TEXTURE := preload("res://assets/gfx/vypinac_vypnuto.png")
const ON_TEXTURE := preload("res://assets/gfx/vypinac_zapnuto.png")

var nearby := false
var hint: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.lights_state_changed.connect(_on_lights_state_changed)
	_build_hint()
	_on_lights_state_changed(EventBus.lights_are_on)


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or not event.is_action_pressed("interact"):
		return
	var level := get_tree().current_scene as Level
	if level == null or not level.player_controls_enabled():
		return
	EventBus.toggle_lights()
	get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = true
		hint.show()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		hint.hide()


func _on_lights_state_changed(is_on: bool) -> void:
	$Sprite2D.texture = ON_TEXTURE if is_on else OFF_TEXTURE


func _build_hint() -> void:
	hint = Label.new()
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.position = Vector2(-80, 38)
	hint.text = "%s  Přepnout světla" % InputPrompts.action_label(&"interact")
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
