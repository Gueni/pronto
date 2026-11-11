extends Area2D
## Shockwave rolling along the floor after a boss lands. Jump over it! Origin is at floor level.

var dir = 1
var speed = 130.0
var life = 1.5
var t = 0.0


func _ready():
	z_index = 6
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(9, 13)
	c.shape = r
	c.position = Vector2(0, -6.5)
	add_child(c)


func _physics_process(delta):
	t += delta
	position.x += dir * speed * delta
	queue_redraw()
	if t >= life:
		queue_free()
		return
	for body in get_overlapping_bodies():
		if body.has_method("hurt"):
			body.hurt(global_position.x - dir * 8.0)


func _draw():
	var a = clamp((life - t) * 3.0, 0.0, 1.0)
	var h = 13.0 + sin(t * 30.0) * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-dir * 7, 0), Vector2(dir * 2, -h), Vector2(dir * 6, -h * 0.55), Vector2(dir * 5, 0)]),
		Color(1.0, 0.95, 0.7, a))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-dir * 12, 0), Vector2(-dir * 6, -h * 0.5), Vector2(-dir * 4, 0)]),
		Color(1.0, 0.8, 0.5, a * 0.6))
