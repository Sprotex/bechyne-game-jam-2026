extends VBoxContainer

var digit := 0


func _ready() -> void:
	$Increase.pressed.connect(_change_digit.bind(1))
	$Decrease.pressed.connect(_change_digit.bind(-1))
	set_digit(digit)


func set_digit(value: int) -> void:
	digit = posmod(value, 10)
	$Digit.text = str(digit)


func _change_digit(step: int) -> void:
	set_digit(digit + step)
