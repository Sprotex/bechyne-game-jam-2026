extends Node2D

const LEVEL_SCENE := "res://scenes/level.tscn"
const DOMECEK := preload("res://assets/gfx/domecek.png")


func _ready() -> void:
	_build_menu()


func _build_menu() -> void:
	var background := TextureRect.new()
	background.texture = DOMECEK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.modulate = Color(0.42, 0.42, 0.42, 1.0)
	$HUD.add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.055, 0.07, 0.08, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(center)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(520, 280)
	menu.add_theme_constant_override("separation", 18)
	center.add_child(menu)

	var eyebrow := Label.new()
	eyebrow.text = "A ROOM TO EXPLORE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Color("#d5ae22"))
	eyebrow.add_theme_font_size_override("font_size", 16)
	menu.add_child(eyebrow)

	var title := Label.new()
	title.text = "THE ROOMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fff8df"))
	title.add_theme_font_size_override("font_size", 54)
	menu.add_child(title)

	var prompt := Label.new()
	prompt.text = "Move with WASD or the arrow keys.\nMessages created along the way will appear here."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color("#e1ded3"))
	prompt.add_theme_font_size_override("font_size", 17)
	menu.add_child(prompt)

	var start := Button.new()
	start.text = "ENTER THE FIRST ROOM"
	start.custom_minimum_size = Vector2(0, 54)
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(_start_game)
	menu.add_child(start)


func _start_game() -> void:
	_enter_game()


func _enter_game() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)
