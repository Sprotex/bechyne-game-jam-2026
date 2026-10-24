extends Control
## Mouse operated code entry panel for the bedroom keypad.

signal submitted(is_correct: bool)
signal cancelled

@export var correct_code := "1234"

var entered_code := ""
var display: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_update_display()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.025, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 570)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title := Label.new()
	title.text = "ČÍSELNÝ ZÁMEK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	display = Label.new()
	display.custom_minimum_size = Vector2(0, 58)
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display.add_theme_font_size_override("font_size", 30)
	display.add_theme_color_override("font_color", Color("#a8e6b2"))
	content.add_child(display)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for digit in ["7", "8", "9", "4", "5", "6", "1", "2", "3"]:
		_add_button(grid, digit, _append_digit.bind(digit), Vector2(96, 72))
	_add_button(grid, "SMAZAT", _delete_digit, Vector2(96, 72))
	_add_button(grid, "0", _append_digit.bind("0"), Vector2(96, 72))
	_add_button(grid, "ODESLAT", _submit, Vector2(96, 72))

	var cancel_button := Button.new()
	cancel_button.text = "ZAVŘÍT"
	cancel_button.custom_minimum_size = Vector2(0, 44)
	cancel_button.pressed.connect(_cancel)
	content.add_child(cancel_button)


func _add_button(parent: GridContainer, label: String, callback: Callable, size: Vector2) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	parent.add_child(button)


func _append_digit(digit: String) -> void:
	entered_code += digit
	_update_display()


func _delete_digit() -> void:
	if entered_code.is_empty():
		_cancel()
		return
	entered_code = entered_code.left(entered_code.length() - 1)
	_update_display()


func _update_display() -> void:
	if display != null:
		display.text = entered_code if not entered_code.is_empty() else "— — — —"


func _submit() -> void:
	submitted.emit(entered_code == correct_code)


func _cancel() -> void:
	cancelled.emit()
