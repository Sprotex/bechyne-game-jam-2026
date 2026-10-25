extends Control

signal submitted(is_correct: bool)
signal cancelled

@export var correct_code := "1234"

var submission_sent := false
var entered_code: String:
	get:
		var code := ""
		for wheel in wheels.get_children():
			code += str(wheel.digit)
		return code

@onready var wheels: HBoxContainer = $Center/Panel/Content/KeypadGrid
@onready var submit_button: Button = $Center/Panel/Content/Submit


func _ready() -> void:
	submit_button.pressed.connect(_submit)
	(wheels.get_child(0).get_node("Increase") as Button).grab_focus()


func _submit() -> void:
	if submission_sent:
		return
	submission_sent = true
	submit_button.disabled = true
	submitted.emit(entered_code == correct_code)
