extends Area2D
## Cycles through sample files to exercise the web message previews.

const AUDIO_PATH := "res://assets/audio/voice_message.wav"

var nearby := false
var preview_index := 0
var hint: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not nearby or DialogManager.is_dialog_open() or not event.is_action_pressed("interact"):
		return
	_preview_next_file()
	get_viewport().set_input_as_handled()


func _preview_next_file() -> void:
	var result := OK
	match preview_index:
		0:
			result = UserMessages.deliver_user_message_text(
				"Something happened in the background. This is a sample text message from the main entrance.",
				"entrance_test_message.txt"
			)
		1:
			var room_texture := get_parent().get("background_texture") as Texture2D
			if room_texture == null:
				result = ERR_UNAVAILABLE
			else:
				result = UserMessages.deliver_user_picture(room_texture.get_image(), "entrance_test_picture.png")
		2:
			result = UserMessages.deliver_user_message_file(AUDIO_PATH, "entrance_test_audio.wav")
	if result != OK:
		DialogManager.show_dialog(["Could not create the test file. Error code: %d" % result])
	preview_index = (preview_index + 1) % 3
	_update_hint()


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
	hint.position = Vector2(-90, -55)
	hint.add_theme_color_override("font_color", Color("#fff8df"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_font_size_override("font_size", 16)
	hint.hide()
	add_child(hint)
	_update_hint()


func _update_hint() -> void:
	if hint != null:
		hint.text = "E  Test file preview (%d/3)" % (preview_index + 1)
