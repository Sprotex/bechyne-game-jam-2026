extends Node2D

const LEVEL_SCENE := "res://scenes/level.tscn"
const DOMECEK := preload("res://assets/gfx/domecek.png")
const CUTSCENE_BACKGROUNDS := [
	DOMECEK,
	preload("res://assets/gfx/fotak.png"),
	preload("res://assets/gfx/klic.png"),
]
const CUTSCENE_MESSAGES: Array[String] = [
	"Věci nemusí bejt tak, jak se na první pohled zdá.",
	"Ale TETY dům mi teda vždycky naháněl husí kůži. Možná to je ta nostalgie nebo fakt, že jsem se tu vždycky cítila, jako bych sem nepatřila.",
	"Stejně se za ní půjdu podívat.",
]
const OPTIONS_SCENE := preload("res://scenes/ui/options.tscn")
const CREDITS_SCENE := preload("res://scenes/ui/credits.tscn")
const DIALOG_MANAGER_SCENE := preload("res://scenes/ui/dialog_manager.tscn")

var options_screen: Control
var credits_screen: Control
var menu_container: Control
var cutscene_background: TextureRect
var cutscene_dialog: DialogManager


func _ready() -> void:
	_build_menu()
	options_screen = OPTIONS_SCENE.instantiate()
	options_screen.hide()
	options_screen.connect("back_pressed", _close_screens)
	$HUD.add_child(options_screen)
	credits_screen = CREDITS_SCENE.instantiate()
	credits_screen.hide()
	credits_screen.connect("back_pressed", _close_screens)
	$HUD.add_child(credits_screen)


func _build_menu() -> void:
	var background := TextureRect.new()
	background.texture = DOMECEK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	$HUD.add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.055, 0.07, 0.08, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(shade)

	var center := CenterContainer.new()
	menu_container = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(center)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(520, 280)
	menu.add_theme_constant_override("separation", 18)
	center.add_child(menu)

	var eyebrow := Label.new()
	eyebrow.text = "MÍSTNOST K PROZKOUMÁNÍ"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Color("#d5ae22"))
	eyebrow.add_theme_font_size_override("font_size", 16)
	menu.add_child(eyebrow)

	var title := Label.new()
	title.text = "POKOJE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fff8df"))
	title.add_theme_font_size_override("font_size", 54)
	menu.add_child(title)

	var prompt := Label.new()
	prompt.text = "Pohyb: WASD nebo šipky.\nZprávy, které cestou najdeš, se zobrazí zde."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color("#e1ded3"))
	prompt.add_theme_font_size_override("font_size", 17)
	menu.add_child(prompt)

	var start := Button.new()
	start.text = "VSTOUPIT DO PRVNÍ MÍSTNOSTI"
	start.custom_minimum_size = Vector2(0, 54)
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(_start_game)
	menu.add_child(start)

	var options := Button.new()
	options.text = "MOŽNOSTI"
	options.custom_minimum_size = Vector2(0, 48)
	options.pressed.connect(_open_options)
	menu.add_child(options)

	var credits := Button.new()
	credits.text = "AUTOŘI"
	credits.custom_minimum_size = Vector2(0, 48)
	credits.pressed.connect(_open_credits)
	menu.add_child(credits)


func _open_options() -> void:
	credits_screen.hide()
	options_screen.show()


func _open_credits() -> void:
	options_screen.hide()
	credits_screen.show()


func _close_screens() -> void:
	options_screen.hide()
	credits_screen.hide()


func _start_game() -> void:
	_show_cutscene()


func _show_cutscene() -> void:
	menu_container.hide()
	options_screen.hide()
	credits_screen.hide()
	_build_cutscene()
	cutscene_dialog.show_dialog(CUTSCENE_MESSAGES)


func _build_cutscene() -> void:
	cutscene_background = TextureRect.new()
	cutscene_background.name = "Cutscene"
	cutscene_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutscene_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cutscene_background.stretch_mode = TextureRect.STRETCH_SCALE
	$HUD.add_child(cutscene_background)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.025, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutscene_background.add_child(shade)

	cutscene_dialog = DIALOG_MANAGER_SCENE.instantiate() as DialogManager
	cutscene_dialog.message_changed.connect(_update_cutscene_background)
	cutscene_dialog.dialog_finished.connect(_enter_game)
	add_child(cutscene_dialog)
	cutscene_dialog.layer = 31

	cutscene_background.texture = CUTSCENE_BACKGROUNDS[0]


func _update_cutscene_background(message_index: int) -> void:
	cutscene_background.texture = CUTSCENE_BACKGROUNDS[message_index]


func _enter_game() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)
