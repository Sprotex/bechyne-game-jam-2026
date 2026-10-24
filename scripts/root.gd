extends Node2D

const LEVEL_SCENE := "res://scenes/level.tscn"
const ROOM_LAYOUT := preload("res://assets/room_layout.png")

var access_dialog: AcceptDialog


func _ready() -> void:
	UserMessages.browser_access_checked.connect(_on_browser_access_checked)
	UserMessages.browser_write_failed.connect(_on_browser_write_failed)
	_build_menu()


func _build_menu() -> void:
	var background := TextureRect.new()
	background.texture = ROOM_LAYOUT
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
	prompt.text = "Move with WASD or the arrow keys.\nChoose where messages can be saved when you start."
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

	access_dialog = AcceptDialog.new()
	access_dialog.title = "MESSAGE FOLDER ACCESS"
	access_dialog.ok_button_text = "TRY AGAIN"
	access_dialog.add_button("CONTINUE ANYWAY", true, "continue")
	access_dialog.confirmed.connect(_retry_folder_access)
	access_dialog.custom_action.connect(_on_access_dialog_action)
	$HUD.add_child(access_dialog)


func _start_game() -> void:
	if OS.has_feature("web"):
		UserMessages.request_browser_folder_access()
		return
	_enter_game()


func _on_browser_access_checked(success: bool, detail: String) -> void:
	if success:
		_enter_game()
	else:
		_show_access_dialog("To save messages in a folder, choose a folder and approve read and write access. %s\n\nTry again, or continue with browser downloads." % detail)


func _show_access_dialog(message: String) -> void:
	access_dialog.dialog_text = message
	access_dialog.popup_centered()


func _retry_folder_access() -> void:
	_start_game()


func _on_access_dialog_action(action: StringName) -> void:
	if action == &"continue":
		UserMessages.use_browser_downloads()
		_enter_game()


func _on_browser_write_failed(file_name: String) -> void:
	_show_access_dialog("Could not save %s. Choose a writable folder or continue with browser downloads." % file_name)


func _enter_game() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)
