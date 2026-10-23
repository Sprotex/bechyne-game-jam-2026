extends Node2D

var delivery_status: Label


func _ready() -> void:
	_build_message_terminal()


func _build_message_terminal() -> void:
	var canvas := $HUD
	var panel := PanelContainer.new()
	panel.name = "MessageTerminal"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440.0
	panel.offset_top = -215.0
	panel.offset_right = 440.0
	panel.offset_bottom = 215.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101b25"), Color("#315261"), 2, 18, 22))
	canvas.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "FIELD COMMUNICATIONS  /  USER DIRECTORY"
	eyebrow.add_theme_color_override("font_color", Color("#64d6c4"))
	eyebrow.add_theme_font_size_override("font_size", 12)
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "Deliver a user message"
	title.add_theme_color_override("font_color", Color("#f0f5f6"))
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)

	var intro := Label.new()
	intro.text = "Messages appear as real files in your User Messages folder."
	intro.add_theme_color_override("font_color", Color("#a9bbc3"))
	intro.add_theme_font_size_override("font_size", 15)
	content.add_child(intro)

	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	content.add_child(cards)

	cards.add_child(_make_message_card(
		"01  TEXT NOTE",
		"A short transmission, delivered as a readable .txt file.",
		"Deliver text message",
		_deliver_demo_text
	))
	cards.add_child(_make_message_card(
		"02  PICTURE",
		"A field photograph, copied in its original image format.",
		"Deliver picture",
		_deliver_demo_picture
	))
	cards.add_child(_make_message_card(
		"03  AUDIO",
		"A spoken voice memo, delivered as a .wav file.",
		"Deliver audio message",
		_deliver_demo_audio
	))

	delivery_status = Label.new()
	delivery_status.text = "Choose a message to deliver."
	delivery_status.add_theme_color_override("font_color", Color("#9db0b8"))
	delivery_status.add_theme_font_size_override("font_size", 13)
	content.add_child(delivery_status)


func _make_message_card(
		heading: String,
		description: String,
		button_text: String,
		action: Callable
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color("#172833"), Color("#29414c"), 1, 12, 16))

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	card.add_child(layout)

	var type_label := Label.new()
	type_label.text = heading
	type_label.add_theme_color_override("font_color", Color("#70d8c8"))
	type_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(type_label)

	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.add_theme_color_override("font_color", Color("#c5d1d5"))
	description_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(description_label)

	var deliver_button := Button.new()
	deliver_button.text = button_text
	deliver_button.custom_minimum_size.y = 42
	deliver_button.add_theme_color_override("font_color", Color("#08211f"))
	deliver_button.add_theme_stylebox_override("normal", _panel_style(Color("#70d8c8"), Color("#70d8c8"), 0, 8, 10))
	deliver_button.add_theme_stylebox_override("hover", _panel_style(Color("#9aeadf"), Color("#9aeadf"), 0, 8, 10))
	deliver_button.add_theme_stylebox_override("pressed", _panel_style(Color("#50b7a8"), Color("#50b7a8"), 0, 8, 10))
	deliver_button.pressed.connect(action)
	layout.add_child(deliver_button)
	return card


func _panel_style(fill: Color, border: Color, border_size: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_size)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


func _deliver_demo_text() -> void:
	_deliver_and_report(
		UserMessages.deliver_user_message_text(
			"If you can read this, the line is open. Meet me where the old signal tower touches the clouds.",
			"incoming_transmission.txt"
		),
		"Text message"
	)


func _deliver_demo_picture() -> void:
	_deliver_and_report(
		UserMessages.deliver_user_picture("res://assets/signal_tower.svg"),
		"Picture"
	)


func _deliver_demo_audio() -> void:
	_deliver_and_report(
		UserMessages.deliver_user_audio("res://assets/voice_message.wav"),
		"Audio message"
	)


func _deliver_and_report(error: Error, message_type: String) -> void:
	if error != OK:
		delivery_status.text = "%s could not be delivered: %s" % [message_type, error_string(error)]
		delivery_status.add_theme_color_override("font_color", Color("#ff8a83"))
		return

	delivery_status.text = "%s delivered to User Messages. Open the folder to see it." % message_type
	delivery_status.add_theme_color_override("font_color", Color("#70d8c8"))


func _on_open_user_messages_pressed() -> void:
	var error := UserMessages.open_user_messages_folder()
	if error != OK:
		delivery_status.text = "Could not open User Messages folder: " + error_string(error)
		delivery_status.add_theme_color_override("font_color", Color("#ff8a83"))
