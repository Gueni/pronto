extends Area2D
## A small flag. Touch it to respawn here. Origin is at ground level.

var active = false


func _ready():
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(12, 32)
	c.shape = r
	c.position = Vector2(0, -16)
	add_child(c)
	body_entered.connect(_on_body)
	if Game.checkpoint != null and Game.checkpoint.distance_to(global_position) < 4:
		active = true


func _draw():
	draw_rect(Rect2(-4, -3, 8, 3), Color(0.25, 0.27, 0.35))
	draw_rect(Rect2(-1, -30, 2, 27), Color(0.85, 0.88, 0.95))
	var col = Color(0.3, 0.7, 1.0) if active else Color(0.75, 0.75, 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(1, -30), Vector2(12, -26), Vector2(1, -22)]), col)


func _on_body(body):
	if active or not body.has_method("hurt") or body.dead:
		return
	active = true
	Game.checkpoint = global_position
	Game.sfx("power_up", 1.6, -4.0)
	Game.popup("CHECKPOINT!", global_position + Vector2(0, -24), Color(0.5, 0.85, 1.0))
	queue_redraw()
