extends CanvasLayer
class_name WorldFrame

var room: Room
var camera: Camera2D
var bars: Dictionary = {}


func setup(target_camera: Camera2D) -> void:
	camera = target_camera
	name = "WorldFrame"
	layer = 10
	for bar_name in ["TopLetterbox", "BottomLetterbox", "LeftLetterbox", "RightLetterbox"]:
		var bar := ColorRect.new()
		bar.name = bar_name
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bars[bar_name] = bar
	update_frame()


func set_room(active_room: Room) -> void:
	room = active_room


func get_render_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var bounds := room.get_background_bounds() if is_instance_valid(room) else Rect2()
	var render_size := (bounds.size * camera.zoom).min(viewport_size)
	return Rect2((viewport_size - render_size) * 0.5, render_size)


func update_frame() -> void:
	if bars.is_empty():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var bounds := room.get_background_bounds() if is_instance_valid(room) else Rect2()
	if bounds.size.y > 0.0:
		camera.zoom = Vector2.ONE * viewport_size.y / bounds.size.y
	var render_rect := get_render_rect()
	_set_bar("TopLetterbox", Rect2(0, 0, viewport_size.x, render_rect.position.y))
	_set_bar("BottomLetterbox", Rect2(0, render_rect.end.y, viewport_size.x, viewport_size.y - render_rect.end.y))
	_set_bar("LeftLetterbox", Rect2(0, render_rect.position.y, render_rect.position.x, render_rect.size.y))
	_set_bar("RightLetterbox", Rect2(render_rect.end.x, render_rect.position.y, viewport_size.x - render_rect.end.x, render_rect.size.y))


func crop_photo(photo: Image) -> Image:
	var rect := get_render_rect()
	var crop := Rect2i(floori(rect.position.x), floori(rect.position.y), mini(roundi(rect.size.x), photo.get_width()), mini(roundi(rect.size.y), photo.get_height()))
	crop.position.x = clampi(crop.position.x, 0, photo.get_width() - crop.size.x)
	crop.position.y = clampi(crop.position.y, 0, photo.get_height() - crop.size.y)
	return photo.get_region(crop)


func _set_bar(bar_name: String, rect: Rect2) -> void:
	var bar := bars[bar_name] as ColorRect
	bar.position = rect.position
	bar.size = rect.size
	bar.visible = rect.size.x > 0.0 and rect.size.y > 0.0
