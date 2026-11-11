extends Area2D

var collected = false

@onready var animation_player = $AnimationPlayer

func _on_body_entered(body):
	if collected:
		return
	collected = true
	if body.has_method("add_mana"):
		body.add_mana(3)
	Game.add_coin(global_position)
	animation_player.play("Pickup")
