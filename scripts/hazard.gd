extends Area2D
## Spikes (hurt), lava (instant death) and fire (a fireball leaping out of the lava).
## Origin is the centre of a tile.

var kind = "spike"
var t = 0.0
var base_y = 0.0


func _ready():
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	if kind == "fire":
		r.size = Vector2(9, 9)
		base_y = position.y + 20.0
		t = fmod(position.x * 0.013, 2.4)
		z_index = 3
	elif kind == "lava":
		r.size = Vector2(16, 10)
		c.position = Vector2(0, 3)
	else:
		r.size = Vector2(12, 6)
		c.position = Vector2(0, 5)
	c.shape = r
	add_child(c)


func _draw():
	if kind == "fire":
		draw_circle(Vector2.ZERO, 5.5, Color(1.0, 0.45, 0.1))
		draw_circle(Vector2(0, 1), 3.5, Color(1.0, 0.85, 0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(0, -10), Vector2(4, -3)]), Color(1.0, 0.45, 0.1))
		return
	if kind != "spike":
		return
	for i in 3:
		var x = -8 + i * 5.33
		draw_colored_polygon(PackedVector2Array([Vector2(x, 8), Vector2(x + 2.67, -1), Vector2(x + 5.33, 8)]), Color(0.62, 0.65, 0.75))
		draw_line(Vector2(x + 2.67, -1), Vector2(x + 5.33, 8), Color(0.16, 0.14, 0.24), 1.0)
		draw_line(Vector2(x, 8), Vector2(x + 2.67, -1), Color(0.16, 0.14, 0.24), 1.0)


func _physics_process(delta):
	if kind == "fire":
		# Leaps 5 tiles out of the lava every 2.4 seconds.
		t = fmod(t + delta, 2.4)
		var k = clamp(t / 1.3, 0.0, 1.0)
		position.y = base_y - 100.0 * 4.0 * k * (1.0 - k)
		scale.y = -1.0 if k > 0.5 and k < 1.0 else 1.0
	for body in get_overlapping_bodies():
		if body.has_method("hurt"):
			if kind == "lava":
				body.die()
			else:
				body.hurt(null)
