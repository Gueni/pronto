extends Area2D
## Anything with a die() method that enters is gone (bottomless pits).

func _on_body_entered(body):
	if body.has_method("die"):
		body.die()


func _on_timer_timeout():
	pass
