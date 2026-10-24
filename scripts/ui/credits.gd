extends Control

signal back_pressed


func _on_back_pressed() -> void:
	back_pressed.emit()
