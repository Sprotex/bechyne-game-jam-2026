extends Area2D
class_name Interactor
## Shared proximity, input, and hint behavior for world interactions.

@export var interaction_hint := ""

var nearby := false
var hint: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()
	_refresh_hint()


func _process(_delta: float) -> void:
	_refresh_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or not _can_interact():
		return
	get_viewport().set_input_as_handled()
	_interact()


func _can_interact() -> bool:
	var level := _interaction_level()
	return nearby and level != null and level.player_controls_enabled()


func _interact() -> void:
	pass


func _is_interaction_body(body: Node2D) -> bool:
	return body is CharacterBody2D


func _interaction_level() -> Level:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Level:
			return ancestor as Level
		ancestor = ancestor.get_parent()
	return get_tree().current_scene as Level


func _on_body_entered(body: Node2D) -> void:
	if _is_interaction_body(body):
		nearby = true
		_refresh_hint()


func _on_body_exited(body: Node2D) -> void:
	if _is_interaction_body(body):
		nearby = false
		_refresh_hint()
		_on_left_range()


func _on_left_range() -> void:
	pass


func _refresh_hint() -> void:
	if not is_instance_valid(hint):
		return
	hint.visible = _can_interact()
	if hint.visible:
		_clamp_hint_to_viewport()


func _clamp_hint_to_viewport() -> void:
	var parent := hint.get_parent() as CanvasItem
	var parent_transform := parent.get_global_transform_with_canvas()
	var hint_transform := hint.get_global_transform_with_canvas()
	var screen_position := hint_transform * Vector2.ZERO
	var screen_size := hint_transform.basis_xform(hint.size).abs()
	var viewport_size := get_viewport_rect().size
	var maximum := (viewport_size - screen_size - Vector2(8.0, 8.0)).max(Vector2(8.0, 8.0))
	var clamped_position := screen_position.clamp(Vector2(8.0, 8.0), maximum)
	if not screen_position.is_equal_approx(clamped_position):
		hint.position = parent_transform.affine_inverse() * clamped_position


func _build_hint() -> void:
	hint = Label.new()
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.position = Vector2(-80, 38)
	hint.text = "%s  %s" % [InputPrompts.action_label(&"interact"), interaction_hint]
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
