extends Control
## Handles code entry for the statically laid out keypad scene.

signal submitted(is_correct: bool)
signal cancelled

@export var correct_code := "1234"

var entered_code := ""
@onready var display: Label = $Center/Content/Display


func _ready() -> void:
	for digit in ["7", "8", "9", "4", "5", "6", "1", "2", "3", "0"]:
		var button := get_node("Center/Content/KeypadGrid/Digit" + digit) as Button
		button.pressed.connect(_append_digit.bind(digit))
	(get_node("Center/Content/KeypadGrid/Delete") as Button).pressed.connect(_delete_digit)
	(get_node("Center/Content/KeypadGrid/Submit") as Button).pressed.connect(_submit)
	(get_node("Center/Content/Cancel") as Button).pressed.connect(_cancel)
	_update_display()


func _append_digit(digit: String) -> void:
	if entered_code.length() >= 4:
		return
	entered_code += digit
	_update_display()


func _delete_digit() -> void:
	if entered_code.is_empty():
		return
	entered_code = entered_code.left(entered_code.length() - 1)
	_update_display()


func _update_display() -> void:
	display.text = entered_code if not entered_code.is_empty() else "— — — —"


func _submit() -> void:
	submitted.emit(entered_code == correct_code)


func _cancel() -> void:
	cancelled.emit()
