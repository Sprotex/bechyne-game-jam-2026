extends CanvasLayer
class_name GameDialogManager
## Screen-space dialog panel shared by interactions throughout the game.

signal modal_changed
signal message_changed(message_index: int)
signal dialog_finished

const DIALOG_BOX_SCENE := preload("res://scenes/ui/dialog_box.tscn")

@export_range(1.0, 100.0, 1.0, "or_greater") var characters_per_second := 20.0

var panel: PanelContainer
var message_label: Label
var messages: Array[String] = []
var current_message := 0
var reveal_tween: Tween
var image_overlay: ColorRect
var image_preview: TextureRect
var image_hint: Label
var generated_audio: AudioStreamPlayer
var input_enabled := true


func _ready() -> void:
	layer = 20
	_build_dialog()
	(get_node("DialogPanel/Content/CloseHint") as Label).text = "Pokračovat: %s" % InputPrompts.action_label(&"interact")
	get_window().size_changed.connect(_update_dialog_font_size)
	_update_dialog_font_size()
	hide_dialog()


func _process(_delta: float) -> void:
	if not OS.is_debug_build() or not Input.is_key_pressed(KEY_CTRL):
		return
	if not input_enabled or not is_dialog_open():
		return
	if _is_revealing():
		_finish_reveal()
	else:
		advance_dialog()


func _input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("interact"):
		if image_overlay != null and image_overlay.visible:
			image_overlay.hide()
			modal_changed.emit()
		elif is_dialog_open():
			if _is_revealing():
				_finish_reveal()
			else:
				advance_dialog()
		else:
			return
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled


func show_dialog(dialog_messages: Array[String]) -> void:
	if dialog_messages.is_empty():
		return
	messages = dialog_messages
	current_message = 0
	_set_message(messages[current_message])
	message_changed.emit(current_message)
	panel.show()
	modal_changed.emit()


func advance_dialog() -> void:
	current_message += 1
	if current_message >= messages.size():
		hide_dialog()
		dialog_finished.emit()
		return
	_set_message(messages[current_message])
	message_changed.emit(current_message)


func is_dialog_open() -> bool:
	return panel != null and panel.visible


func is_modal_open() -> bool:
	return is_dialog_open() or (image_overlay != null and image_overlay.visible)


func hide_dialog() -> void:
	_stop_reveal()
	if panel and panel.visible:
		panel.hide()
		modal_changed.emit()


func _set_message(message: String) -> void:
	_stop_reveal()
	message_label.text = message
	message_label.visible_characters = 0
	var character_count := message_label.get_total_character_count()
	if character_count == 0:
		return
	reveal_tween = create_tween()
	reveal_tween.set_trans(Tween.TRANS_LINEAR)
	reveal_tween.tween_property(
		message_label,
		"visible_characters",
		character_count,
		float(character_count) / maxf(characters_per_second, 1.0)
	)


func _is_revealing() -> bool:
	return reveal_tween != null and reveal_tween.is_running()


func _finish_reveal() -> void:
	if reveal_tween != null and reveal_tween.is_running():
		reveal_tween.kill()
	message_label.visible_characters = -1


func _stop_reveal() -> void:
	if reveal_tween != null and reveal_tween.is_running():
		reveal_tween.kill()
	reveal_tween = null


func show_generated_file(file_name: String, content: PackedByteArray) -> void:
	if not OS.has_feature("web"):
		return
	if image_overlay != null:
		image_overlay.hide()
	if generated_audio != null:
		generated_audio.stop()
	var extension := file_name.get_extension().to_lower()
	if extension in ["png", "jpg", "jpeg", "webp"]:
		_show_generated_image(file_name, content)
	elif extension in ["wav", "ogg", "mp3"]:
		_play_generated_audio(file_name, content)
	else:
		show_dialog(["Na pozadí se něco stalo."])


func _show_generated_image(file_name: String, content: PackedByteArray) -> void:
	var image := Image.new()
	var load_error := ERR_UNAVAILABLE
	match file_name.get_extension().to_lower():
		"png": load_error = image.load_png_from_buffer(content)
		"jpg", "jpeg": load_error = image.load_jpg_from_buffer(content)
		"webp": load_error = image.load_webp_from_buffer(content)
	if load_error != OK:
		show_dialog(["Na pozadí se něco stalo, ale soubor %s se nepodařilo zobrazit." % file_name])
		return
	if image_overlay == null:
		_build_image_overlay()
	hide_dialog()
	image_preview.texture = ImageTexture.create_from_image(image)
	image_hint.text = "Na pozadí se něco stalo: %s  ·  Skrýt: %s" % [file_name, InputPrompts.action_label(&"interact")]
	image_overlay.show()
	modal_changed.emit()


func _play_generated_audio(file_name: String, content: PackedByteArray) -> void:
	var extension := file_name.get_extension().to_lower()
	var audio: AudioStream
	match extension:
		"wav": audio = AudioStreamWAV.load_from_buffer(content)
		"ogg": audio = AudioStreamOggVorbis.load_from_buffer(content)
		"mp3": audio = AudioStreamMP3.load_from_buffer(content)
	if audio == null:
		show_dialog(["Na pozadí se něco stalo, ale soubor %s se nepodařilo přehrát." % file_name])
		return
	if generated_audio == null:
		generated_audio = AudioStreamPlayer.new()
		generated_audio.name = "GeneratedFileAudio"
		generated_audio.bus = &"Sound"
		add_child(generated_audio)
	generated_audio.stream = audio
	generated_audio.play()
	show_dialog(["Na pozadí se něco stalo.\n\nPřehrávám soubor %s." % file_name])


func _build_image_overlay() -> void:
	image_overlay = ColorRect.new()
	image_overlay.name = "GeneratedImageOverlay"
	image_overlay.color = Color(0.02, 0.02, 0.02, 0.94)
	image_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image_overlay)

	image_preview = TextureRect.new()
	image_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_preview.offset_left = 32
	image_preview.offset_top = 32
	image_preview.offset_right = -32
	image_preview.offset_bottom = -72
	image_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_overlay.add_child(image_preview)

	image_hint = Label.new()
	image_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	image_hint.offset_top = -56
	image_hint.offset_bottom = -16
	image_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	image_hint.add_theme_color_override("font_color", Color("#fff8df"))
	image_hint.add_theme_font_size_override("font_size", 18)
	image_overlay.add_child(image_hint)


func _build_dialog() -> void:
	var dialog_box := DIALOG_BOX_SCENE.instantiate()
	panel = dialog_box as PanelContainer
	var message_scroll := dialog_box.get_node("Content/MessageScroll") as ScrollContainer
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_label = dialog_box.get_node("Content/MessageScroll/Message") as Label
	add_child(dialog_box)


func _update_dialog_font_size() -> void:
	if message_label == null:
		return
	var viewport_size := Vector2(get_window().size)
	var scale := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	message_label.add_theme_font_size_override("font_size", roundi(clampf(28.0 * scale, 22.0, 28.0)))
	var close_hint := get_node("DialogPanel/Content/CloseHint") as Label
	close_hint.add_theme_font_size_override("font_size", roundi(clampf(17.0 * scale, 14.0, 17.0)))
