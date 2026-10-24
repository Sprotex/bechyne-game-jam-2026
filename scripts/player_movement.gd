extends CharacterBody2D

@export var speed: float = 300.0


func _physics_process(_delta: float) -> void:
	if DialogManager.is_dialog_open():
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
