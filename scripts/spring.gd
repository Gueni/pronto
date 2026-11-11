extends Area2D
## Spring pad: land on it to be launched sky high. Origin is the centre of a tile.

var squash = 0.0


func _ready():
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(14, 6)
	c.shape = r
	c.position = Vector2(0, 4)
	add_child(c)


func _physics_process(delta):
	if squash > 0:
		squash = max(squash - delta * 4.0, 0.0)
		queue_redraw()
	for body in get_overlapping_bodies():
		if body.has_method("spring") and not body.dead and body.velocity.y >= 0:
			if body.spring():
				squash = 1.0
				Game.sfx("jump", 0.65, 2.0)
				queue_redraw()


func _draw():
	var top = 1.0 + squash * 4.0
	draw_rect(Rect2(-7, 6, 14, 2), Color(0.25, 0.27, 0.35))
	var pts = PackedVector2Array()
	for i in 5:
		pts.append(Vector2(-4 if i % 2 == 0 else 4, lerp(6.0, top + 2.0, i / 4.0)))
	draw_polyline(pts, Color(0.75, 0.78, 0.86), 1.5)
	draw_rect(Rect2(-7, top, 14, 3), Color(0.95, 0.3, 0.35))
	draw_rect(Rect2(-7, top, 14, 1), Color(1.0, 0.6, 0.6))
