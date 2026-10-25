extends Control

signal back_pressed

const CREDITS_DATA := preload("res://resources/credits.tres")

@export var title_text := "AUTOŘI"
@export var back_text := "ZPĚT"

var _title_label: Label
var _back_button: Button


func _ready() -> void:
	_build_contents()


func set_presentation(title: String, back: String) -> void:
	title_text = title
	back_text = back
	if _title_label != null:
		_title_label.text = title_text
		_back_button.text = back_text


func _build_contents() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.045, 0.055, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 120.0
	layout.offset_top = 70.0
	layout.offset_right = -120.0
	layout.offset_bottom = -70.0
	layout.add_theme_constant_override("separation", 24)
	add_child(layout)

	var title := Label.new()
	_title_label = title
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fff8df"))
	title.add_theme_font_size_override("font_size", 42)
	layout.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 18)
	scroll.add_child(names)
	for contributor in CREDITS_DATA.names:
		var label := Label.new()
		label.text = contributor
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#fff8df"))
		label.add_theme_font_size_override("font_size", 28)
		names.add_child(label)

	var back := Button.new()
	_back_button = back
	back.name = "Back"
	back.text = back_text
	back.custom_minimum_size = Vector2(240, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	layout.add_child(back)


func _on_back_pressed() -> void:
	back_pressed.emit()
