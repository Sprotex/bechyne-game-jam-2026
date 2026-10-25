extends Control

const MAIN_SCENE := "res://scenes/root.tscn"


func _ready() -> void:
	var credits := $Credits
	credits.set_presentation("ZÁVĚREČNÉ TITULKY", "ZPĚT DO MENU")
	credits.back_pressed.connect(_return_to_main_menu)


func _return_to_main_menu() -> void:
	EventBus.reset_game_completion()
	get_tree().change_scene_to_file(MAIN_SCENE)
