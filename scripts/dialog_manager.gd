extends CanvasLayer
## Screen-space dialog panel shared by interactions throughout the game.

var panel: PanelContainer
var message_label: Label
var close_hint: Label
var messages: Array[String] = []
var current_message := 0
var image_overlay: ColorRect
var image_preview: TextureRect
var image_hint: Label
var generated_audio: AudioStreamPlayer


func _ready() -> void:
	layer = 20
	_build_dialog()
	hide_dialog()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if image_overlay != null and image_overlay.visible:
			image_overlay.hide()
		elif is_dialog_open():
			advance_dialog()
		else:
			return
		get_viewport().set_input_as_handled()


func show_dialog(dialog_messages: Array[String]) -> void:
	if dialog_messages.is_empty():
		return
	messages = dialog_messages
	current_message = 0
	message_label.text = messages[current_message]
	panel.show()


func advance_dialog() -> void:
	current_message += 1
	if current_message >= messages.size():
		hide_dialog()
		return
	message_label.text = messages[current_message]


func is_dialog_open() -> bool:
	return panel != null and panel.visible


func hide_dialog() -> void:
	if panel:
		panel.hide()


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
		show_dialog(["Something happened in the background.\n\n%s" % content.get_string_from_utf8()])


func _show_generated_image(file_name: String, content: PackedByteArray) -> void:
	var image := Image.new()
	var load_error := ERR_UNAVAILABLE
	match file_name.get_extension().to_lower():
		"png": load_error = image.load_png_from_buffer(content)
		"jpg", "jpeg": load_error = image.load_jpg_from_buffer(content)
		"webp": load_error = image.load_webp_from_buffer(content)
	if load_error != OK:
		show_dialog(["Something happened in the background, but %s could not be displayed." % file_name])
		return
	if image_overlay == null:
		_build_image_overlay()
	hide_dialog()
	image_preview.texture = ImageTexture.create_from_image(image)
	image_hint.text = "Something happened in the background: %s  ·  Press E to hide" % file_name
	image_overlay.show()


func _play_generated_audio(file_name: String, content: PackedByteArray) -> void:
	var extension := file_name.get_extension().to_lower()
	var audio: AudioStream
	match extension:
		"wav": audio = AudioStreamWAV.load_from_buffer(content)
		"ogg": audio = AudioStreamOggVorbis.load_from_buffer(content)
		"mp3": audio = AudioStreamMP3.load_from_buffer(content)
	if audio == null:
		show_dialog(["Something happened in the background, but %s could not be played." % file_name])
		return
	if generated_audio == null:
		generated_audio = AudioStreamPlayer.new()
		generated_audio.name = "GeneratedFileAudio"
		add_child(generated_audio)
	generated_audio.stream = audio
	generated_audio.play()
	show_dialog(["Something happened in the background.\n\nPlaying %s once." % file_name])


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
	panel = PanelContainer.new()
	panel.name = "DialogPanel"
	panel.anchor_left = 0.04
	panel.anchor_top = 0.64
	panel.anchor_right = 0.96
	panel.anchor_bottom = 0.98
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var message_scroll := ScrollContainer.new()
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_scroll.custom_minimum_size.y = 100
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(message_scroll)

	message_label = Label.new()
	message_label.name = "Message"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.add_theme_color_override("font_color", Color("#fff8df"))
	message_label.add_theme_font_size_override("font_size", 20)
	message_scroll.add_child(message_label)

	close_hint = Label.new()
	close_hint.text = "Press E to continue"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.add_theme_color_override("font_color", Color("#c7b99a"))
	close_hint.add_theme_font_size_override("font_size", 14)
	content.add_child(close_hint)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#211f1b", 0.94)
	style.border_color = Color("#c7b99a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_top = 14
	style.content_margin_right = 22
	style.content_margin_bottom = 14
	return style
