extends Area2D

@export var document_texture: Texture2D
@export var story_id: StringName
@export var required_flags: PackedStringArray = []
@export var completed_flag := ""
@export var hint_text := "Prohlédnout dokument"
@export var completes_game := false

var level: Level
var nearby := false
var hint: Label
var reading := false


func _ready() -> void:
	level = get_tree().current_scene as Level
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()
	_update_availability()


func _process(_delta: float) -> void:
	_update_availability()
	if hint != null and nearby and is_visible_in_tree():
		hint.global_position = global_position + Vector2(-92.0, -62.0)


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or reading or level == null or not _requirements_met():
		return
	if not level.player_controls_enabled() or not event.is_action_pressed("interact"):
		return
	var messages := DialogueCatalog.get_messages(story_id)
	if messages.is_empty() or document_texture == null:
		return
	reading = true
	level.dialog_manager.document_closed.connect(_on_document_closed, CONNECT_ONE_SHOT)
	level.dialog_manager.show_document(document_texture, messages)
	get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = true
		_update_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby = false
		_update_hint()


func _on_document_closed() -> void:
	reading = false
	if level == null:
		return
	if not completed_flag.is_empty():
		level.set_flag(completed_flag)
	if completes_game:
		EventBus.call_deferred("complete_game")
	_update_hint()


func _requirements_met() -> bool:
	if level == null:
		return false
	for flag_id in required_flags:
		if not level.has_flag(flag_id):
			return false
	return true


func _update_availability() -> void:
	var available := _requirements_met()
	visible = available
	if hint != null:
		_update_hint()


func _update_hint() -> void:
	if hint == null:
		return
	hint.visible = nearby and not reading and _requirements_met()
	if hint.visible:
		hint.text = "%s  %s" % [InputPrompts.action_label(&"interact"), hint_text]


func _build_hint() -> void:
	hint = Label.new()
	hint.name = "EvidenceHint"
	hint.z_index = 4096
	hint.z_as_relative = false
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
	hint.set_as_top_level(true)

