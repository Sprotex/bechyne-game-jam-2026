extends Control

signal back_pressed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.045, 0.055, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_constant_override("separation", 18)
	center.add_child(panel)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fff8df"))
	title.add_theme_font_size_override("font_size", 42)
	panel.add_child(title)
	_add_volume_control(panel, "Master volume", &"Master")
	_add_volume_control(panel, "Music volume", &"Music")
	_add_volume_control(panel, "Sound volume", &"Sound")

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func(): back_pressed.emit())
	panel.add_child(back)


func _add_volume_control(parent: VBoxContainer, label_text: String, bus_name: StringName) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color("#e1ded3"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus_name))
	slider.value_changed.connect(_set_bus_volume.bind(bus_name))
	row.add_child(slider)


func _set_bus_volume(value: float, bus_name: StringName) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus_name), value)
