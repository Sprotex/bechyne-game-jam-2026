extends Area2D
class_name PersistentPickup

@export var item_id := ""
@export var item_label := "Předmět"
@export var draw_default_icon := true
@export_multiline var pickup_message := ""

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
	hint.position = Vector2(-60, -48)
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.hide()
	add_child(hint)
	hint.set_as_top_level(true)
	hint.global_position = global_position + Vector2(-60, -48)
	if level != null and level.has_flag(item_id):
		_hide_pickup()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or item_id.is_empty() or level == null or not level.player_controls_enabled() or not event.is_action_pressed("interact"):
		return
	level.set_flag(item_id)
	EventBus.request_audio(&"key" if item_id == "item.key" else &"pickup")
	_hide_pickup()
	if not pickup_message.is_empty():
		level.dialog_manager.show_dialog([pickup_message])
	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not draw_default_icon:
		return
	draw_circle(Vector2.ZERO, 15.0, Color("#d5ae22"))
	draw_circle(Vector2.ZERO, 8.0, Color("#fff8df"))


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and visible:
		nearby = true
		hint.text = "%s  Seber: %s" % [InputPrompts.action_label(&"interact"), item_label]
		hint.show()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		hint.hide()


func _hide_pickup() -> void:
	visible = false
	monitoring = false
