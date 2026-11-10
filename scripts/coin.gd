extends Area2D

var collected = false

@onready var animation_player = $AnimationPlayer

func _on_body_entered(_body):
	if collected:
		return
	collected = true
	Game.add_coin(global_position)
	animation_player.play("Pickup")
