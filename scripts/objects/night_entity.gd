extends Node2D
class_name NightEntity

const SCARE_DIALOGUE: StringName = &"act2.silhouette_scare"
const REVEAL_DIALOGUE: StringName = &"act2.coat_rack_reveal"
const DAY_TWO_FLAG := "story.day_two"
const SEEN_FLAG := "story.entity_seen"

@export var required_flag := ""
@export var art_scale := Vector2.ONE
@export_range(16.0, 256.0, 1.0) var trigger_radius := 64.0

var room: Room
var level: Level
var enabled_for_day := false
var scare_happened_here := false
var reveal_queued_here := false
var pending_dialogues: Array[StringName] = []

@onready var entity_sprite: Sprite2D = $Sprite2D
@onready var proximity: Area2D = $Proximity
@onready var proximity_shape: CollisionShape2D = $Proximity/CollisionShape2D


func _ready() -> void:
	room = _find_room_parent()
	level = _find_level_parent()
	if room == null or level == null:
		set_process(false)
		return
	room.lights_state_changed.connect(_on_lights_state_changed)
	if level.has_signal("flag_changed"):
		level.connect("flag_changed", _on_flag_changed)
	entity_sprite.scale = art_scale
	var circle := CircleShape2D.new()
	circle.radius = trigger_radius
	proximity_shape.shape = circle
	proximity.body_entered.connect(_on_body_entered)
	_refresh_visibility()


func _process(_delta: float) -> void:
	_deliver_pending_dialogue()


func _find_room_parent() -> Room:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Room:
			return ancestor as Room
		ancestor = ancestor.get_parent()
	return null


func _find_level_parent() -> Level:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Level:
			return ancestor as Level
		ancestor = ancestor.get_parent()
	return null


func _on_flag_changed(flag_id: String, _value: bool) -> void:
	if flag_id == DAY_TWO_FLAG or flag_id == required_flag:
		_refresh_visibility()


func _on_lights_state_changed(_is_on: bool) -> void:
	_refresh_visibility()
	if room.lights_are_on and scare_happened_here and not reveal_queued_here:
		reveal_queued_here = true
		pending_dialogues.append(REVEAL_DIALOGUE)


func _refresh_visibility() -> void:
	if room == null or level == null:
		return
	enabled_for_day = level.has_flag(DAY_TWO_FLAG)
	if not required_flag.is_empty():
		enabled_for_day = enabled_for_day and level.has_flag(required_flag)
	var is_visible_now := enabled_for_day and not room.lights_are_on
	entity_sprite.visible = is_visible_now
	proximity.monitoring = is_visible_now
	proximity.monitorable = is_visible_now


func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or not entity_sprite.visible or scare_happened_here:
		return
	if level.has_flag(SEEN_FLAG):
		return
	scare_happened_here = true
	level.set_flag(SEEN_FLAG)
	pending_dialogues.append(SCARE_DIALOGUE)


func _deliver_pending_dialogue() -> void:
	if pending_dialogues.is_empty() or not is_instance_valid(level):
		return
	if not level.player_controls_enabled() or not is_instance_valid(level.dialog_manager):
		return
	if level.dialog_manager.is_modal_open():
		return
	var dialogue_id: StringName = pending_dialogues.pop_front()
	level.dialog_manager.show_dialog(DialogueCatalog.get_messages(dialogue_id))
