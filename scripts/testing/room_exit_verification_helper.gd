extends RefCounted


static func interact(exit: RoomExit, player: CharacterBody2D) -> void:
	exit._on_body_entered(player)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	exit._unhandled_input(event)
