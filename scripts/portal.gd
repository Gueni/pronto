extends Area2D
## A portal at the end of a zone: touch it and the whole team jumps to the start of the next
## zone, which becomes the checkpoint. target = -1 is the quiet pad you arrive on.
## Origin is at ground level.

var target = -1
var t = 0.0
var cooldown = 0.0


func _ready():
	z_index = 3
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(14, 36)
	c.shape = r
	c.position = Vector2(0, -18)
	add_child(c)


func _physics_process(delta):
	t += delta
	cooldown -= delta
	queue_redraw()
	if target < 0 or cooldown > 0:
		return
	for body in get_overlapping_bodies():
		if body.has_method("hurt") and not body.dead:
			cooldown = 1.5
			var level = Game.level_node
			if level != null and level.has_method("warp"):
				level.warp(target)
			return


func _draw():
	var live = target >= 0
	var col = Color(0.4, 0.9, 1.0) if live else Color(0.5, 0.55, 0.7)
	draw_rect(Rect2(-11, -3, 22, 3), Color(0.25, 0.27, 0.38))
	draw_rect(Rect2(-9, -5, 18, 2), Color(0.4, 0.43, 0.55))
	if not live:
		draw_arc(Vector2(0, -6), 7.0, PI, TAU, 12, Color(col.r, col.g, col.b, 0.5), 1.5)
		return
	var c = Vector2(0, -22)
	for i in 4:
		var k = fmod(t * 0.7 + i / 4.0, 1.0)
		var rx = 4.0 + k * 9.0
		var pts = PackedVector2Array()
		for j in 17:
			var a = TAU * j / 16.0 + t * 2.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * 1.5))
		draw_polyline(pts, Color(col.r, col.g, col.b, 1.0 - k), 1.5)
	draw_circle(c, 4.0 + sin(t * 6.0), Color(0.85, 1.0, 1.0, 0.9))
	draw_circle(c, 20.0, Color(col.r, col.g, col.b, 0.1))
	for i in 5:
		var k = fmod(t * 0.9 + i * 0.2, 1.0)
		draw_rect(Rect2(sin(i * 2.4 + t) * 9.0 - 1, -4 - k * 36.0, 2, 2), Color(col.r, col.g, col.b, 1.0 - k))
